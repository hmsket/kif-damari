import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/handicap_presets.dart';
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/logic/sfen_generator.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/models/game_node.dart';
import 'package:kifdamari/models/kif_tree.dart';

void main() {
  group('KifTree.applyHandicap', () {
    test('指し手が無い状態で二枚落ちを選ぶと、root 局面が二枚落ちの開始局面になり info の手合割が二枚落ちになる', () {
      final tree = KifTree.initial();
      expect(tree.canChangeHandicap, isTrue);

      expect(tree.applyHandicap('二枚落ち'), isTrue);
      expect(
        SfenGenerator.generateKey(tree.root.state),
        SfenGenerator.generateKey(HandicapPresets.stateFor('二枚落ち')!),
      );
      expect(tree.info['手合割'], '二枚落ち');
      expect(tree.currentNode, same(tree.root));
    });

    test('info に手合割キーが無い棋譜でも適用でき、root のコメントは保持される', () {
      final tree = KifTree.initial();
      tree.root.comments.add('開始局面のコメント');

      expect(tree.applyHandicap('香落ち'), isTrue);
      expect(tree.root.joinedComment, '開始局面のコメント');
      expect(
        SfenGenerator.generateKey(tree.root.state),
        SfenGenerator.generateKey(HandicapPresets.stateFor('香落ち')!),
      );
      expect(tree.info['手合割'], '香落ち');
    });

    test('平手を選んだ場合も「平手」と記録される', () {
      final tree = KifTree.initial();
      expect(tree.applyHandicap('平手'), isTrue);
      expect(tree.info['手合割'], '平手');
      expect(
        SfenGenerator.generateKey(tree.root.state),
        SfenGenerator.generateKey(BoardState.initial()),
      );
    });

    test('指し手がある状態では手合割を変更できない', () {
      final tree = KifTree.initial();
      final firstState = tree.root.state.movePiece(
        fromX: 7, fromY: 7, toX: 7, toY: 6, pieceName: '歩',
      );
      tree.root.addChild(GameNode(
        moveNumber: 1,
        state: firstState,
        moveLabel: '７六歩(77)',
        parent: tree.root,
      ));

      expect(tree.canChangeHandicap, isFalse);
      expect(tree.applyHandicap('二枚落ち'), isFalse);
      expect(
        SfenGenerator.generateKey(tree.root.state),
        SfenGenerator.generateKey(BoardState.initial()),
      );
      expect(tree.info.containsKey('手合割'), isFalse);
    });

    test('プリセットに無い名前は適用できない', () {
      final tree = KifTree.initial();
      expect(tree.applyHandicap('歩三兵'), isFalse);
      expect(tree.info.containsKey('手合割'), isFalse);
    });
  });

  group('手合割変更後の encode → decode 往復', () {
    test('変更後に保存したファイルを読み直すと、同じ開始局面・手合割になる', () {
      final tree = KifTree.initial();
      expect(tree.applyHandicap('二枚落ち'), isTrue);
      final firstState = tree.root.state.movePiece(
        fromX: 7, fromY: 7, toX: 7, toY: 6, pieceName: '歩',
      );
      tree.root.addChild(GameNode(
        moveNumber: 1,
        state: firstState,
        moveLabel: '７六歩(77)',
        parent: tree.root,
      ));

      final encoded = KifParser.encode(tree);
      expect(encoded, contains('手合割：二枚落ち'));

      final redecoded = KifParser.decode(encoded);
      expect(
        SfenGenerator.generateKey(redecoded.root.state),
        SfenGenerator.generateKey(HandicapPresets.stateFor('二枚落ち')!),
      );
      expect(redecoded.info['手合割'], '二枚落ち');
      expect(redecoded.root.nextNodes.first.moveLabel, '７六歩(77)');
    });
  });
}
