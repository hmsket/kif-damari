import 'board_state.dart';
import 'game_node.dart';

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

  // --- シークバー用の計算プロパティ ---
  
  /// 本譜（メインの指し手）の合計手数を取得します。
  /// スライダーの max 値に使用します。
  int get totalMoveCount {
    int count = currentNode.moveNumber;
    GameNode? temp = currentNode;
    
    // 現在地から、今選ばれている文脈（first）に沿って最後まで下りきってカウントを足す
    while (temp!.nextNodes.isNotEmpty) {
      temp = temp.nextNodes.first;
      count++;
    }
    return count;
  }

  // --- 操作用メソッド ---

  // 1手進める（基本は最初の選択肢。分岐選択時は特定のノードを指定可能にする）
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

  /// 1手指し戻す（親ノードへ移動）
  void stepBack() {
    if (currentNode.parent != null) {
      currentNode = currentNode.parent!;
    }
  }

  /// 指定した手数にジャンプします。
  /// シークバーの onChanged などから呼び出します。
  void jumpTo(int targetMoveNumber) {
    if (targetMoveNumber < 0) {
      currentNode = root;
      return;
    }

    // 目標の手数が、現在地より「過去」なら、歴史を遡る
    while (currentNode.moveNumber > targetMoveNumber && currentNode.parent != null) {
      currentNode = currentNode.parent!;
    }

    // 目標の手数が、現在地より「未来」なら、今選ばれている文脈に沿って下る
    while (currentNode.moveNumber < targetMoveNumber && currentNode.nextNodes.isNotEmpty) {
      currentNode = currentNode.nextNodes.first;
    }
  }
}
