import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/models/game_node.dart';

class KifTree {
  final GameNode root;
  GameNode currentNode;
  final Map<String, String> info = {};

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

  int get totalMoveCount {
    int count = currentNode.moveNumber;
    GameNode? temp = currentNode;
    while (temp!.nextNodes.isNotEmpty) {
      temp = temp.nextNodes.first;
      count++;
    }
    return count;
  }

  // 1手進める
  void stepNext({GameNode? chosenNode}) {
    if (chosenNode != null) {
      currentNode = chosenNode;

      if (chosenNode.parent != null) {
        chosenNode.parent!.selectedBranchIndex =
            chosenNode.parent!.nextNodes.indexOf(chosenNode);
      }

      return;
    }

    if (currentNode.nextNodes.isNotEmpty) {
      currentNode = currentNode.nextNodes[
          currentNode.selectedBranchIndex];
    }
  }

  // 1手戻す
  void stepBack() {
    if (currentNode.parent != null) {
      currentNode = currentNode.parent!;
    }
  }

  // 指定した手数にジャンプ
  void jumpTo(int targetMoveNumber) {
    if (targetMoveNumber < 0) {
      currentNode = root;
      return;
    }

    while (currentNode.moveNumber > targetMoveNumber && currentNode.parent != null) {
      currentNode = currentNode.parent!;
    }

    while (currentNode.moveNumber < targetMoveNumber && currentNode.nextNodes.isNotEmpty) {
      currentNode = currentNode.nextNodes.first;
    }
  }
}
