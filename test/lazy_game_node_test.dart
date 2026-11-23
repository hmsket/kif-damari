import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/sfen_generator.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/models/game_node.dart';

void main() {
  test('局面キーだけを持つノードは初回参照時に盤面を復元する', () {
    final key = SfenGenerator.generateKey(BoardState.initial());
    final node = GameNode.fromPositionKey(
      moveNumber: 0,
      moveLabel: '開始局面',
      key: key,
    );

    final state = node.state;
    expect(SfenGenerator.generateKey(state), key);
    expect(state.nextPlayer, Player.sente);
    expect(node.state, same(state));
  });

  test('不正な局面キーでもノード生成時には解析されない', () {
    final node = GameNode.fromPositionKey(
      moveNumber: 1,
      moveLabel: '+7776FU',
      key: 'invalid-key',
    );

    expect(() => node.state, throwsA(isA<ArgumentError>()));
  });
}
