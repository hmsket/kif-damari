import 'package:kifdamari/models/board_state.dart';

class GameNode {
  final int moveNumber;      // 何手目か
  final String? moveLabel;   // 「７六歩」などの表記
  final BoardState state;    // この手番終了後の局面
  final String comment;      // 棋譜コメント

  // 拡張性のポイント
  GameNode? parent;               // 前の手（1手戻る用）
  List<GameNode> nextNodes = [];  // 次の手のリスト（分岐対応用）

  GameNode({
    required this.moveNumber,
    this.moveLabel,
    required this.state,
    this.comment = "",
    this.parent,
  });

  // 次の手を追加する（分岐対応の布石）
  void addChild(GameNode child) {
    child.parent = this;
    nextNodes.add(child);
  }
}
