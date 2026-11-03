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
      version: 1,
      onCreate: _createDB,
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

    await _insertDefaultTabs(db);
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
