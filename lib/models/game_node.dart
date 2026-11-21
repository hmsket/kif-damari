import 'package:kifdamari/models/board_state.dart';

class GameNode {
  final int moveNumber;
  final String? moveLabel;
  BoardState state;

  final List<String> comments;

  final List<String> positionComments;

  GameNode? parent;

  List<GameNode> nextNodes = [];

  int selectedBranchIndex = 0;

  String? positionKey;

  GameNode({
    required this.moveNumber,
    this.moveLabel,
    required this.state,
    List<String>? comments,
    List<String>? positionComments,
    this.parent,
  }) : comments = comments ?? [],
       positionComments = positionComments ?? [];

  void addChild(GameNode child) {
    child.parent = this;
    nextNodes.add(child);
  }

  void addComment(String line) {
    comments.add(line);
  }

  void addPositionComment(String line) {
    positionComments.add(line);
  }

  String get joinedComment => comments.join('\n');

  String get joinedPositionComment => positionComments.join('\n');
}
