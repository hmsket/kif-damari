import 'package:kifdamari/logic/handicap_presets.dart';
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

  // 指し手が1つも入っていない（root に nextNodes が無い）時だけ手合割を変更できる
  bool get canChangeHandicap => root.nextNodes.isEmpty;

  // 手合割プリセットの開始局面で root の局面を差し替える（root のコメントは保持する）。
  // info の「手合割」に選んだ名前を記録し、現在局面を root に戻す。
  // 指し手が入っている場合・プリセットに無い名前の場合は何もせず false を返す。
  bool applyHandicap(String label) {
    if (!canChangeHandicap) return false;

    final state = HandicapPresets.stateFor(label);
    if (state == null) return false;

    root.state = state;
    info['手合割'] = label;
    currentNode = root;
    return true;
  }
}
