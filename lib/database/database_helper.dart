import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Future<Database>? _databaseFuture;

  DatabaseHelper._init();

  /// 初期化を一行で行い、複数の同時アクセスでも必ず同じ接続を共有する。
  /// 失敗した場合はキャッシュを破棄して、次回アクセス時に再試行できるようにする。
  Future<Database> get database async {
    if (_databaseFuture != null) {
      try {
        return await _databaseFuture!;
      } catch (_) {
        _databaseFuture = null;
        rethrow;
      }
    }
    final future = _initDB('kifdamari.db');
    _databaseFuture = future;
    try {
      return await future;
    } catch (_) {
      _databaseFuture = null;
      rethrow;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tab (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        tab_order INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE kif (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tab_id INTEGER NOT NULL,
        kif_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        detail TEXT,
        kif_order INTEGER NOT NULL,
        kif_path TEXT,
        img_path TEXT,
        color INTEGER,
        FOREIGN KEY (tab_id) REFERENCES tab (id) ON DELETE CASCADE
      )
    ''');

    await _createPositionTables(db);

    await _insertDefaultTabs(db);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPositionTables(db);
    }
  }

  Future _createPositionTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS position (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        position_key TEXT NOT NULL UNIQUE,
        is_root INTEGER NOT NULL DEFAULT 0,
        comment TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS transition (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_position_id INTEGER NOT NULL,
        to_position_id INTEGER NOT NULL,
        move_label TEXT NOT NULL,
        UNIQUE (from_position_id, move_label),
        FOREIGN KEY (from_position_id) REFERENCES position (id) ON DELETE CASCADE,
        FOREIGN KEY (to_position_id) REFERENCES position (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS position_appearance (
        position_id INTEGER NOT NULL,
        kif_id INTEGER NOT NULL,
        move_number INTEGER NOT NULL,
        PRIMARY KEY (position_id, kif_id, move_number),
        FOREIGN KEY (position_id) REFERENCES position (id) ON DELETE CASCADE,
        FOREIGN KEY (kif_id) REFERENCES kif (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _insertDefaultTabs(Database db) async {
    final List<String> defaultTabs = ['四間飛車', '矢倉', '中飛車'];
    for (int i = 0; i < defaultTabs.length; i++) {
      await db.insert('tab', {
        'title': defaultTabs[i],
        'tab_order': i,
      });
    }
  }
}
