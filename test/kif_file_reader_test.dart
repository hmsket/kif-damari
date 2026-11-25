import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/kif_file_reader.dart';

void main() {
  group('KifFileReader', () {
    late Directory tempDir;
    late File kifFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('kif_file_reader_test');
      kifFile = File('${tempDir.path}/sample.kif');
      await kifFile.writeAsBytes(utf8.encode('先手：山田太郎\n後手：佐藤花子\n'));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('ローカルパスから UTF-8 の棋譜を読み込める', () async {
      final text = await KifFileReader.readText(kifFile.path);

      expect(text, contains('先手：山田太郎'));
      expect(text, contains('後手：佐藤花子'));
    });

    test('file:// URI からも棋譜を読み込める', () async {
      final uri = Uri.file(kifFile.path).toString();
      final text = await KifFileReader.readText(uri);

      expect(text, contains('先手：山田太郎'));
    });

    test('存在しないファイルは null を返す', () async {
      final bytes = await KifFileReader.readBytes('${tempDir.path}/missing.kif');

      expect(bytes, isNull);
    });

    test('toLocalPath は file:// URI をローカルパスに変換する', () {
      final localPath = '/storage/emulated/0/Download/sample.kif';
      final uri = Uri.file(localPath).toString();

      expect(KifFileReader.toLocalPath(uri), localPath);
      expect(KifFileReader.toLocalPath(localPath), localPath);
    });
  });
}
