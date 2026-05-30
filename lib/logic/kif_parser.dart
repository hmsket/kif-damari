import 'package:kifdamari/models/game_node.dart';
import 'package:kifdamari/models/kif_tree.dart';

class KifParser {
  static const _zenToNum = {'１': 1, '２': 2, '３': 3, '４': 4, '５': 5, '６': 6, '７': 7, '８': 8, '９': 9};
  static const _kanToNum = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9};

  static KifTree decode(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final tree = KifTree.initial();
    GameNode currentNode = tree.root;

    // ヘッダー情報(キーワード：値)
    final infoRegex = RegExp(r"^([^：:]+)[：:](.*)$");
    
    // 指し手解析
    final moveRegex = RegExp(r"^\s*(\d+)\s+([１-９同])\s*([一二三四五六七八九　]?)\s*([^\s(]+)(?:\((\d)(\d)\))?");

    // 「変化：46手目」などの変化行を検出するための正規表現
    final branchRegex = RegExp(r"^変化[：:\s]*(\d+)\s*手(?:目)?");

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // コメント行 (*で始まる)
      if (trimmedLine.startsWith('*')) {
        currentNode.addComment(trimmedLine.substring(1));
        continue;
      }

      // 変化行の検出
      final branchMatch = branchRegex.firstMatch(trimmedLine);
      if (branchMatch != null) {
        final branchMoveNum = int.parse(branchMatch.group(1)!);
        final targetParentMoveNum = branchMoveNum - 1; // 探したい親ノード自身の「手数」

        // 現在地からルートに向かって遡り、
        // 「ノード自身の手数」が、探したい親の手数（例: 31）とピッタリ一致するものを探す
        GameNode? targetParent = currentNode;
        bool found = false;

        while (targetParent != null) {
          if (targetParent.moveNumber == targetParentMoveNum) {
            currentNode = targetParent; // その局面を親にする
            found = true;
            break;
          }
          targetParent = targetParent.parent;
        }
        
        // 直系の先祖にいなかった場合のみ、ルートから本譜を辿る
        if (!found) {
          GameNode backup = tree.root;
          for (int i = 0; i < targetParentMoveNum; i++) {
            if (backup.nextNodes.isNotEmpty) {
              backup = backup.nextNodes.first;
            }
          }
          currentNode = backup; 
        }
        continue;
      }

      // 指し手行 (数字で始まる)
      final moveMatch = moveRegex.firstMatch(trimmedLine);
      if (moveMatch != null) {
        final moveNum = int.parse(moveMatch.group(1)!);
        final firstChar = moveMatch.group(2)!;
        final secondChar = moveMatch.group(3)?.trim() ?? "";
        final pieceName = moveMatch.group(4)!;
        final fromXStr = moveMatch.group(5);
        final fromYStr = moveMatch.group(6);

        int toX, toY;
        if (firstChar == '同') {
          if (currentNode.state.lastMoveToX == null || currentNode.state.lastMoveToY == null) {
            toX = 0; toY = 0;
          } else {
            toX = currentNode.state.lastMoveToX!;
            toY = currentNode.state.lastMoveToY!;
          }
        } else {
          toX = _zenToNum[firstChar]!;
          toY = _kanToNum[secondChar]!;
        }

        int? fromX = fromXStr != null ? int.parse(fromXStr) : null;
        int? fromY = fromYStr != null ? int.parse(fromYStr) : null;

        // 局面更新
        final nextState = currentNode.state.movePiece(
          fromX: fromX, fromY: fromY,
          toX: toX, toY: toY,
          pieceName: pieceName,
        );

        final cleanMoveLabel = trimmedLine
            .split(RegExp(r'\s+'))
            .skip(1)
            .join(' ')
            .replaceAll('+', '');

        // ノード作成
        final newNode = GameNode(
          moveNumber: moveNum,
          moveLabel: cleanMoveLabel,
          state: nextState,
        );

        currentNode.addChild(newNode);
        currentNode = newNode;
        continue;
      }

      final infoMatch = infoRegex.firstMatch(trimmedLine);
      if (infoMatch != null) {
        final key = infoMatch.group(1)!.trim();
        final value = infoMatch.group(2)!.trim();
        if (!key.startsWith('手数')) {
          tree.info[key] = value;
        }
      }
    }
    return tree;
  }
}
