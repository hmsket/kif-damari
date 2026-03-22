import 'package:sqflite/sqflite.dart';
import '../entity/kif_entity.dart';
import '../database_helper.dart';

class KifDao {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  // 1. 特定のタブ(tab_id)に属する棋譜を kif_order 順に取得
  Future<List<KifEntity>> getKifsByTab(int tabId) async {
    final db = await _db;
    final result = await db.query(
      'kif',
      where: 'tab_id = ?',
      whereArgs: [tabId],
      orderBy: 'kif_order ASC',
    );

    return result.map((map) => KifEntity.fromMap(map)).toList();
  }

  // 2. 新規保存（kif_id の自動採番ロジックを含む）
  Future<void> insertKif(int tabId, String title, String kifPath) async {
    final db = await _db;

    // トランザクションで実行（採番の整合性を保つため）
    await db.transaction((txn) async {
      // 現在の tab_id における最大の kif_id を取得
      final result = await txn.rawQuery(
        'SELECT MAX(kif_id) as max_id FROM kif WHERE tab_id = ?',
        [tabId],
      );
      int nextKifId = (result.first['max_id'] as int? ?? 0) + 1;

      // 現在の tab_id における最大の kif_order を取得
      final orderResult = await txn.rawQuery(
        'SELECT MAX(kif_order) as max_order FROM kif WHERE tab_id = ?',
        [tabId],
      );
      int nextOrder = (orderResult.first['max_order'] as int? ?? 0) + 1;

      // 保存実行
      await txn.insert('kif', {
        'tab_id': tabId,
        'kif_id': nextKifId,
        'title': title,
        'kif_order': nextOrder,
        'kif_path': kifPath,
        // 必要に応じて他のカラムも追加
      });
    });
  }

  // 3. 削除（複合キーを指定）
  Future<int> deleteKif(int tabId, int kifId) async {
    final db = await _db;
    return await db.delete(
      'kif',
      where: 'tab_id = ? AND kif_id = ?',
      whereArgs: [tabId, kifId],
    );
  }

  // 4. 更新（複合キーを指定）
  Future<int> updateKif(KifEntity kif) async {
    final db = await _db;
    return await db.update(
      'kif',
      kif.toMap(),
      where: 'tab_id = ? AND kif_id = ?',
      whereArgs: [kif.tabId, kif.kifId],
    );
  }
}
