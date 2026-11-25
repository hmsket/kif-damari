import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kifdamari/database/database_helper.dart';
import 'package:kifdamari/logic/kif_file_reader.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// バックアップファイルとして読み込めない場合に投げる例外。
class BackupFormatException implements Exception {
  final String message;

  BackupFormatException(this.message);

  @override
  String toString() => message;
}

/// 復元結果。
class BackupRestoreResult {
  /// 復元した棋譜の総数。
  final int restoredKifCount;

  /// 実体を同梱できず、復元後に開けない可能性がある棋譜の数。
  final int unopenableKifCount;

  const BackupRestoreResult({
    required this.restoredKifCount,
    required this.unopenableKifCount,
  });
}

/// ZIP に同梱した棋譜ファイル1件分の対応表。
class BackupKifFileEntry {
  final int kifRowId;
  final String archivePath;
  final String originalPath;

  const BackupKifFileEntry({
    required this.kifRowId,
    required this.archivePath,
    required this.originalPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'kifRowId': kifRowId,
      'archivePath': archivePath,
      'originalPath': originalPath,
    };
  }

  factory BackupKifFileEntry.fromJson(Map<String, dynamic> json) {
    return BackupKifFileEntry(
      kifRowId: json['kifRowId'] as int,
      archivePath: json['archivePath'] as String,
      originalPath: (json['originalPath'] as String?) ?? '',
    );
  }
}

/// ZIP に同梱したサムネイル1件分の対応表。
class BackupThumbnailEntry {
  final int kifRowId;
  final String archivePath;
  final String originalPath;

  const BackupThumbnailEntry({
    required this.kifRowId,
    required this.archivePath,
    required this.originalPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'kifRowId': kifRowId,
      'archivePath': archivePath,
      'originalPath': originalPath,
    };
  }

  factory BackupThumbnailEntry.fromJson(Map<String, dynamic> json) {
    return BackupThumbnailEntry(
      kifRowId: json['kifRowId'] as int,
      archivePath: json['archivePath'] as String,
      originalPath: (json['originalPath'] as String?) ?? '',
    );
  }
}

/// バックアップファイルのマニフェスト。
class BackupManifest {
  static const String formatName = 'kifdamari-backup';
  static const int currentVersion = 1;

  final int formatVersion;
  final DateTime createdAt;
  final String? appVersion;
  final List<BackupKifFileEntry> kifFiles;
  final List<BackupThumbnailEntry> thumbnails;

  const BackupManifest({
    required this.formatVersion,
    required this.createdAt,
    this.appVersion,
    required this.kifFiles,
    required this.thumbnails,
  });

  Map<String, dynamic> toJson() {
    return {
      'format': formatName,
      'formatVersion': formatVersion,
      'createdAt': createdAt.toIso8601String(),
      'appVersion': appVersion,
      'kifFiles': kifFiles.map((entry) => entry.toJson()).toList(),
      'thumbnails': thumbnails.map((entry) => entry.toJson()).toList(),
    };
  }

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    if (json['format'] != formatName) {
      throw BackupFormatException('バックアップファイルではありません');
    }

    final version = json['formatVersion'];
    if (version is! int || version < 1 || version > currentVersion) {
      throw BackupFormatException('対応していないバックアップ形式です');
    }

    final createdAtValue = json['createdAt'];
    final createdAt = createdAtValue is String
        ? DateTime.tryParse(createdAtValue)
        : null;
    if (createdAt == null) {
      throw BackupFormatException('バックアップファイルの内容が不正です');
    }

    final kifFiles = <BackupKifFileEntry>[];
    final kifFilesValue = json['kifFiles'];
    if (kifFilesValue is List) {
      for (final item in kifFilesValue) {
        if (item is Map) {
          kifFiles.add(
            BackupKifFileEntry.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final thumbnails = <BackupThumbnailEntry>[];
    final thumbnailsValue = json['thumbnails'];
    if (thumbnailsValue is List) {
      for (final item in thumbnailsValue) {
        if (item is Map) {
          thumbnails.add(
            BackupThumbnailEntry.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final appVersionValue = json['appVersion'];
    return BackupManifest(
      formatVersion: version,
      createdAt: createdAt,
      appVersion: appVersionValue is String ? appVersionValue : null,
      kifFiles: kifFiles,
      thumbnails: thumbnails,
    );
  }
}

/// DB・設定・サムネイル・棋譜ファイルの実体を ZIP 1ファイルにまとめて
/// バックアップ／復元するサービス。
class BackupService {
  /// 復元が完了したことを画面へ知らせるためのリビジョン。
  static final ValueNotifier<int> restoreRevision = ValueNotifier<int>(0);

  static const String _manifestEntryName = 'manifest.json';
  static const String _databaseEntryName = 'database.json';
  static const String _settingsEntryName = 'settings.json';

  const BackupService();

  /// 現在のデータを ZIP のバイト列として返す。
  Future<Uint8List> createBackup() async {
    final db = await DatabaseHelper.instance.database;
    final database = await _exportDatabase(db);
    final settings = _exportSettings();

    final archive = Archive();
    final kifFiles = <BackupKifFileEntry>[];
    final thumbnails = <BackupThumbnailEntry>[];

    final kifRows = database['kifs'] as List<Map<String, dynamic>>;
    for (final kif in kifRows) {
      final kifRowId = kif['id'];
      if (kifRowId is! int) continue;

      final kifPath = kif['kif_path'];
      if (kifPath is String && kifPath.isNotEmpty) {
        final bytes = await KifFileReader.readBytes(kifPath);
        if (bytes != null) {
          final archivePath = 'kif_files/$kifRowId${_extensionOf(kifPath, '.kif')}';
          archive.add(ArchiveFile.bytes(archivePath, bytes));
          kifFiles.add(BackupKifFileEntry(
            kifRowId: kifRowId,
            archivePath: archivePath,
            originalPath: kifPath,
          ));
        }
      }

      final imgPath = kif['img_path'];
      if (imgPath is String && imgPath.isNotEmpty) {
        final bytes = await KifFileReader.readBytes(imgPath);
        if (bytes != null) {
          final archivePath = 'thumbnails/$kifRowId${_extensionOf(imgPath, '.png')}';
          archive.add(ArchiveFile.bytes(archivePath, bytes));
          thumbnails.add(BackupThumbnailEntry(
            kifRowId: kifRowId,
            archivePath: archivePath,
            originalPath: imgPath,
          ));
        }
      }
    }

    final manifest = BackupManifest(
      formatVersion: BackupManifest.currentVersion,
      createdAt: DateTime.now(),
      kifFiles: kifFiles,
      thumbnails: thumbnails,
    );

    archive.add(ArchiveFile.string(_databaseEntryName, jsonEncode(database)));
    archive.add(ArchiveFile.string(_settingsEntryName, jsonEncode(settings)));
    archive.add(ArchiveFile.string(_manifestEntryName, jsonEncode(manifest.toJson())));

    return ZipEncoder().encodeBytes(archive);
  }

  /// [bytes] のバックアップファイルで現在のデータを上書き復元する。
  ///
  /// マニフェストを検証してから書き込みを始めるため、バックアップファイルでない
  /// データを渡した場合は現在のデータに一切触れず [BackupFormatException] を投げる。
  Future<BackupRestoreResult> restore(Uint8List bytes) async {
    final archive = _decodeArchive(bytes);
    final manifest = _readManifest(archive);
    final database = _readJsonMap(archive, _databaseEntryName);
    final settings = _readJsonMap(archive, _settingsEntryName);

    final tabs = _readRows(database, 'tabs');
    final kifs = _readRows(database, 'kifs');
    final positions = _readRows(database, 'positions');
    final transitions = _readRows(database, 'transitions');
    final appearances = _readRows(database, 'positionAppearances');

    // 書き込み前に、マニフェストに載っている実体が ZIP 内に存在するか検証する。
    final kifEntries = <BackupKifFileEntry, Uint8List>{};
    for (final entry in manifest.kifFiles) {
      final archiveFile = archive.find(entry.archivePath);
      if (archiveFile == null) {
        throw BackupFormatException('バックアップファイルの内容が不足しています');
      }
      kifEntries[entry] = _readArchiveBytes(archiveFile);
    }

    final thumbnailEntries = <BackupThumbnailEntry, Uint8List>{};
    for (final entry in manifest.thumbnails) {
      final archiveFile = archive.find(entry.archivePath);
      if (archiveFile == null) {
        throw BackupFormatException('バックアップファイルの内容が不足しています');
      }
      thumbnailEntries[entry] = _readArchiveBytes(archiveFile);
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final restoreId = DateTime.now().millisecondsSinceEpoch;
    final kifDir = Directory(
      p.join(documentsDir.path, 'Kifdamari', 'restored_$restoreId'),
    );
    final thumbnailDir = Directory(
      p.join(documentsDir.path, 'thumbnails_restored_$restoreId'),
    );

    final kifPathByRowId = <int, String>{};
    for (final entry in kifEntries.keys) {
      kifPathByRowId[entry.kifRowId] = p.join(
        kifDir.path,
        p.basename(entry.archivePath),
      );
    }

    final imgPathByRowId = <int, String>{};
    for (final entry in thumbnailEntries.keys) {
      imgPathByRowId[entry.kifRowId] = p.join(
        thumbnailDir.path,
        p.basename(entry.archivePath),
      );
    }

    var unopenableKifCount = 0;
    final restoredKifs = <Map<String, dynamic>>[];
    for (final kif in kifs) {
      final row = Map<String, dynamic>.from(kif);
      final kifRowId = row['id'];
      final kifPath = row['kif_path'];

      if (kifRowId is int) {
        final restoredPath = kifPathByRowId[kifRowId];
        if (restoredPath != null) {
          row['kif_path'] = restoredPath;
        } else if (kifPath is String && kifPath.isNotEmpty) {
          unopenableKifCount++;
        }

        final restoredImgPath = imgPathByRowId[kifRowId];
        if (restoredImgPath != null) {
          row['img_path'] = restoredImgPath;
        }
      } else if (kifPath is String && kifPath.isNotEmpty) {
        unopenableKifCount++;
      }

      restoredKifs.add(row);
    }

    // 復元先のディレクトリは今回専用のものなので、既存データには影響しない。
    await kifDir.create(recursive: true);
    await thumbnailDir.create(recursive: true);
    for (final entry in kifEntries.entries) {
      await File(kifPathByRowId[entry.key.kifRowId]!)
          .writeAsBytes(entry.value, flush: true);
    }
    for (final entry in thumbnailEntries.entries) {
      await File(imgPathByRowId[entry.key.kifRowId]!)
          .writeAsBytes(entry.value, flush: true);
    }

    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.delete('position_appearance');
      await txn.delete('transition');
      await txn.delete('position');
      await txn.delete('kif');
      await txn.delete('tab');

      for (final row in tabs) {
        await txn.insert('tab', row);
      }
      for (final row in restoredKifs) {
        await txn.insert('kif', row);
      }
      for (final row in positions) {
        await txn.insert('position', row);
      }
      for (final row in transitions) {
        await txn.insert('transition', row);
      }
      for (final row in appearances) {
        await txn.insert('position_appearance', row);
      }
    });

    await _restoreSettings(settings);
    restoreRevision.value++;

    return BackupRestoreResult(
      restoredKifCount: restoredKifs.length,
      unopenableKifCount: unopenableKifCount,
    );
  }

  Archive _decodeArchive(Uint8List bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw BackupFormatException('バックアップファイルではありません');
    }
  }

  BackupManifest _readManifest(Archive archive) {
    final manifestFile = archive.find(_manifestEntryName);
    if (manifestFile == null) {
      throw BackupFormatException('バックアップファイルではありません');
    }
    final json = _decodeJsonObject(_readArchiveBytes(manifestFile));
    try {
      return BackupManifest.fromJson(json);
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw BackupFormatException('バックアップファイルの内容が不正です');
    }
  }

  Map<String, dynamic> _readJsonMap(Archive archive, String entryName) {
    final file = archive.find(entryName);
    if (file == null) {
      throw BackupFormatException('バックアップファイルの内容が不足しています');
    }
    return _decodeJsonObject(_readArchiveBytes(file));
  }

  Map<String, dynamic> _decodeJsonObject(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const FormatException();
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw BackupFormatException('バックアップファイルの内容が不正です');
    }
  }

  Uint8List _readArchiveBytes(ArchiveFile file) {
    final data = file.readBytes();
    if (data == null) {
      throw BackupFormatException('バックアップファイルの内容が不正です');
    }
    return data;
  }

  List<Map<String, dynamic>> _readRows(
    Map<String, dynamic> database,
    String key,
  ) {
    final value = database[key];
    if (value is! List) {
      throw BackupFormatException('バックアップファイルの内容が不正です');
    }
    final rows = <Map<String, dynamic>>[];
    for (final row in value) {
      if (row is! Map) {
        throw BackupFormatException('バックアップファイルの内容が不正です');
      }
      rows.add(Map<String, dynamic>.from(row));
    }
    return rows;
  }

  Future<Map<String, dynamic>> _exportDatabase(Database db) async {
    return {
      'tabs': await _queryRows(db, 'tab', orderBy: 'tab_order ASC'),
      'kifs': await _queryRows(db, 'kif', orderBy: 'id ASC'),
      'positions': await _queryRows(db, 'position', orderBy: 'id ASC'),
      'transitions': await _queryRows(db, 'transition', orderBy: 'id ASC'),
      'positionAppearances': await _queryRows(db, 'position_appearance'),
    };
  }

  Future<List<Map<String, dynamic>>> _queryRows(
    Database db,
    String table, {
    String? orderBy,
  }) async {
    final rows = await db.query(table, orderBy: orderBy);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Map<String, dynamic> _exportSettings() {
    try {
      final box = Hive.box('settings_box');
      return {
        for (final key in box.keys) '$key': box.get(key),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _restoreSettings(Map<String, dynamic> settings) async {
    try {
      final box = Hive.box('settings_box');
      await box.clear();
      for (final entry in settings.entries) {
        await box.put(entry.key, entry.value);
      }
    } catch (_) {
      // 設定ボックスが開けない環境では設定だけ復元できない。
    }
  }

  String _extensionOf(String path, String fallback) {
    final extension = p.extension(path).replaceAll(RegExp(r'[^A-Za-z0-9.]'), '');
    if (extension.length <= 1 || extension.length > 10) return fallback;
    return extension;
  }
}
