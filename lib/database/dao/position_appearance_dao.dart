import 'package:kifdamari/database/database_helper.dart';
import 'package:kifdamari/database/entity/position_appearance_entity.dart';
import 'package:sqflite/sqflite.dart';

class PositionAppearanceDao {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<PositionAppearanceEntity>> getByPositionId(
    int positionId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _db;
    final rows = await db.query(
      'position_appearance',
      where: 'position_id = ?',
      whereArgs: [positionId],
      orderBy: 'kif_id ASC, move_number ASC',
    );
    return rows.map((map) => PositionAppearanceEntity.fromMap(map)).toList();
  }

  Future<void> replaceForKif(
    int kifId,
    List<PositionAppearanceEntity> appearances, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _db;
    await db.delete(
      'position_appearance',
      where: 'kif_id = ?',
      whereArgs: [kifId],
    );
    for (final appearance in appearances) {
      await db.insert(
        'position_appearance',
        appearance.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}
