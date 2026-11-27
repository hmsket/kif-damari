import 'package:kifdamari/database/database_helper.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:sqflite/sqflite.dart';

class KifDao {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

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

  /// 全タブの棋譜を取得する（ホームの検索用）。
  Future<List<KifEntity>> getAllKifs() async {
    final db = await _db;
    final result = await db.query(
      'kif',
      orderBy: 'tab_id ASC, kif_order ASC',
    );
    return result.map((map) => KifEntity.fromMap(map)).toList();
  }

  Future<List<KifEntity>> getByIds(List<int> ids) async {
    final uniqueIds = ids.toSet().toList();
    if (uniqueIds.isEmpty) return [];
    final db = await _db;
    final result = <KifEntity>[];
    for (int i = 0; i < uniqueIds.length; i += 100) {
      final chunk = uniqueIds.skip(i).take(100).toList();
      final rows = await db.query(
        'kif',
        where: 'id IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
      );
      result.addAll(rows.map((map) => KifEntity.fromMap(map)));
    }
    return result;
  }

  Future<List<KifEntity>> getPendingKifs() async {
    final db = await _db;
    final result = await db.query(
      'kif',
      where: 'pending_tree_uri IS NOT NULL AND pending_tree_uri != ?',
      whereArgs: [''],
      orderBy: 'id ASC',
    );
    return result.map((map) => KifEntity.fromMap(map)).toList();
  }

  Future<int> insertKif(KifEntity kif) async {
    final db = await _db;
    int insertedId = 0;
    await db.transaction((txn) async {
      final result = await txn.rawQuery(
        'SELECT MAX(kif_id) as max_id FROM kif WHERE tab_id = ?',
        [kif.tabId],
      );
      int nextKifId = (result.first['max_id'] as int? ?? 0) + 1;
      final kifMap = kif.toMap();
      kifMap['kif_id'] = nextKifId;

      insertedId = await txn.insert('kif', kifMap);
    });
    return insertedId;
  }

  Future<int> deleteKif(int tabId, int kifId) async {
    final db = await _db;
    return await db.delete(
      'kif',
      where: 'tab_id = ? AND kif_id = ?',
      whereArgs: [tabId, kifId],
    );
  }

  Future<void> deleteKifs(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'kif',
        where: 'id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
      );
    });
  }

  Future<void> updateKif(KifEntity kif) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'kif',
      kif.toMap(),
      where: 'id = ?',
      whereArgs: [kif.id],
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
      return 0;
    }
    return maxId as int;
  }

  Future<void> updateAllKifOrders(List<KifEntity> kifs) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (int i = 0; i < kifs.length; i++) {
        await txn.update(
          'kif',
          {'kif_order': i},
          where: 'id = ?',
          whereArgs: [kifs[i].id],
        );
      }
    });
  }

  /// 棋譜を別タブの末尾へ移動する。
  ///
  /// 移動先では新しい kif_id と kif_order を採番し、元のタブに残った
  /// 棋譜の kif_order は順序を保ったまま詰め直す。
  Future<void> moveKifToTab(KifEntity kif, int targetTabId) async {
    final id = kif.id;
    if (id == null || kif.tabId == targetTabId) return;
    final db = await _db;
    await db.transaction((txn) async {
      final maxKifIdResult = await txn.rawQuery(
        'SELECT MAX(kif_id) as max_id FROM kif WHERE tab_id = ?',
        [targetTabId],
      );
      final nextKifId = (maxKifIdResult.first['max_id'] as int? ?? 0) + 1;

      final maxOrderResult = await txn.rawQuery(
        'SELECT MAX(kif_order) as max_order FROM kif WHERE tab_id = ?',
        [targetTabId],
      );
      final maxOrder = maxOrderResult.first['max_order'] as int?;
      final nextOrder = maxOrder == null ? 0 : maxOrder + 1;

      await txn.update(
        'kif',
        {
          'tab_id': targetTabId,
          'kif_id': nextKifId,
          'kif_order': nextOrder,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // 元のタブに残った棋譜の並び順を詰め直す。
      final remaining = await txn.query(
        'kif',
        columns: ['id'],
        where: 'tab_id = ?',
        whereArgs: [kif.tabId],
        orderBy: 'kif_order ASC',
      );
      for (int i = 0; i < remaining.length; i++) {
        await txn.update(
          'kif',
          {'kif_order': i},
          where: 'id = ?',
          whereArgs: [remaining[i]['id']],
        );
      }
    });
  }

  Future<int> getTotalKifCount() async {
    final db = await _db;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM kif'),
    );
    return count ?? 0;
  }
}
