import 'package:kifdamari/models/board_state.dart';

class GameNode {
  final int moveNumber;
  final String? moveLabel;
  BoardState state;

  /// 棋譜コメント（.kif の * 行として読み書きする）。
  final List<String> comments;

  /// 局面メモ（アプリ内 DB の positions テーブルにのみ保存する）。
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

  void addKifComment(String line) {
    comments.add(line);
  }

  void addPositionComment(String line) {
    positionComments.add(line);
  }

  /// 棋譜コメント（[comments] の別名）。
  List<String> get kifComments => comments;

  /// 局面メモ（[positionComments] の別名）。
  List<String> get positionMemo => positionComments;

  String get joinedComment => comments.join('\n');

  String get joinedKifComment => comments.join('\n');

  String get joinedPositionComment => positionComments.join('\n');

  String get joinedPositionMemo => positionComments.join('\n');
}
