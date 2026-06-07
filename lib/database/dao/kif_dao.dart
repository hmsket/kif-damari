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

  Future<void> insertKif(KifEntity kif) async {
    final db = await _db;
    await db.transaction((txn) async {
      final result = await txn.rawQuery(
        'SELECT MAX(kif_id) as max_id FROM kif WHERE tab_id = ?',
        [kif.tabId],
      );
      int nextKifId = (result.first['max_id'] as int? ?? 0) + 1;
      final kifMap = kif.toMap();
      kifMap['kif_id'] = nextKifId;
      await txn.insert('kif', kifMap);
    });
  }

  Future<int> deleteKif(int tabId, int kifId) async {
    final db = await _db;
    return await db.delete(
      'kif',
      where: 'tab_id = ? AND kif_id = ?',
      whereArgs: [tabId, kifId],
    );
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

  Future<int> getTotalKifCount() async {
    final db = await _db;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM kif'),
    );
    return count ?? 0;
  }
}
