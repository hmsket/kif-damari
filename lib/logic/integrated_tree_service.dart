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
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/models/game_node.dart';
import 'package:kifdamari/models/kif_tree.dart';
import 'package:sqflite/sqflite.dart';

/// 根選択画面の1行分
class IntegratedTreeRootSummary {
  final PositionEntity position;
  final String kindLabel;
  final int kifuCount;
  final int positionCount;

  const IntegratedTreeRootSummary({
    required this.position,
    required this.kindLabel,
    required this.kifuCount,
    required this.positionCount,
  });
}

/// 統合ツリーを根から展開したもの（ゲームプレイ用の positionId 対応表を含む）
class IntegratedTree {
  final GameNode root;
  final Map<String, int> positionIdByKey;

  const IntegratedTree(this.root, this.positionIdByKey);
}

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

  /// 根（開始局面）の一覧を「この根の棋譜 n 件・局面 n」付きで返す。
  /// 棋譜が1つも出現しない根は除外する。
  static Future<List<IntegratedTreeRootSummary>> listRoots() async {
    try {
      final roots = await PositionDao().getRoots();
      final summaries = <IntegratedTreeRootSummary>[];
      for (final root in roots) {
        if (root.id == null) continue;
        final kifuCount = (await PositionAppearanceDao().getKifIdsForPosition(root.id!)).length;
        if (kifuCount == 0) continue;

        final positionCount = await _countPositionsFrom(root.id!);
        summaries.add(IntegratedTreeRootSummary(
          position: root,
          kindLabel: describeRootKind(root.positionKey),
          kifuCount: kifuCount,
          positionCount: positionCount,
        ));
      }
      return summaries;
    } catch (e) {
      debugPrint('統合ツリーの根一覧の取得に失敗しました: $e');
      return [];
    }
  }

  // 根から指せる到達局面数（transition を辿る BFS）
  static Future<int> _countPositionsFrom(int rootId) async {
    final transitionDao = TransitionDao();
    final visited = <int>{rootId};
    var frontier = <int>[rootId];
    while (frontier.isNotEmpty) {
      final edges = await transitionDao.getByFromPositionIds(frontier);
      final nextIds = edges.map((e) => e.toPositionId).where((id) => !visited.contains(id)).toSet();
      if (nextIds.isEmpty) break;
      visited.addAll(nextIds);
      frontier = nextIds.toList();
      if (visited.length > 100000) break;
    }
    return visited.length;
  }

  /// 根の開始局面の種類をラベル化する（平手／各種駒落ち／途中開始）
  static String describeRootKind(String positionKey) {
    try {
      if (positionKey == SfenGenerator.generateKey(BoardState.initial())) {
        return '平手';
      }

      final state = SfenGenerator.stateFromKey(positionKey);

      // どちらか一方の駒台が空で、盤上の駒が各陣の初期配置域だけで並んでいるか（＝駒落ちかどうか）
      bool isStartLike = state.senteHand.isEmpty && state.goteHand.isEmpty;
      if (isStartLike) {
        loop:
        for (int y = 0; y < 9; y++) {
          for (int x = 0; x < 9; x++) {
            final piece = state.grid[y][x];
            if (piece == null) continue;
            if (y >= 3 && y <= 5) {
              isStartLike = false;
              break loop;
            }
            if (piece.startsWith('b') && y < 6) {
              isStartLike = false;
              break loop;
            }
            if (piece.startsWith('w') && y > 2) {
              isStartLike = false;
              break loop;
            }
          }
        }
      }

      if (!isStartLike) return '途中開始';

      // 各手の標準駒数（玉を除く）：歩9 香2 桂2 銀2 金2 飛1 角1
      const standardCounts = {
        'fu': 9, 'ya': 2, 'ke': 2, 'gi': 2, 'ki': 2, 'hi': 1, 'ka': 1,
      };

      Map<String, int> missingFor(bool sente) {
        final missing = <String, int>{};
        for (final entry in standardCounts.entries) {
          final onBoard = state.grid
              .expand((row) => row)
              .whereType<String>()
              .where((p) => p.startsWith(sente ? 'b' : 'w') && p.substring(1) == entry.key)
              .length;
          final inHand = sente
              ? (state.senteHand[entry.key] ?? 0)
              : (state.goteHand[entry.key] ?? 0);
          final shortage = entry.value - onBoard - inHand;
          if (shortage > 0) missing[entry.key] = shortage;
        }
        return missing;
      }

      final senteMissing = missingFor(true);
      final goteMissing = missingFor(false);

      if (senteMissing.isEmpty && goteMissing.isEmpty) return '途中開始';
      if (senteMissing.isNotEmpty && goteMissing.isNotEmpty) return '途中開始';

      final missing = senteMissing.isNotEmpty ? senteMissing : goteMissing;
      return _handicapName(missing);
    } catch (e) {
      return '途中開始';
    }
  }

  static String _handicapName(Map<String, int> missing) {
    final int total = missing.values.fold(0, (a, b) => a + b);
    if (total == 1) {
      final type = missing.keys.first;
      switch (type) {
        case 'hi': return '飛落ち';
        case 'ka': return '角落ち';
        case 'ki': return '金落ち';
        case 'gi': return '銀落ち';
        case 'ke': return '桂落ち';
        case 'ya': return '香落ち';
        case 'fu': return '歩落ち';
      }
    }
    final signature = missing.entries
        .map((e) => '${e.key}x${e.value}')
        .toList()
      ..sort();
    switch (signature.join(',')) {
      case 'hix1,kax1':
        return '二枚落ち';
      case 'hix1,kax1,kix1':
        return '三枚落ち';
      case 'hix1,kax1,kix2':
        return '四枚落ち';
    }
    return '$total枚落ち';
  }

  /// 指定した根から統合ツリーをメモリ上に展開する。
  /// 合流はツリーの複製として展開し、祖先に戻るエッジ（＝循環）のみスキップする。
  static Future<IntegratedTree?> buildTreeFromRoot(PositionEntity root) async {
    try {
      final rootState = SfenGenerator.stateFromKey(root.positionKey);
      final rootNode = GameNode(
        moveNumber: 0,
        state: rootState,
        moveLabel: '開始局面',
      );
      rootNode.positionKey = root.positionKey;
      _applyCommentsToNode(rootNode, root.comment);

      final positionIdByKey = <String, int>{root.positionKey: root.id!};
      final positionKeyById = <int, String>{root.id!: root.positionKey};
      final commentsById = <int, String>{root.id!: root.comment};

      var frontier = <GameNode>[rootNode];
      final transitionDao = TransitionDao();
      final positionDao = PositionDao();

      int nodeCount = 1;
      while (frontier.isNotEmpty) {
        if (nodeCount > 20000) break;

        final fromIds = frontier
            .map((node) => positionIdByKey[node.positionKey!])
            .whereType<int>()
            .toSet()
            .toList();
        if (fromIds.isEmpty) break;

        final edges = await transitionDao.getByFromPositionIds(fromIds);

        // 未取得の子局面を読み込む
        final newToIds = edges.map((e) => e.toPositionId).where((id) => !positionKeyById.containsKey(id)).toSet().toList();
        if (newToIds.isNotEmpty) {
          final toPositions = await positionDao.getByIds(newToIds);
          for (final position in toPositions) {
            positionKeyById[position.id!] = position.positionKey;
            positionIdByKey[position.positionKey] = position.id!;
            commentsById[position.id!] = position.comment;
          }
        }

        final edgesByFrom = <int, List<TransitionEntity>>{};
        for (final edge in edges) {
          edgesByFrom.putIfAbsent(edge.fromPositionId, () => []).add(edge);
        }

        final nextFrontier = <GameNode>[];
        for (final node in frontier) {
          final fromId = positionIdByKey[node.positionKey!]!;
          final children = edgesByFrom[fromId] ?? const [];
          for (final edge in children) {
            final toKey = positionKeyById[edge.toPositionId];
            if (toKey == null) continue;

            // 循環（祖先へ戻る枝）のみスキップ。合流由来の複製は許す
            if (_hasAncestorWithKey(node, toKey)) continue;

            final child = GameNode(
              moveNumber: node.moveNumber + 1,
              state: SfenGenerator.stateFromKey(toKey),
              moveLabel: edge.moveLabel,
            );
            child.positionKey = toKey;
            _applyCommentsToNode(child, commentsById[edge.toPositionId] ?? '');
            node.nextNodes.add(child);
            nextFrontier.add(child);
            nodeCount++;
          }
        }
        frontier = nextFrontier;
      }

      return IntegratedTree(rootNode, positionIdByKey);
    } catch (e) {
      debugPrint('統合ツリーの構築に失敗しました: $e');
      return null;
    }
  }

  static bool _hasAncestorWithKey(GameNode node, String key) {
    GameNode? temp = node.parent;
    while (temp != null) {
      if (temp.positionKey == key) return true;
      temp = temp.parent;
    }
    return false;
  }

  static void _applyCommentsToNode(GameNode node, String comment) {
    node.comments
      ..clear()
      ..addAll(comment.isEmpty ? <String>[] : comment.split('\n'));
  }

  /// 盤面で指された手を統合ツリーへ登録し、乗るべき子ノードを返す。
  /// 既存の子（同じ局面キー、または同じ指し手コードの枝）があればそれに乗る。
  /// 新規の手は局面・枝として永続化される（どの棋譜にも所属しない）。
  static Future<(GameNode, int)?> playMove({
    required GameNode parentNode,
    required int parentPositionId,
    required BoardState nextState,
  }) async {
    try {
      final childKey = SfenGenerator.generateKey(nextState);
      final moveLabel = SfenGenerator.moveCode(
        fromState: parentNode.state,
        toState: nextState,
        fallbackLabel: '',
      );
      if (moveLabel.isEmpty) return null;

      final db = await DatabaseHelper.instance.database;
      return await db.transaction((txn) async {
        final positionDao = PositionDao();
        final transitionDao = TransitionDao();

        // 同じ指し手コードの既存枝があればそこへ合流
        TransitionEntity? edge = await transitionDao.getByFromAndMoveLabel(
          parentPositionId,
          moveLabel,
          executor: txn,
        );

        // 同じ結果局面を持つ既存枝（＝手順前後の合流）があればそれへ合流
        if (edge == null) {
          final parentEdges = await transitionDao.getByFromPositionIds([parentPositionId], executor: txn);
          if (parentEdges.isNotEmpty) {
            final toIds = parentEdges.map((e) => e.toPositionId).toSet().toList();
            final toPositions = await positionDao.getByIds(toIds, executor: txn);
            for (final edgeCandidate in parentEdges) {
              final match = toPositions.where((p) => p.id == edgeCandidate.toPositionId && p.positionKey == childKey);
              if (match.isNotEmpty) {
                edge = edgeCandidate;
                break;
              }
            }
          }
        }

        if (edge != null) {
          return await _createChildNodeWithDb(
            parentNode,
            nextState,
            moveLabel,
            edge.toPositionId,
            executor: txn,
          );
        }

        // 新規：局面を登録（既存ならその id を使う）
        final existingPosition = await positionDao.getByKey(childKey, executor: txn);
        final childPositionId = existingPosition?.id ??
            await positionDao.insert(PositionEntity(positionKey: childKey), executor: txn);

        await transitionDao.insert(
          TransitionEntity(
            fromPositionId: parentPositionId,
            toPositionId: childPositionId,
            moveLabel: moveLabel,
          ),
          executor: txn,
        );

        return await _createChildNodeWithDb(
          parentNode,
          nextState,
          moveLabel,
          childPositionId,
          executor: txn,
        );
      });
    } catch (e) {
      debugPrint('統合ツリーへの指し手登録に失敗しました: $e');
      return null;
    }
  }

  /// 現在局面のコメントを1行文字列として保存する（局面コメントは棋譜に共通）
  static Future<bool> savePositionComment(int positionId, String comment) async {
    try {
      await PositionDao().updateComment(positionId, comment);
      return true;
    } catch (e) {
      debugPrint('局面コメントの保存に失敗しました: $e');
      return false;
    }
  }

  static Future<(GameNode, int)> _createChildNodeWithDb(
    GameNode parentNode,
    BoardState nextState,
    String moveLabel,
    int childPositionId, {
    required DatabaseExecutor executor,
  }) async {
    final rows = await executor.query(
      'position',
      where: 'id = ?',
      whereArgs: [childPositionId],
      limit: 1,
    );
    final comment = rows.isNotEmpty ? ((rows.first['comment'] as String?) ?? '') : '';
    final childKey = rows.isNotEmpty ? (rows.first['position_key'] as String) : '';

    final child = GameNode(
      moveNumber: parentNode.moveNumber + 1,
      state: nextState,
      moveLabel: moveLabel,
    );
    child.positionKey = childKey;
    _applyCommentsToNode(child, comment);
    return (child, childPositionId);
  }
}
