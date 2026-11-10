import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:kifdamari/database/dao/position_appearance_dao.dart';
import 'package:kifdamari/database/dao/position_dao.dart';
import 'package:kifdamari/database/dao/transition_dao.dart';
import 'package:kifdamari/database/database_helper.dart';
import 'package:kifdamari/database/entity/position_appearance_entity.dart';
import 'package:kifdamari/database/entity/position_entity.dart';
import 'package:kifdamari/database/entity/transition_entity.dart';
import 'package:kifdamari/logic/position_comment_merger.dart';
import 'package:kifdamari/logic/sfen_generator.dart';
import 'package:kifdamari/models/game_node.dart';
import 'package:kifdamari/models/kif_tree.dart';

class IntegratedTreeService {
  static Future<void> registerKifTree(KifTree tree, {int? kifId}) async {
    try {
      final nodes = <GameNode>[];
      final queue = Queue<GameNode>();
      queue.add(tree.root);
      while (queue.isNotEmpty) {
        final node = queue.removeFirst();
        nodes.add(node);
        queue.addAll(node.nextNodes);
      }

      final keyByNode = <GameNode, String>{};
      final uniqueKeys = <String>{};
      for (final node in nodes) {
        final key = SfenGenerator.generateKey(node.state);
        keyByNode[node] = key;
        uniqueKeys.add(key);
      }

      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        final positionDao = PositionDao();
        final existingPositions = await positionDao.getByKeys(uniqueKeys.toList(), executor: txn);
        final idByKey = <String, int>{};
        final commentById = <int, String>{};
        for (final position in existingPositions) {
          idByKey[position.positionKey] = position.id!;
          commentById[position.id!] = position.comment;
        }

        for (final node in nodes) {
          final key = keyByNode[node]!;
          if (!idByKey.containsKey(key)) {
            final insertedId = await positionDao.insert(
              PositionEntity(
                positionKey: key,
                isRoot: node.parent == null,
              ),
              executor: txn,
            );
            idByKey[key] = insertedId;
            commentById[insertedId] = '';
          } else if (node.parent == null) {
            await positionDao.markAsRoot(idByKey[key]!, executor: txn);
          }
        }

        for (final node in nodes) {
          final positionId = idByKey[keyByNode[node]!]!;
          node.positionKey = keyByNode[node];

          final existingComment = commentById[positionId] ?? '';
          final merged = PositionCommentMerger.merge(
            existingComment,
            node.comments.join('\n'),
          );
          if (merged != existingComment) {
            await positionDao.updateComment(positionId, merged, executor: txn);
          }
          commentById[positionId] = merged;

          node.comments
            ..clear()
            ..addAll(merged.isEmpty ? <String>[] : merged.split('\n'));
        }

        final transitionDao = TransitionDao();
        final fromPositionIds = <int>{};
        for (final node in nodes) {
          final parent = node.parent;
          if (parent == null) continue;
          fromPositionIds.add(idByKey[keyByNode[parent]!]!);
        }
        final existingTransitions = await transitionDao.getByFromPositionIds(
          fromPositionIds.toList(),
          executor: txn,
        );
        final existingTransitionKeys = existingTransitions
            .map((transition) => '${transition.fromPositionId}:${transition.moveLabel}')
            .toSet();

        for (final node in nodes) {
          final parent = node.parent;
          if (parent == null) continue;
          final fromId = idByKey[keyByNode[parent]!]!;
          final moveLabel = SfenGenerator.moveCode(
            fromState: parent.state,
            toState: node.state,
            fallbackLabel: node.moveLabel ?? '',
          );
          final transitionKey = '$fromId:$moveLabel';
          if (existingTransitionKeys.contains(transitionKey)) continue;
          existingTransitionKeys.add(transitionKey);
          await transitionDao.insert(
            TransitionEntity(
              fromPositionId: fromId,
              toPositionId: idByKey[keyByNode[node]!]!,
              moveLabel: moveLabel,
            ),
            executor: txn,
          );
        }

        if (kifId != null) {
          final appearances = <PositionAppearanceEntity>[];
          for (final node in nodes) {
            appearances.add(PositionAppearanceEntity(
              positionId: idByKey[keyByNode[node]!]!,
              kifId: kifId,
              moveNumber: node.moveNumber,
            ));
          }
          await PositionAppearanceDao().replaceForKif(kifId, appearances, executor: txn);
        }
      });
    } catch (e) {
      debugPrint('統合ツリーへの登録に失敗しました: $e');
    }
  }
}
