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
    int count = 0;
    GameNode? temp = root;
    // 最初の分岐（本譜）を最後まで辿ってカウント
    while (temp!.nextNodes.isNotEmpty) {
      temp = temp.nextNodes.first;
      count++;
    }
    return count;
  }

  // --- 操作用メソッド ---

  /// 1手進める（本譜の次ノードへ移動）
  void stepNext() {
    if (currentNode.nextNodes.isNotEmpty) {
      currentNode = currentNode.nextNodes.first;
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
    // 範囲外のガード
    if (targetMoveNumber < 0) {
      currentNode = root;
      return;
    }

    // 一旦ルートから探索を開始
    GameNode temp = root;
    
    // 目標の手数まで本譜を辿る
    for (int i = 0; i < targetMoveNumber; i++) {
      if (temp.nextNodes.isNotEmpty) {
        temp = temp.nextNodes.first;
      } else {
        // 目標手数が棋譜の最後を超えている場合はそこで止まる
        break;
      }
    }
    
    currentNode = temp;
  }
}
