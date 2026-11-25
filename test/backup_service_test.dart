import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/backup_service.dart';

void main() {
  group('BackupManifest', () {
    test('JSON へ書き出して読み戻せる', () {
      final manifest = BackupManifest(
        formatVersion: BackupManifest.currentVersion,
        createdAt: DateTime.utc(2026, 11, 25, 12, 34, 56),
        kifFiles: const [
          BackupKifFileEntry(
            kifRowId: 1,
            archivePath: 'kif_files/1.kif',
            originalPath: '/data/Kifdamari/1.kif',
          ),
        ],
        thumbnails: const [
          BackupThumbnailEntry(
            kifRowId: 1,
            archivePath: 'thumbnails/1.png',
            originalPath: '/data/thumbnails/1.png',
          ),
        ],
      );

      final json = jsonDecode(jsonEncode(manifest.toJson())) as Map<String, dynamic>;
      final restored = BackupManifest.fromJson(json);

      expect(restored.formatVersion, BackupManifest.currentVersion);
      expect(restored.createdAt, DateTime.utc(2026, 11, 25, 12, 34, 56));
      expect(restored.kifFiles.single.kifRowId, 1);
      expect(restored.kifFiles.single.archivePath, 'kif_files/1.kif');
      expect(restored.thumbnails.single.archivePath, 'thumbnails/1.png');
    });

    test('別形式の JSON は BackupFormatException になる', () {
      expect(
        () => BackupManifest.fromJson({'format': 'other'}),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });

  group('BackupService', () {
    test('バックアップファイルでないデータは復元せず例外を投げる', () async {
      await expectLater(
        const BackupService().restore(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });
}
