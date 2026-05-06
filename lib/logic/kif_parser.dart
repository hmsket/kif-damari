import '../models/game_node.dart';
import '../models/kif_tree.dart';

class KifParser {
  static const _zenToNum = {'１':1,'２':2,'３':3,'４':4,'５':5,'６':6,'７':7,'８':8,'９':9};
  static const _kanToNum = {'一':1,'二':2,'三':3,'四':4,'五':5,'六':6,'七':7,'八':8,'九':9};

  static KifTree decode(String text) {
    // 改行コード(\r\n, \n)の両方に対応
    final lines = text.split(RegExp(r'\r?\n'));
    final tree = KifTree.initial();
    
    // 現在どのノードに対して操作（コメント追加や次の手の追加）を行っているか
    GameNode currentNode = tree.root;

    final moveRegex = RegExp(r"^\s*(\d+)\s+([１-９同])([一二三四五六七八九]?)?\s*([^(\s]+)(?:\((\d)(\d)\))?");

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // --- コメント行の処理 ---
      if (trimmedLine.startsWith('*')) {
        // 先頭の'*'を除去して、現在のノード（rootまたは直前の指し手）に追加
        currentNode.comments.add(trimmedLine.substring(1));
        continue;
      }

      // --- 指し手行の処理 ---
      final match = moveRegex.firstMatch(trimmedLine);
      if (match != null) {
        final moveNum = int.parse(match.group(1)!);
        final toXStr = match.group(2)!;
        final toYStr = match.group(3);
        final pieceName = match.group(4)!;
        final fromXStr = match.group(5);
        final fromYStr = match.group(6);

        // 座標の特定
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

        // 新しい局面の生成
        final nextState = currentNode.state.movePiece(
          fromX: fromX, fromY: fromY,
          toX: toX, toY: toY,
          pieceName: pieceName,
        );

        // 新しいノードの生成
        final newNode = GameNode(
          moveNumber: moveNum,
          // moveLabel取得を正規表現に合わせてもう少し安全に
          moveLabel: trimmedLine.split(RegExp(r'\s+')).skip(1).first,
          state: nextState,
        );

        // 木構造に追加
        currentNode.addChild(newNode);
        
        // カレントノードを更新（これ以降のコメントはこの手に紐付く）
        currentNode = newNode;
      }
    }
    return tree;
  }
}
