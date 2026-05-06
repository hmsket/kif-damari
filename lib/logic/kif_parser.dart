import '../models/game_node.dart';
import '../models/kif_tree.dart';

class KifParser {
  static const _zenToNum = {'１':1,'２':2,'３':3,'４':4,'５':5,'６':6,'７':7,'８':8,'９':9};
  static const _kanToNum = {'一':1,'二':2,'三':3,'四':4,'五':5,'六':6,'七':7,'八':8,'九':9};

  static KifTree decode(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final tree = KifTree.initial();
    GameNode currentNode = tree.root;

    final moveRegex = RegExp(r"^\s*(\d+)\s+([１-９同])([一二三四五六七八九]?)?\s*([^(\s]+)(?:\((\d)(\d)\))?");
    
    // ヘッダー解析用: 行頭から始まり、：または: で区切られているもの
    final infoRegex = RegExp(r"^([^：:]+)[：:](.*)$");

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // 1. コメント行の処理
      if (trimmedLine.startsWith('*')) {
        currentNode.comments.add(trimmedLine.substring(1));
        continue;
      }

      // 2. 指し手行の処理
      final moveMatch = moveRegex.firstMatch(trimmedLine);
      if (moveMatch != null) {
        // ... (指し手処理: 既存のロジック) ...
        final moveNum = int.parse(moveMatch.group(1)!);
        final toXStr = moveMatch.group(2)!;
        final toYStr = moveMatch.group(3);
        final pieceName = moveMatch.group(4)!;
        final fromXStr = moveMatch.group(5);
        final fromYStr = moveMatch.group(6);

        int toX, toY;
        if (toXStr == '同') {
          toX = currentNode.state.lastMoveToX!;
          toY = currentNode.state.lastMoveToY!;
        } else {
          toX = _zenToNum[toXStr]!;
          toY = _kanToNum[toYStr]!;
        }

        int? fromX = fromXStr != null ? int.parse(fromXStr) : null;
        int? fromY = fromYStr != null ? int.parse(fromYStr) : null;

        final nextState = currentNode.state.movePiece(
          fromX: fromX, fromY: fromY,
          toX: toX, toY: toY,
          pieceName: pieceName,
        );

        final newNode = GameNode(
          moveNumber: moveNum,
          moveLabel: trimmedLine.split(RegExp(r'\s+')).skip(1).first,
          state: nextState,
        );

        currentNode.addChild(newNode);
        currentNode = newNode;
        continue; // 指し手として処理したら次の行へ
      }

      // 3. キーワード（ヘッダー）情報の処理
      final infoMatch = infoRegex.firstMatch(trimmedLine);
      if (infoMatch != null) {
        final key = infoMatch.group(1)!.trim();
        final value = infoMatch.group(2)!.trim();

        // 「手数----」のような区切り行は除外
        if (!key.startsWith('手数')) {
          tree.info[key] = value;
        }
      }
    }
    return tree;
  }
}
