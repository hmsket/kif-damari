import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // シングルトンパターンの実装
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // DBインスタンスを取得するゲッター
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kifdamari.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: _onConfigure, // 外部キー制約の有効化
    );
  }

  // Javaの onConfigure 相当：SQLiteのオプション設定
  Future _onConfigure(Database db) async {
    // 外部キー制aryを有効にする（CASCADEを効かせるために必須）
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Javaの onCreate 相当：テーブル作成
  Future _createDB(Database db, int version) async {
    // 1. tab テーブルの作成
    await db.execute('''
      CREATE TABLE tab (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        tab_order INTEGER NOT NULL
      )
    ''');

    // 2. kif テーブルの作成（複合キー制約付き）
    await db.execute('''
      CREATE TABLE kif (
        tab_id INTEGER NOT NULL,
        kif_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        detail TEXT,
        kif_order INTEGER NOT NULL,
        kif_path TEXT,
        img_path TEXT,
        color INTEGER,
        PRIMARY KEY (tab_id, kif_id),
        FOREIGN KEY (tab_id) REFERENCES tab (id) ON DELETE CASCADE
      )
    ''');

    // 初期データ（デフォルトのタブ）を入れておくと開発が楽です
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
