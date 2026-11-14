import 'package:kifdamari/database/database_helper.dart';
import 'package:kifdamari/database/entity/transition_entity.dart';
import 'package:sqflite/sqflite.dart';

class TransitionDao {
  static const int _chunkSize = 100;

  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<TransitionEntity>> getByFromPositionIds(
    List<int> positionIds, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _db;
    final uniqueIds = positionIds.toSet().toList();
    final result = <TransitionEntity>[];
    for (int i = 0; i < uniqueIds.length; i += _chunkSize) {
      final chunk = uniqueIds.skip(i).take(_chunkSize).toList();
      final rows = await db.query(
        'transition',
        where: 'from_position_id IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
      );
      result.addAll(rows.map((map) => TransitionEntity.fromMap(map)));
    }
    return result;
  }

  /// 指定した局面へ入ってくる枝（from → その局面）の一覧
  Future<List<TransitionEntity>> getByToPositionId(
    int positionId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _db;
    final rows = await db.query(
      'transition',
      where: 'to_position_id = ?',
      whereArgs: [positionId],
    );
    return rows.map((map) => TransitionEntity.fromMap(map)).toList();
  }

  Future<TransitionEntity?> getByFromAndMoveLabel(
    int fromPositionId,
    String moveLabel, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _db;
    final rows = await db.query(
      'transition',
      where: 'from_position_id = ? AND move_label = ?',
      whereArgs: [fromPositionId, moveLabel],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TransitionEntity.fromMap(rows.first);
  }

  Future<int> deleteByFromTo(
    int fromPositionId,
    int toPositionId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _db;
    return await db.delete(
      'transition',
      where: 'from_position_id = ? AND to_position_id = ?',
      whereArgs: [fromPositionId, toPositionId],
    );
  }

  Future<int> insert(TransitionEntity transition, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _db;
    return await db.insert(
      'transition',
      transition.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
