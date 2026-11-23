import 'package:kifdamari/logic/sfen_generator.dart';
import 'package:kifdamari/models/board_state.dart';

class GameNode {
  final int moveNumber;
  final String? moveLabel;
  BoardState? _state;

  /// 盤面データ。局面キーから復元するノードでは、初めて参照された時にだけ SFEN を解析する。
  BoardState get state {
    final cached = _state;
    if (cached != null) return cached;
    final key = positionKey;
    if (key == null) throw StateError('局面キーが未設定のため盤面を復元できません');
    final restored = SfenGenerator.stateFromKey(key);
    _state = restored;
    return restored;
  }

  set state(BoardState value) => _state = value;

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
    required BoardState state,
    List<String>? comments,
    List<String>? positionComments,
    this.parent,
  })  : _state = state,
        comments = comments ?? [],
        positionComments = positionComments ?? [];

  /// 局面キーだけを持つノードを作る（盤面データは [state] の初回参照時に解析する）。
  GameNode.fromPositionKey({
    required this.moveNumber,
    this.moveLabel,
    required String key,
    List<String>? comments,
    List<String>? positionComments,
    this.parent,
  })  : _state = null,
        comments = comments ?? [],
        positionComments = positionComments ?? [],
        positionKey = key;

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
