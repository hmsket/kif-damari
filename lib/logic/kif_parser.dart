import '../models/game_node.dart';
import '../models/kif_tree.dart';

class KifParser {
  static const _zenToNum = {'１': 1, '２': 2, '３': 3, '４': 4, '５': 5, '６': 6, '７': 7, '８': 8, '９': 9};
  static const _kanToNum = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9};

  static KifTree decode(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final tree = KifTree.initial();
    GameNode currentNode = tree.root;

    // ヘッダー情報(キーワード：値)用
    final infoRegex = RegExp(r"^([^：:]+)[：:](.*)$");
    
    // 指し手解析用
    // 1:手数, 2:先頭(数字or同), 3:段(or全角スペース), 4:駒名, 5:元筋, 6:元段
    final moveRegex = RegExp(r"^\s*(\d+)\s+([１-９同])\s*([一二三四五六七八九　]?)\s*([^\s(]+)(?:\((\d)(\d)\))?");

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // 1. コメント行 (* で始まる)
      if (trimmedLine.startsWith('*')) {
        currentNode.addComment(trimmedLine.substring(1));
        continue;
      }

      // 2. 指し手行 (数字で始まる)
      final moveMatch = moveRegex.firstMatch(trimmedLine);
      if (moveMatch != null) {
        final moveNum = int.parse(moveMatch.group(1)!);
        final firstChar = moveMatch.group(2)!; // 「３」や「同」
        final secondChar = moveMatch.group(3)?.trim() ?? ""; // 「八」や「　」
        final pieceName = moveMatch.group(4)!; // 「歩」や「成銀」
        final fromXStr = moveMatch.group(5);
        final fromYStr = moveMatch.group(6);

        int toX, toY;
        if (firstChar == '同') {
          // 「同」の場合は直前の着手位置を継承
          if (currentNode.state.lastMoveToX == null || currentNode.state.lastMoveToY == null) {
            // 初手で「同」が来ることは通常ないが、エラー回避
            toX = 0; toY = 0;
          } else {
            toX = currentNode.state.lastMoveToX!;
            toY = currentNode.state.lastMoveToY!;
          }
        } else {
          // 「３八」などの通常形式
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

        // ノード作成
        final newNode = GameNode(
          moveNumber: moveNum,
          // ラベルは「３八金(49)」や「同　歩(83)」の全体を保持
          moveLabel: trimmedLine.split(RegExp(r'\s+')).skip(1).join(' '),
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
