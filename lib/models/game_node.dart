import 'package:kifdamari/models/board_state.dart';

class GameNode {
  final int moveNumber;
  final String? moveLabel;
  final BoardState state;
  
  // final ですが、リストの中身自体は編集可能です
  final List<String> comments;

  GameNode? parent;
  List<GameNode> nextNodes = [];

  GameNode({
    required this.moveNumber,
    this.moveLabel,
    required this.state,
    List<String>? comments, 
    this.parent,
  }) : this.comments = comments ?? []; // ここで新しい可変リストを代入

  void addChild(GameNode child) {
    child.parent = this;
    nextNodes.add(child);
  }

  // Parserから後で1行ずつ追加するために必要
  void addComment(String line) {
    comments.add(line);
  }

  String get joinedComment => comments.join('\n');
}
