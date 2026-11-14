import 'package:kifdamari/database/database_helper.dart';
import 'package:kifdamari/database/entity/position_entity.dart';
import 'package:sqflite/sqflite.dart';

class PositionDao {
  static const int _chunkSize = 100;

  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<PositionEntity>> getByKeys(List<String> keys, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _db;
    final uniqueKeys = keys.toSet().toList();
    final result = <PositionEntity>[];
    for (int i = 0; i < uniqueKeys.length; i += _chunkSize) {
      final chunk = uniqueKeys.skip(i).take(_chunkSize).toList();
      final rows = await db.query(
        'position',
        where: 'position_key IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
      );
      result.addAll(rows.map((map) => PositionEntity.fromMap(map)));
    }
    return result;
  }

  Future<List<PositionEntity>> getByIds(List<int> ids, {DatabaseExecutor? executor}) async {
    if (ids.isEmpty) return [];
    final db = executor ?? await _db;
    final uniqueIds = ids.toSet().toList();
    final result = <PositionEntity>[];
    for (int i = 0; i < uniqueIds.length; i += _chunkSize) {
      final chunk = uniqueIds.skip(i).take(_chunkSize).toList();
      final rows = await db.query(
        'position',
        where: 'id IN (${List.filled(chunk.length, '?').join(',')})',
        whereArgs: chunk,
      );
      result.addAll(rows.map((map) => PositionEntity.fromMap(map)));
    }
    return result;
  }

  Future<PositionEntity?> getByKey(String key, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _db;
    final rows = await db.query(
      'position',
      where: 'position_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PositionEntity.fromMap(rows.first);
  }

  Future<int> insert(PositionEntity position, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _db;
    return await db.insert('position', position.toMap());
  }

  Future<void> updateComment(int id, String comment, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _db;
    await db.update(
      'position',
      {'comment': comment},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAsRoot(int id, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _db;
    await db.update(
      'position',
      {'is_root': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<PositionEntity>> getRoots({DatabaseExecutor? executor}) async {
    final db = executor ?? await _db;
    final rows = await db.query(
      'position',
      where: 'is_root = 1',
      orderBy: 'id ASC',
    );
    return rows.map((map) => PositionEntity.fromMap(map)).toList();
  }

  /// 登録済みの全局面の position_key 一覧を返す（局面検索の走査用）
  Future<List<String>> getAllKeys({DatabaseExecutor? executor}) async {
    final db = executor ?? await _db;
    final rows = await db.query('position', columns: ['position_key']);
    return rows.map((row) => row['position_key'] as String).toList();
  }
}
