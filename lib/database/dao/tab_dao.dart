import 'package:sqflite/sqflite.dart';
import '../entity/tab_entity.dart';
import '../database_helper.dart';

class TabDao {
  // DatabaseHelperからDatabaseインスタンスを取得するヘルパーメソッド
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  // 1. 全てのタブを tab_order 順に取得する (Read)
  Future<List<TabEntity>> getAllTabs() async {
    final db = await _db;
    // Javaの db.query("tab", null, null, ...) に相当
    final result = await db.query('tab', orderBy: 'tab_order ASC');

    // List<Map> を List<TabEntity> に変換 (JavaのStream API風)
    return result.map((map) => TabEntity.fromMap(map)).toList();
  }

  // 2. 新しいタブを追加する (Create)
  Future<int> insertTab(TabEntity tab) async {
    final db = await _db;
    return await db.insert('tab', tab.toMap());
  }

  // 3. タブを削除する (Delete)
  // CASCADE設定により、紐づくkifデータも自動で消えます
  Future<int> deleteTab(int id) async {
    final db = await _db;
    return await db.delete(
      'tab',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 4. タブの並び順を更新する (Update)
  Future<void> updateTabOrder(int id, int newOrder) async {
    final db = await _db;
    await db.update(
      'tab',
      {'tab_order': newOrder},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // tab_orderの最大値を取得する
  Future<int> getMaxTabOrder() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT MAX(tab_order) as max_order FROM tab');
    final maxOrder = result.first['max_order'];
    if (maxOrder == null) {
      return 0; // データが1件もない場合は0を返す
    }    
    return maxOrder as int;
  }
}
