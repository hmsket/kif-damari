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
  Future<void> insertKif(KifEntity kif) async {
    final db = await _db;

    await db.transaction((txn) async {
      // 採番ロジック（以前と同じ）
      final result = await txn.rawQuery(
        'SELECT MAX(kif_id) as max_id FROM kif WHERE tab_id = ?',
        [kif.tabId],
      );
      int nextKifId = (result.first['max_id'] as int? ?? 0) + 1;

      // Entity を Map に変換（Entityクラスで toMap を定義しておく）
      final kifMap = kif.toMap();
      kifMap['kif_id'] = nextKifId; // 採番したIDを上書き

      // 保存実行
      await txn.insert('kif', kifMap);
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

  Future<int> getMaxKifId(int tabId) async {
    final db = await _db;
    final List<Map<String, Object?>> result = await db.rawQuery(
      'SELECT MAX(kif_id) as max_id FROM kif WHERE tab_id = ?',
      [tabId],
    );
    final maxId = result.first['max_id'];
    if (maxId == null) {
      return 0; // まだそのタブに棋譜がない場合は 0 を返す
    }
    return maxId as int;
  }

}
