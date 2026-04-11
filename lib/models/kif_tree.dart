import 'board_state.dart';
import 'game_node.dart'; // game_node.dartも先に作っておく必要があります

class KifTree {
  final GameNode root;
  GameNode currentNode;

  KifTree(this.root) : currentNode = root;

  // 0手目の初期状態でツリーを作成する
  factory KifTree.initial() {
    final initialNode = GameNode(
      moveNumber: 0,
      state: BoardState.initial(),
      moveLabel: "開始局面",
    );
    return KifTree(initialNode);
  }

  // UIから呼ぶためのメソッド
  void stepNext() {
    if (currentNode.nextNodes.isNotEmpty) {
      currentNode = currentNode.nextNodes.first;
    }
  }

  void stepBack() {
    if (currentNode.parent != null) {
      currentNode = currentNode.parent!;
    }
  }
}
