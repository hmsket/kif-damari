import 'dart:io';
import 'dart:typed_data';

import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/logic/saf_helper.dart';
import 'package:path/path.dart' as p;

/// 送信待ち棋譜の一覧取得と、送信完了後の状態更新を担うリポジトリ。
abstract class PendingKifRepository {
  Future<List<KifEntity>> getPendingKifs();

  /// 棋譜を「送信済み」に更新する（kifPath をリモートの保存先に差し替え、
  /// 送信待ち状態を解除する）。
  Future<void> markSent({required KifEntity kif, required String remotePath});
}

/// 退避ファイルの読み込み・削除を担う。
abstract class PendingKifFileStore {
  Future<Uint8List?> readBytes(String path);
  Future<void> delete(String path);
}

/// デフォルト保存先（SAF ツリー）への新規ファイル作成を担う。
abstract class PendingKifRemoteWriter {
  /// 成功時は作成したファイルの content:// URI、失敗時（オフライン等）は null。
  Future<String?> createFile({
    required String treeUri,
    required String fileName,
    required Uint8List bytes,
  });
}

/// オフライン時に退避保存した「送信待ち」棋譜を、オンライン時に
/// デフォルト保存先へ自動送信する。
class PendingKifSender {
  final PendingKifRepository repository;
  final PendingKifFileStore fileStore;
  final PendingKifRemoteWriter remoteWriter;

  PendingKifSender({
    required this.repository,
    required this.fileStore,
    required this.remoteWriter,
  });

  static final PendingKifSender instance = PendingKifSender(
    repository: KifDaoPendingKifRepository(),
    fileStore: LocalPendingKifFileStore(),
    remoteWriter: SafPendingKifRemoteWriter(),
  );

  /// すべての送信待ち棋譜の自動送信を試み、送信できた件数を返す。
  ///
  /// 送信できない棋譜（オフライン等）は退避状態のまま残す。
  Future<int> sendPendingKifs() async {
    final pendingKifs = await repository.getPendingKifs();
    int sentCount = 0;

    for (final kif in List.of(pendingKifs)) {
      final treeUri = kif.pendingTreeUri;
      final localPath = kif.kifPath;
      if (treeUri == null || treeUri.isEmpty) continue;
      if (localPath == null || localPath.isEmpty) continue;

      final bytes = await fileStore.readBytes(localPath);
      if (bytes == null) continue;

      final remotePath = await remoteWriter.createFile(
        treeUri: treeUri,
        fileName: p.basename(localPath),
        bytes: bytes,
      );
      if (remotePath == null || remotePath.isEmpty) continue;

      await fileStore.delete(localPath);
      await repository.markSent(kif: kif, remotePath: remotePath);
      sentCount++;
    }

    return sentCount;
  }
}

/// KifDao を使った既定のリポジトリ実装。
class KifDaoPendingKifRepository implements PendingKifRepository {
  @override
  Future<List<KifEntity>> getPendingKifs() => KifDao().getPendingKifs();

  @override
  Future<void> markSent({required KifEntity kif, required String remotePath}) {
    return KifDao().updateKif(KifEntity(
      id: kif.id,
      tabId: kif.tabId,
      kifId: kif.kifId,
      title: kif.title,
      detail: kif.detail,
      kifOrder: kif.kifOrder,
      kifPath: remotePath,
      imgPath: kif.imgPath,
      color: kif.color,
    ));
  }
}

/// ローカルファイルシステムを使った既定の退避ファイル操作。
class LocalPendingKifFileStore implements PendingKifFileStore {
  @override
  Future<Uint8List?> readBytes(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

/// SafHelper を使った既定の保存先書き込み。
class SafPendingKifRemoteWriter implements PendingKifRemoteWriter {
  @override
  Future<String?> createFile({
    required String treeUri,
    required String fileName,
    required Uint8List bytes,
  }) {
    return SafHelper.createFileInTree(treeUri, fileName, bytes);
  }
}
