import '../models/game_node.dart';
import '../models/kif_tree.dart';

class KifParser {
  static const _zenToNum = {'１':1,'２':2,'３':3,'４':4,'５':5,'６':6,'７':7,'８':8,'９':9};
  static const _kanToNum = {'一':1,'二':2,'三':3,'四':4,'五':5,'六':6,'七':7,'八':8,'九':9};

  /// KIF形式のテキストを解析してKifTreeを返す
  static KifTree decode(String text) {
    final lines = text.split('\n');
    final tree = KifTree.initial();
    GameNode currentNode = tree.root;

    // 指し手行を抽出する正規表現
    // グループ1:手数, 2:移動先筋, 3:移動先段, 4:駒名, 5:元筋, 6:元段
    // lib/logic/kif_parser.dart

    // 修正前: ([^\s(]+) 
    // 修正後: ([^(\s]+)  <-- カッコやスペースが来るまで「すべて」を駒名として拾う
    final moveRegex = RegExp(r"^\s*(\d+)\s+([１-９同])([一二三四五六七八九]?)?\s*([^(\s]+)(?:\((\d)(\d)\))?");

    for (var line in lines) {
      final match = moveRegex.firstMatch(line);
      if (match != null) {
        final moveNum = int.parse(match.group(1)!);
        final toXStr = match.group(2)!;
        final toYStr = match.group(3);
        final pieceName = match.group(4)!;
        final fromXStr = match.group(5);
        final fromYStr = match.group(6);

        // --- 座標の特定 ---
        int toX, toY;
        if (toXStr == '同') {
          // 「同」の場合は直前の着手と同じ場所
          toX = currentNode.state.lastMoveToX!;
          toY = currentNode.state.lastMoveToY!;
        } else {
          toX = _zenToNum[toXStr]!;
          toY = _kanToNum[toYStr]!;
        }

        // --- 移動元（打つ場合はnull） ---
        int? fromX = fromXStr != null ? int.parse(fromXStr) : null;
        int? fromY = fromYStr != null ? int.parse(fromYStr) : null;

        // --- 新しい局面の生成 ---
        // ここで BoardState に「駒を動かす」ロジックを呼ぶ
        final nextState = currentNode.state.movePiece(
          fromX: fromX, fromY: fromY,
          toX: toX, toY: toY,
          pieceName: pieceName,
        );

        final newNode = GameNode(
          moveNumber: moveNum,
          moveLabel: line.trim().split(' ').where((s) => s.isNotEmpty).skip(1).first, // 「３八金(49)」の部分
          state: nextState,
        );

        currentNode.addChild(newNode);
        currentNode = newNode;
      }
    }
    return tree;
  }
}
