import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/handicap_presets.dart';
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/logic/sfen_generator.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/models/game_node.dart';
import 'package:kifdamari/models/kif_tree.dart';

const _shichimaiochiDiagram = '''
  ９ ８ ７ ６ ５ ４ ３ ２ １
+---------------------------+
| ・v桂v銀v金v玉v金v銀v桂 ・|一
| ・ ・ ・ ・ ・ ・ ・ ・ ・|二
|v歩v歩v歩v歩v歩v歩v歩v歩v歩|三
| ・ ・ ・ ・ ・ ・ ・ ・ ・|四
| ・ ・ ・ ・ ・ ・ ・ ・ ・|五
| ・ ・ ・ ・ ・ ・ ・ ・ ・|六
| 歩 歩 歩 歩 歩 歩 歩 歩 歩|七
| ・ 角 ・ ・ ・ ・ ・ 飛 ・|八
| 香 桂 銀 金 玉 金 銀 桂 香|九
+---------------------------+
先手の持駒：なし
後手の持駒：なし
先手番
''';

void main() {
  group('encode の盤面図書き出し', () {
    test('四枚落ちの root では開始局面の盤面図が出力される', () {
      final tree = KifTree.initial();
      tree.applyHandicap('四枚落ち');

      final encoded = KifParser.encode(tree);

      expect(encoded, contains(_shichimaiochiDiagram.trim()));
      // 盤面図は情報ヘッダーの後・区切り行の前にあること
      final headerIndex = encoded.indexOf('手合割：四枚落ち');
      final diagramIndex = encoded.indexOf('  ９ ８ ７ ６ ５ ４ ３ ２ １');
      final separatorIndex = encoded.indexOf('手数----指手---------消費時間--');
      expect(headerIndex, greaterThan(-1));
      expect(diagramIndex, greaterThan(headerIndex));
      expect(separatorIndex, greaterThan(diagramIndex));
    });

    test('平手の root では盤面図を出力しない', () {
      final tree = KifTree.initial();

      final encoded = KifParser.encode(tree);

      expect(encoded, isNot(contains('先手の持駒：')));
      expect(encoded, isNot(contains('先手番')));
      expect(encoded, isNot(contains('+---------------------------+')));
    });

    test('盤面図は root の持駒・手番を反映する', () {
      const source = '''
棋戦：テスト
  ９ ８ ７ ６ ５ ４ ３ ２ １
+---------------------------+
| ・v桂v銀v金v玉v金v銀v桂v香|一
| ・ ・ ・ ・ ・ ・ ・ ・ ・|二
|v歩v歩v歩v歩v歩v歩v歩v歩v歩|三
| ・ ・ ・ ・ ・ ・ ・ ・ ・|四
| ・ ・ ・ ・ ・ ・ ・ ・ ・|五
| ・ ・ ・ ・ ・ ・ ・ ・ ・|六
| 歩 歩 歩 歩 歩 歩 歩 歩 歩|七
| と 馬 ・ ・ ・ ・ ・ 飛 ・|八
| 香 桂 銀 金 玉 金 銀 桂 香|九
+---------------------------+
先手の持駒：歩二　金
後手の持駒：なし
後手番
手数----指手---------消費時間--
   1 ８四歩(83)
''';
      final tree = KifParser.decode(source);

      final encoded = KifParser.encode(tree);

      expect(encoded, contains('先手の持駒：金　歩二'));
      expect(encoded, contains('後手の持駒：なし'));
      expect(encoded, contains('後手番'));
      expect(encoded, contains('| と 馬 ・ ・ ・ ・ ・ 飛 ・|八'));
    });
  });

  group('encode の区切り行', () {
    test('区切り行は長形式で出力される', () {
      final tree = KifTree.initial();
      final encoded = KifParser.encode(tree);

      expect(encoded, contains('手数----指手---------消費時間--'));
      expect(encoded, isNot(contains('手数----指手----消費時間--')));
    });
  });

  group('decode の盤面図読み込み', () {
    test('盤面図つきKIFから正しい開始局面が復元できる', () {
      const source = '''
棋戦：テスト
$_shichimaiochiDiagram手数----指手---------消費時間--
   1 ７六歩(77)
''';
      final tree = KifParser.decode(source);

      expect(
        SfenGenerator.generateKey(tree.root.state),
        SfenGenerator.generateKey(HandicapPresets.stateFor('四枚落ち')!),
      );
      expect(tree.root.nextNodes.first.moveLabel, '７六歩(77)');
    });

    test('持駒・成駒・後手番を含む盤面図から復元できる', () {
      const source = '''
棋戦：テスト
  ９ ８ ７ ６ ５ ４ ３ ２ １
+---------------------------+
| ・v桂v銀v金v玉v金v銀v桂v香|一
| ・ ・ ・ ・ ・ ・ ・ ・ ・|二
|v歩v歩v歩v歩v歩v歩v歩v歩v歩|三
| ・ ・ ・ ・ ・ ・ ・ ・ ・|四
| ・ ・ ・ ・ ・ ・ ・ ・ ・|五
| ・ ・ ・ ・ ・ ・ ・ ・ ・|六
| 歩 歩 歩 歩 歩 歩 歩 歩 歩|七
| と 馬 ・ ・ ・ ・ ・ 飛 ・|八
| 香 桂 銀 金 玉 金 銀 桂 香|九
+---------------------------+
先手の持駒：歩二　金
後手の持駒：なし
後手番
手数----指手---------消費時間--
   1 ８四歩(83)
''';
      final tree = KifParser.decode(source);

      final state = tree.root.state;
      expect(state.grid[7][0], 'bto'); // ９八と
      expect(state.grid[7][1], 'bum'); // ８八馬
      expect(state.senteHand, {'fu': 2, 'ki': 1});
      expect(state.goteHand, isEmpty);
      expect(state.nextPlayer, Player.gote);
      expect(
        SfenGenerator.generateKey(state),
        '1nsgkgsnl/9/ppppppppp/9/9/9/PPPPPPPPP/+P+B5R1/LNSGKGSNL w G2P',
      );
    });

    test('盤面図の行は info ヘッダーとして取り込まない', () {
      const source = '''
棋戦：テスト
$_shichimaiochiDiagram手数----指手---------消費時間--
   1 ７六歩(77)
''';
      final tree = KifParser.decode(source);

      expect(tree.info.containsKey('先手の持駒'), isFalse);
      expect(tree.info.containsKey('後手の持駒'), isFalse);
      expect(tree.info.containsKey('先手番'), isFalse);
      expect(tree.info['棋戦'], 'テスト');
    });

    test('盤面図と手合割の両方がある場合は盤面図が優先される', () {
      const source = '''
手合割：二枚落ち
棋戦：テスト
$_shichimaiochiDiagram手数----指手---------消費時間--
   1 ７六歩(77)
''';
      final tree = KifParser.decode(source);

      expect(
        SfenGenerator.generateKey(tree.root.state),
        SfenGenerator.generateKey(HandicapPresets.stateFor('四枚落ち')!),
      );
      expect(tree.info['手合割'], '二枚落ち');
    });

    test('盤面図の解析に失敗した場合は平手にフォールバックする', () {
      const source = '''
棋戦：テスト
  ９ ８ ７ ６ ５ ４ ３ ２ １
+---------------------------+
| ・v桂v銀v金v玉v金v銀v桂 ・|一
（壊れた盤面図）
手数----指手---------消費時間--
   1 ７六歩(77)
''';
      final tree = KifParser.decode(source);

      expect(
        SfenGenerator.generateKey(tree.root.state),
        SfenGenerator.generateKey(BoardState.initial()),
      );
      expect(tree.root.nextNodes.first.moveLabel, '７六歩(77)');
    });
  });

  group('decode → encode → decode の往復（盤面図）', () {
    test('四枚落ちのKIFは開始局面と指し手を保って往復できる', () {
      const source = '''
手合割：四枚落ち
棋戦：テスト
手数----指手---------消費時間--
   1 ７六歩(77)
   2 ３四歩(33)
''';
      final original = KifParser.decode(source);
      final redecoded = KifParser.decode(KifParser.encode(original));

      expect(
        SfenGenerator.generateKey(redecoded.root.state),
        SfenGenerator.generateKey(HandicapPresets.stateFor('四枚落ち')!),
      );
      expect(redecoded.root.nextNodes.first.moveLabel, '７六歩(77)');
      expect(
        redecoded.root.nextNodes.first.nextNodes.first.moveLabel,
        '３四歩(33)',
      );
    });

    test('指し手で駒を取った後の局面も往復で一致する', () {
      final tree = KifTree.initial();
      tree.applyHandicap('香落ち');
      var state = tree.root.state;
      final moves = [
        {'fromX': 7, 'fromY': 7, 'toX': 7, 'toY': 6, 'name': '歩', 'label': '７六歩(77)'},
        {'fromX': 3, 'fromY': 3, 'toX': 3, 'toY': 4, 'name': '歩', 'label': '３四歩(33)'},
        {'fromX': 8, 'fromY': 8, 'toX': 3, 'toY': 4, 'name': '香', 'label': '３四香(88)'},
      ];
      for (final entry in moves) {
        state = state.movePiece(
          fromX: entry['fromX'] as int?,
          fromY: entry['fromY'] as int?,
          toX: entry['toX'] as int,
          toY: entry['toY'] as int,
          pieceName: entry['name'] as String,
        );
        tree.root.addChild(GameNode(
          moveNumber: tree.root.nextNodes.length + 1,
          moveLabel: entry['label'] as String,
          state: state,
          parent: tree.root,
        ));
      }

      final redecoded = KifParser.decode(KifParser.encode(tree));

      expect(
        SfenGenerator.generateKey(redecoded.root.state),
        SfenGenerator.generateKey(HandicapPresets.stateFor('香落ち')!),
      );
      // 3手目の先手持駒（歩）が盤面図経由で保たれる
      var a = tree.root;
      var b = redecoded.root;
      while (a.nextNodes.isNotEmpty) {
        a = a.nextNodes.first;
        b = b.nextNodes.first;
        expect(SfenGenerator.generateKey(b.state), SfenGenerator.generateKey(a.state));
      }
    });
  });
}
