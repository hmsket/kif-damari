import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/kif_save_planner.dart';

void main() {
  group('KifSavePlanner 保存先の振り分け', () {
    test('新規作成・未設定の場合はアプリ内部フォルダへ新規作成する', () async {
      final plan = await KifSavePlanner.plan(
        currentPath: '',
        pendingTreeUri: null,
        defaultTreeUri: '',
        fileExists: (_) async => throw StateError('呼ばれない'),
      );

      expect(plan.mode, KifSaveMode.newInternal);
      expect(plan.treeUri, isNull);
    });

    test('新規作成・デフォルト保存先設定ありの場合はそのフォルダへ新規作成する', () async {
      final plan = await KifSavePlanner.plan(
        currentPath: '',
        pendingTreeUri: null,
        defaultTreeUri: 'content://com.android.providers.downloads.documents/tree/downloads',
        fileExists: (_) async => throw StateError('呼ばれない'),
      );

      expect(plan.mode, KifSaveMode.newRemote);
      expect(plan.treeUri, 'content://com.android.providers.downloads.documents/tree/downloads');
      expect(plan.targetPath, isNull);
    });

    test('取り込み棋譜（content://）は設定があっても元のファイルへ上書きする', () async {
      final plan = await KifSavePlanner.plan(
        currentPath: 'content://com.google.android.apps.docs.storage/document/acc%3D1%3Bdoc%3D1',
        pendingTreeUri: null,
        defaultTreeUri: 'content://tree/downloads',
        fileExists: (_) async => throw StateError('呼ばれない'),
      );

      expect(plan.mode, KifSaveMode.overwriteRemote);
      expect(plan.targetPath, 'content://com.google.android.apps.docs.storage/document/acc%3D1%3Bdoc%3D1');
      expect(plan.treeUri, isNull);
    });

    test('既存のローカルファイルがある棋譜は設定があっても元のファイルへ上書きする', () async {
      final existingPath = '/data/user/0/app/files/Kifdamari/1000.kif';
      final plan = await KifSavePlanner.plan(
        currentPath: existingPath,
        pendingTreeUri: null,
        defaultTreeUri: 'content://tree/downloads',
        fileExists: (path) async => path == existingPath,
      );

      expect(plan.mode, KifSaveMode.overwriteLocal);
      expect(plan.targetPath, existingPath);
      expect(plan.treeUri, isNull);
    });

    test('既存パスのファイルが消えている場合は新規作成として扱う（未設定）', () async {
      final plan = await KifSavePlanner.plan(
        currentPath: '/data/user/0/app/files/Kifdamari/1000.kif',
        pendingTreeUri: null,
        defaultTreeUri: '',
        fileExists: (_) async => false,
      );

      expect(plan.mode, KifSaveMode.newInternal);
    });

    test('既存パスのファイルが消えている場合は新規作成として扱う（設定あり）', () async {
      final plan = await KifSavePlanner.plan(
        currentPath: '/data/user/0/app/files/Kifdamari/1000.kif',
        pendingTreeUri: null,
        defaultTreeUri: 'content://tree/downloads',
        fileExists: (_) async => false,
      );

      expect(plan.mode, KifSaveMode.newRemote);
      expect(plan.treeUri, 'content://tree/downloads');
    });

    test('送信待ちの棋譜はデフォルト保存先が変わっても退避先の保存先へ更新する', () async {
      final plan = await KifSavePlanner.plan(
        currentPath: '/data/user/0/app/files/Kifdamari/pending/1000.kif',
        pendingTreeUri: 'content://tree/downloads',
        defaultTreeUri: '',
        fileExists: (path) async => File(path).exists(),
      );

      expect(plan.mode, KifSaveMode.pendingUpdate);
      expect(plan.treeUri, 'content://tree/downloads');
      expect(plan.targetPath, '/data/user/0/app/files/Kifdamari/pending/1000.kif');
    });

    test('送信待ちでも退避パスが未確定の場合は targetPath が null になる', () async {
      final plan = await KifSavePlanner.plan(
        currentPath: '',
        pendingTreeUri: 'content://tree/downloads',
        defaultTreeUri: '',
        fileExists: (_) async => false,
      );

      expect(plan.mode, KifSaveMode.pendingUpdate);
      expect(plan.treeUri, 'content://tree/downloads');
      expect(plan.targetPath, isNull);
    });

    test('空文字の pendingTreeUri は送信待ちとして扱わない', () async {
      final plan = await KifSavePlanner.plan(
        currentPath: '',
        pendingTreeUri: '',
        defaultTreeUri: '',
        fileExists: (_) async => throw StateError('呼ばれない'),
      );

      expect(plan.mode, KifSaveMode.newInternal);
    });

    test('file:// URI の取り込み棋譜は元のファイルへ上書きする', () async {
      const uri = 'file:///storage/emulated/0/Download/1000.kif';
      final plan = await KifSavePlanner.plan(
        currentPath: uri,
        pendingTreeUri: null,
        defaultTreeUri: 'content://tree/downloads',
        fileExists: (path) async => path == '/storage/emulated/0/Download/1000.kif',
      );

      expect(plan.mode, KifSaveMode.overwriteLocal);
      expect(plan.targetPath, uri);
      expect(plan.treeUri, isNull);
    });

    test('file:// URI の元ファイルが消えている場合は新規作成として扱う', () async {
      final plan = await KifSavePlanner.plan(
        currentPath: 'file:///storage/emulated/0/Download/1000.kif',
        pendingTreeUri: null,
        defaultTreeUri: '',
        fileExists: (_) async => false,
      );

      expect(plan.mode, KifSaveMode.newInternal);
    });
  });
}
