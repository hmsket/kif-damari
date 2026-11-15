import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/logic/pending_kif_sender.dart';

KifEntity _pendingKif({int? id, required String kifPath, required String treeUri}) {
  return KifEntity(
    id: id,
    tabId: 1,
    kifId: 1,
    title: 'テスト棋譜',
    kifOrder: 1,
    kifPath: kifPath,
    pendingTreeUri: treeUri,
  );
}

class FakeRepository implements PendingKifRepository {
  FakeRepository(this.kifs);

  final List<KifEntity> kifs;
  final List<({int? id, String remotePath})> markedSent = [];

  @override
  Future<List<KifEntity>> getPendingKifs() async => kifs;

  @override
  Future<void> markSent({required KifEntity kif, required String remotePath}) async {
    markedSent.add((id: kif.id, remotePath: remotePath));
    kifs.removeWhere((k) => k.id == kif.id);
  }
}

class FakeFileStore implements PendingKifFileStore {
  final Map<String, Uint8List> files = {};

  @override
  Future<Uint8List?> readBytes(String path) async => files[path];

  @override
  Future<void> delete(String path) async {
    files.remove(path);
  }
}

class FakeRemoteWriter implements PendingKifRemoteWriter {
  FakeRemoteWriter(this.results, {this.failFileNames = const {}});

  /// ツリー URI ごとの結果。null はオフライン等で作成に失敗することを表す。
  final Map<String, String?> results;

  /// 指定したファイル名の作成を常に失敗させる（ツリー URI が同じでも）。
  final Set<String> failFileNames;
  final List<({String treeUri, String fileName, Uint8List bytes})> calls = [];

  @override
  Future<String?> createFile({
    required String treeUri,
    required String fileName,
    required Uint8List bytes,
  }) async {
    calls.add((treeUri: treeUri, fileName: fileName, bytes: bytes));
    if (failFileNames.contains(fileName)) return null;
    return results[treeUri];
  }
}

void main() {
  group('PendingKifSender 送信待ちの状態遷移', () {
    test('オフライン（保存先に書き込めない）場合は送信せず退避状態のまま残る', () async {
      final kif = _pendingKif(id: 1, kifPath: '/app/pending/1000.kif', treeUri: 'content://tree/drive');
      final repository = FakeRepository([kif]);
      final fileStore = FakeFileStore()..files['/app/pending/1000.kif'] = Uint8List.fromList([1, 2, 3]);
      final remoteWriter = FakeRemoteWriter({'content://tree/drive': null});
      final sender = PendingKifSender(
        repository: repository,
        fileStore: fileStore,
        remoteWriter: remoteWriter,
      );

      final sentCount = await sender.sendPendingKifs();

      expect(sentCount, 0);
      expect(repository.markedSent, isEmpty);
      expect(fileStore.files.containsKey('/app/pending/1000.kif'), isTrue);
      expect(remoteWriter.calls.single.treeUri, 'content://tree/drive');
      expect(remoteWriter.calls.single.fileName, '1000.kif');
    });

    test('オンライン時に送信できたら kifPath が保存先に更新され、退避状態と退避ファイルが消える', () async {
      final kif = _pendingKif(id: 1, kifPath: '/app/pending/1000.kif', treeUri: 'content://tree/drive');
      final repository = FakeRepository([kif]);
      final fileStore = FakeFileStore()..files['/app/pending/1000.kif'] = Uint8List.fromList([1, 2, 3]);
      final remoteWriter = FakeRemoteWriter({'content://tree/drive': 'content://tree/drive/document/1000.kif'});
      final sender = PendingKifSender(
        repository: repository,
        fileStore: fileStore,
        remoteWriter: remoteWriter,
      );

      final sentCount = await sender.sendPendingKifs();

      expect(sentCount, 1);
      expect(repository.markedSent.single.id, 1);
      expect(
        repository.markedSent.single.remotePath,
        'content://tree/drive/document/1000.kif',
      );
      expect(repository.kifs, isEmpty);
      expect(fileStore.files.containsKey('/app/pending/1000.kif'), isFalse);
      expect(fileStore.files.values.single, Uint8List.fromList([1, 2, 3]));
    });

    test('複数件のうち一部だけ送信できる場合、送信できた分だけ状態が更新される', () async {
      final sentKif = _pendingKif(id: 1, kifPath: '/app/pending/1000.kif', treeUri: 'content://tree/drive');
      final stillPendingKif = _pendingKif(id: 2, kifPath: '/app/pending/2000.kif', treeUri: 'content://tree/drive');
      final repository = FakeRepository([sentKif, stillPendingKif]);
      final fileStore = FakeFileStore()
        ..files['/app/pending/1000.kif'] = Uint8List.fromList([1])
        ..files['/app/pending/2000.kif'] = Uint8List.fromList([2]);
      final remoteWriter = FakeRemoteWriter(
        {'content://tree/drive': 'content://tree/drive/document/sent.kif'},
        failFileNames: {'2000.kif'},
      );
      final sender = PendingKifSender(
        repository: repository,
        fileStore: fileStore,
        remoteWriter: remoteWriter,
      );

      final sentCount = await sender.sendPendingKifs();

      expect(sentCount, 1);
      expect(repository.markedSent.single.id, 1);
      expect(repository.kifs.single.id, 2);
      expect(fileStore.files.containsKey('/app/pending/1000.kif'), isFalse);
      expect(fileStore.files.containsKey('/app/pending/2000.kif'), isTrue);
    });

    test('退避ファイルが読めない棋譜はスキップされ、他の棋譜は送信される', () async {
      final brokenKif = _pendingKif(id: 1, kifPath: '/app/pending/missing.kif', treeUri: 'content://tree/drive');
      final okKif = _pendingKif(id: 2, kifPath: '/app/pending/2000.kif', treeUri: 'content://tree/drive');
      final repository = FakeRepository([brokenKif, okKif]);
      final fileStore = FakeFileStore()
        ..files['/app/pending/2000.kif'] = Uint8List.fromList([2]);
      final remoteWriter = FakeRemoteWriter({'content://tree/drive': 'content://tree/drive/document/2000.kif'});
      final sender = PendingKifSender(
        repository: repository,
        fileStore: fileStore,
        remoteWriter: remoteWriter,
      );

      final sentCount = await sender.sendPendingKifs();

      expect(sentCount, 1);
      expect(repository.markedSent.single.id, 2);
      expect(repository.kifs.single.id, 1);
    });

    test('送信待ちでない棋譜（pendingTreeUri 未設定）は対象にならない', () async {
      final normalKif = KifEntity(
        id: 1,
        tabId: 1,
        kifId: 1,
        title: '通常の棋譜',
        kifOrder: 1,
        kifPath: 'content://tree/drive/document/1000.kif',
      );
      final repository = FakeRepository([normalKif]);
      final fileStore = FakeFileStore();
      final remoteWriter = FakeRemoteWriter({'content://tree/drive': 'content://tree/drive/document/1000.kif'});
      final sender = PendingKifSender(
        repository: repository,
        fileStore: fileStore,
        remoteWriter: remoteWriter,
      );

      // FakeRepository は引数のリストをそのまま返すため、
      // sender 側で pendingTreeUri 未設定の棋譜をスキップすることを確認する
      expect(normalKif.isPendingSend, isFalse);
      final sentCount = await sender.sendPendingKifs();
      expect(sentCount, 0);
      expect(remoteWriter.calls, isEmpty);
    });
  });
}
