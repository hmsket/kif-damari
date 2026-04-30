import 'package:sqflite/sqflite.dart';
import '../entity/tab_entity.dart';
import '../database_helper.dart';

class TabDao {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<TabEntity>> getAllTabs() async {
    final db = await _db;
    final result = await db.query('tab', orderBy: 'tab_order ASC');
    return result.map((map) => TabEntity.fromMap(map)).toList();
  }

  Future<int> insertTab(TabEntity tab) async {
    final db = await _db;
    return await db.insert('tab', tab.toMap());
  }

  Future<int> updateTab(TabEntity tab) async {
    final db = await _db;
    return await db.update(
      'tab',
      tab.toMap(),
      where: 'id = ?',
      whereArgs: [tab.id],
    );
  }
  
  Future<int> deleteTab(int id) async {
    final db = await _db;
    return await db.delete(
      'tab',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTabOrder(int id, int newOrder) async {
    final db = await _db;
    await db.update(
      'tab',
      {'tab_order': newOrder},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getMaxTabOrder() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT MAX(tab_order) as max_order FROM tab');
    final maxOrder = result.first['max_order'];
    if (maxOrder == null) {
      return 0;
    }    
    return maxOrder as int;
  }

  Future<int> countTabByName(String name) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM tab WHERE title = ?',
      [name],
    );
    if (result.isNotEmpty) {
      return result.first['count'] as int;
    }
    return 0;
  }
}
