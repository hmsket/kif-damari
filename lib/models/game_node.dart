import 'package:kifdamari/models/board_state.dart';

class GameNode {
  final int moveNumber;
  final String? moveLabel;
  final BoardState state;

  final List<String> comments;

  GameNode? parent;

  List<GameNode> nextNodes = [];

  int selectedBranchIndex = 0;

  GameNode({
    required this.moveNumber,
    this.moveLabel,
    required this.state,
    List<String>? comments,
    this.parent,
  }) : comments = comments ?? [];

  void addChild(GameNode child) {
    child.parent = this;
    nextNodes.add(child);
  }

  void addComment(String line) {
    comments.add(line);
  }

  String get joinedComment => comments.join('\n');
}
