import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/sfen_generator.dart';
import 'package:kifdamari/models/board_state.dart';

void main() {
  group('SfenGenerator.generateKey', () {
    test('平手初期局面のキーを生成できる', () {
      final key = SfenGenerator.generateKey(BoardState.initial());
      expect(
        key,
        'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b -',
      );
    });

    test('同じ指し手からは同じキーになり、違う局面は違うキーになる', () {
      final state = BoardState.initial();
      final moved1 = state.movePiece(fromX: 7, fromY: 7, toX: 7, toY: 6, pieceName: '歩');
      final moved2 = state.movePiece(fromX: 7, fromY: 7, toX: 7, toY: 6, pieceName: '歩');
      expect(SfenGenerator.generateKey(moved1), SfenGenerator.generateKey(moved2));
      expect(SfenGenerator.generateKey(moved1), isNot(SfenGenerator.generateKey(state)));
    });

    test('手順前後で到達した同一局面は同じキーになる', () {
      final a = BoardState.initial()
          .movePiece(fromX: 7, fromY: 7, toX: 7, toY: 6, pieceName: '歩')
          .movePiece(fromX: 3, fromY: 3, toX: 3, toY: 4, pieceName: '歩')
          .movePiece(fromX: 7, fromY: 9, toX: 6, toY: 8, pieceName: '銀');
      final b = BoardState.initial()
          .movePiece(fromX: 7, fromY: 9, toX: 6, toY: 8, pieceName: '銀')
          .movePiece(fromX: 3, fromY: 3, toX: 3, toY: 4, pieceName: '歩')
          .movePiece(fromX: 7, fromY: 7, toX: 7, toY: 6, pieceName: '歩');
      expect(SfenGenerator.generateKey(a), SfenGenerator.generateKey(b));
    });

    test('持駒と手番はキーに含まれる', () {
      final state = BoardState.initial()
          .movePiece(fromX: 7, fromY: 7, toX: 7, toY: 6, pieceName: '歩')
          .movePiece(fromX: 3, fromY: 3, toX: 3, toY: 4, pieceName: '歩')
          .movePiece(fromX: 7, fromY: 6, toX: 7, toY: 5, pieceName: '歩')
          .movePiece(fromX: 7, fromY: 3, toX: 7, toY: 4, pieceName: '歩');
      final captured = state.movePiece(fromX: 7, fromY: 5, toX: 7, toY: 4, pieceName: '歩');
      final key = SfenGenerator.generateKey(captured);
      expect(key.endsWith(' w P'), isTrue);
    });
  });

  group('SfenGenerator.moveCode', () {
    test('盤上の移動は座標＋駒種に正規化される', () {
      final from = BoardState.initial();
      final to = from.movePiece(fromX: 7, fromY: 7, toX: 7, toY: 6, pieceName: '歩');
      expect(
        SfenGenerator.moveCode(fromState: from, toState: to, fallbackLabel: 'x'),
        '7776fu',
      );
    });

    test('成りの指し手は+付きに正規化される', () {
      final from = BoardState.initial()
          .movePiece(fromX: 2, fromY: 7, toX: 2, toY: 6, pieceName: '歩')
          .movePiece(fromX: 3, fromY: 3, toX: 3, toY: 4, pieceName: '歩')
          .movePiece(fromX: 2, fromY: 6, toX: 2, toY: 5, pieceName: '歩')
          .movePiece(fromX: 5, fromY: 3, toX: 5, toY: 4, pieceName: '歩')
          .movePiece(fromX: 2, fromY: 5, toX: 2, toY: 4, pieceName: '歩')
          .movePiece(fromX: 3, fromY: 4, toX: 3, toY: 5, pieceName: '歩');
      final to = from.movePiece(fromX: 2, fromY: 4, toX: 2, toY: 3, pieceName: 'と');
      expect(
        SfenGenerator.moveCode(fromState: from, toState: to, fallbackLabel: 'x'),
        '2423fu+',
      );
    });

    test('駒打ちは+始まりに正規化される', () {
      final from = BoardState.initial()
          .movePiece(fromX: 5, fromY: 7, toX: 5, toY: 6, pieceName: '歩')
          .movePiece(fromX: 3, fromY: 3, toX: 3, toY: 4, pieceName: '歩')
          .movePiece(fromX: 5, fromY: 6, toX: 5, toY: 5, pieceName: '歩')
          .movePiece(fromX: 5, fromY: 3, toX: 5, toY: 5, pieceName: '歩')
          .movePiece(fromX: 6, fromY: 7, toX: 6, toY: 6, pieceName: '歩');
      final to = from.movePiece(fromX: null, fromY: null, toX: 5, toY: 6, pieceName: '歩');
      expect(
        SfenGenerator.moveCode(fromState: from, toState: to, fallbackLabel: 'x'),
        '+56fu',
      );
    });

    test('盤面の変化から求められない場合はフォールバックラベルを返す', () {
      final state = BoardState(
        grid: List.generate(9, (_) => List<String?>.filled(9, null)),
        senteHand: {},
        goteHand: {},
        nextPlayer: Player.sente,
        lastMoveToX: 5,
        lastMoveToY: 5,
      );
      expect(
        SfenGenerator.moveCode(fromState: state, toState: state, fallbackLabel: 'fallback'),
        'fallback',
      );
    });
  });
}
