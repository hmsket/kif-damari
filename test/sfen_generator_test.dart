import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/integrated_tree_service.dart';
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

  group('SfenGenerator.stateFromKey', () {
    test('平手初期局面のキーを復元し、再生成して元のキーと一致する', () {
      final original = SfenGenerator.generateKey(BoardState.initial());
      final restored = SfenGenerator.stateFromKey(original);
      expect(SfenGenerator.generateKey(restored), original);
      expect(restored.nextPlayer, Player.sente);
    });

    test('指し手を重ねた盤面・持駒・手番をキーから復元できる', () {
      // 先手が歩を取った局面（持駒・手番・盤上の変化）をキーから復元できる
      final state = BoardState.initial()
          .movePiece(fromX: 7, fromY: 7, toX: 7, toY: 6, pieceName: '歩')
          .movePiece(fromX: 3, fromY: 3, toX: 3, toY: 4, pieceName: '歩')
          .movePiece(fromX: 7, fromY: 6, toX: 7, toY: 5, pieceName: '歩')
          .movePiece(fromX: 7, fromY: 3, toX: 7, toY: 4, pieceName: '歩')
          .movePiece(fromX: 7, fromY: 5, toX: 7, toY: 4, pieceName: '歩');
      final key = SfenGenerator.generateKey(state);
      final restored = SfenGenerator.stateFromKey(key);
      expect(SfenGenerator.generateKey(restored), key);
      expect(restored.senteHand['fu'], 1);
      expect(restored.nextPlayer, Player.gote);
      // 取った動きの出発マスが空になっていること
      expect(restored.grid[4][9 - 7], isNull);
    });

    test('後手の持駒（小文字）も復元できる', () {
      // 先手・後手が歩を突き進めた後、後手が先手の歩を取って持駒にする
      final state = BoardState.initial()
          .movePiece(fromX: 7, fromY: 7, toX: 7, toY: 6, pieceName: '歩')
          .movePiece(fromX: 3, fromY: 3, toX: 3, toY: 4, pieceName: '歩')
          .movePiece(fromX: 7, fromY: 6, toX: 7, toY: 5, pieceName: '歩')
          .movePiece(fromX: 7, fromY: 3, toX: 7, toY: 4, pieceName: '歩')
          .movePiece(fromX: 7, fromY: 5, toX: 7, toY: 4, pieceName: '歩');
      final captured = state.movePiece(fromX: 3, fromY: 4, toX: 7, toY: 4, pieceName: '歩');
      final key = SfenGenerator.generateKey(captured);
      final restored = SfenGenerator.stateFromKey(key);
      expect(SfenGenerator.generateKey(restored), key);
      expect(restored.goteHand['fu'], 1);
    });
  });

  group('IntegratedTreeService.describeRootKind', () {
    test('平手初期局面は「平手」になる', () {
      expect(
        IntegratedTreeService.describeRootKind(SfenGenerator.generateKey(BoardState.initial())),
        '平手',
      );
    });

    test('後手から飛を除いた配置は「飛落ち」になる', () {
      final state = SfenGenerator.stateFromKey(SfenGenerator.generateKey(BoardState.initial()));
      // 後手飛（whi、y=2行・x=8）を取り除く
      final grid = state.grid.map((row) => List<String?>.from(row)).toList();
      grid[1][1] = null;
      final key = SfenGenerator.generateKey(BoardState(
        grid: grid,
        senteHand: const {},
        goteHand: const {},
        nextPlayer: Player.sente,
      ));
      expect(IntegratedTreeService.describeRootKind(key), '飛落ち');
    });

    test('先手から角を除いた配置は「角落ち」になる', () {
      final state = SfenGenerator.stateFromKey(SfenGenerator.generateKey(BoardState.initial()));
      final grid = state.grid.map((row) => List<String?>.from(row)).toList();
      grid[7][1] = null; // 先手角（bka、y=8行・x=2）
      final key = SfenGenerator.generateKey(BoardState(
        grid: grid,
        senteHand: const {},
        goteHand: const {},
        nextPlayer: Player.sente,
      ));
      expect(IntegratedTreeService.describeRootKind(key), '角落ち');
    });

    test('中盤風の盤面は「途中開始」になる', () {
      final state = BoardState.initial().movePiece(
        fromX: 7,
        fromY: 7,
        toX: 7,
        toY: 6,
        pieceName: '歩',
      );
      expect(
        IntegratedTreeService.describeRootKind(SfenGenerator.generateKey(state)),
        '途中開始',
      );
    });
  });
}
