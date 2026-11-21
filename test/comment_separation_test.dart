import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/models/game_node.dart';

const _source = '''
棋戦：テスト
手数----指手---------消費時間--
*開始局面の棋譜コメント
   1 ７六歩(77)
*１手目の棋譜コメント
   2 ３四歩(33)
''';

void main() {
  group('棋譜コメントと局面メモの分離', () {
    test('GameNode は棋譜コメントと局面メモを別々に保持する', () {
      final node = GameNode(
        moveNumber: 1,
        state: BoardState.initial(),
      );

      node.addComment('棋譜コメント');
      node.addPositionComment('局面メモ');

      expect(node.comments, ['棋譜コメント']);
      expect(node.positionComments, ['局面メモ']);
      expect(node.joinedComment, '棋譜コメント');
      expect(node.joinedPositionComment, '局面メモ');
    });

    test('decode は .kif のコメントを棋譜コメントとして読み、局面メモには入れない', () {
      final tree = KifParser.decode(_source);

      expect(tree.root.comments, ['開始局面の棋譜コメント']);
      expect(tree.root.positionComments, isEmpty);

      final first = tree.root.nextNodes.first;
      expect(first.comments, ['１手目の棋譜コメント']);
      expect(first.positionComments, isEmpty);
    });

    test('encode は棋譜コメントだけを書き、局面メモを含めない', () {
      final tree = KifParser.decode(_source);
      tree.root.positionComments.add('開始局面の局面メモ');
      tree.root.nextNodes.first.positionComments.add('１手目の局面メモ');

      final encoded = KifParser.encode(tree);

      expect(encoded, contains('*開始局面の棋譜コメント'));
      expect(encoded, contains('*１手目の棋譜コメント'));
      expect(encoded, isNot(contains('局面メモ')));
    });

    test('decode → encode で棋譜コメントが保たれる', () {
      final original = KifParser.decode(_source);
      final redecoded = KifParser.decode(KifParser.encode(original));

      expect(redecoded.root.comments, ['開始局面の棋譜コメント']);
      expect(
        redecoded.root.nextNodes.first.comments,
        ['１手目の棋譜コメント'],
      );
      expect(redecoded.root.positionComments, isEmpty);
      expect(redecoded.root.nextNodes.first.positionComments, isEmpty);
    });
  });
}
