import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/handicap_presets.dart';
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/logic/sfen_generator.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/models/game_node.dart';

void main() {
  group('HandicapPresets', () {
    test('すべてのプリセットは手番が先手・持駒なしで、SFENと一致する局面に復元できる', () {
      HandicapPresets.sfenByLabel.forEach((label, sfen) {
        final parts = sfen.split(' ');
        final state = HandicapPresets.stateFor(label);
        expect(state, isNotNull, reason: '$label が復元できません');
        expect(SfenGenerator.generateKey(state!), '${parts[0]} ${parts[1]} ${parts[2]}',
            reason: '$label の盤面が一致しません');
        expect(state.nextPlayer, Player.sente, reason: '$label の手番が不正です');
        expect(state.senteHand, isEmpty, reason: '$label の先手持駒が不正です');
        expect(state.goteHand, isEmpty, reason: '$label の後手持駒が不正です');
      });
    });

    test('上手（後手）の駒が落ちている', () {
      // 香落ち: 後手の左香（9一）が無い
      final kyochi = HandicapPresets.stateFor('香落ち')!;
      expect(kyochi.grid[0][0], isNull);
      expect(kyochi.grid[0][8], 'wya');

      // 二枚落ち: 後手の角・飛が無い
      final nimaichi = HandicapPresets.stateFor('二枚落ち')!;
      expect(nimaichi.grid[1][1], isNull);
      expect(nimaichi.grid[1][7], isNull);
      expect(nimaichi.grid[0][4], 'wgy');

      // 十枚落ち: 後手は玉のみ
      final jumaichi = HandicapPresets.stateFor('十枚落ち')!;
      expect(SfenGenerator.generateKey(jumaichi),
          '4k4/9/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b -');
    });

    test('左香落ちは香落ちと同じ局面、右香落ちは別の局面', () {
      final hidari = HandicapPresets.stateFor('左香落ち')!;
      final kyo = HandicapPresets.stateFor('香落ち')!;
      expect(SfenGenerator.generateKey(hidari), SfenGenerator.generateKey(kyo));

      final migi = HandicapPresets.stateFor('右香落ち')!;
      expect(SfenGenerator.generateKey(migi),
          '1nsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b -');
      expect(SfenGenerator.generateKey(migi), isNot(SfenGenerator.generateKey(kyo)));
    });
  });

  group('KifParser.decode の手合割対応', () {
    String kif(String? handicap, String moves) {
      final header = StringBuffer();
      if (handicap != null) {
        header.writeln('手合割：$handicap');
      }
      header.writeln('棋戦：テスト');
      header.writeln('手数----指手----消費時間--');
      header.write(moves);
      return header.toString();
    }

    test('香落ちのKIFは香落ちの開始局面から読み込める', () {
      final tree = KifParser.decode(kif('香落ち', '1 ７六歩(77)\n2 ３四歩(33)\n'));
      expect(
        SfenGenerator.generateKey(tree.root.state),
        SfenGenerator.generateKey(HandicapPresets.stateFor('香落ち')!),
      );
      expect(tree.root.moveNumber, 0);
      // 1手目は先手の指し手として正しく適用される
      final first = tree.root.nextNodes.first;
      expect(first.moveLabel, '７六歩(77)');
      expect(first.state.grid[5][9 - 7], 'bfu');
      expect(first.state.nextPlayer, Player.gote);
      // 2手目は後手の指し手として正しく適用される
      final second = first.nextNodes.first;
      expect(second.state.grid[5][9 - 3], 'wfu');
      expect(second.state.nextPlayer, Player.sente);
    });

    test('二枚落ちのKIFは二枚落ちの開始局面から読み込める', () {
      final tree = KifParser.decode(kif('二枚落ち', '1 ７六歩(77)\n2 ８四歩(83)\n'));
      expect(
        SfenGenerator.generateKey(tree.root.state),
        SfenGenerator.generateKey(HandicapPresets.stateFor('二枚落ち')!),
      );
      final second = tree.root.nextNodes.first.nextNodes.first;
      expect(second.state.grid[5][9 - 8], 'wfu');
    });

    test('飛車落ちのKIFも開始局面が切り替わる', () {
      final tree = KifParser.decode(kif('飛車落ち', '1 ２六歩(27)\n'));
      expect(
        SfenGenerator.generateKey(tree.root.state),
        SfenGenerator.generateKey(HandicapPresets.stateFor('飛車落ち')!),
      );
    });

    test('左香落ちは香落ちと同じ開始局面になる', () {
      final tree = KifParser.decode(kif('左香落ち', '1 ７六歩(77)\n'));
      expect(
        SfenGenerator.generateKey(tree.root.state),
        SfenGenerator.generateKey(HandicapPresets.stateFor('香落ち')!),
      );
    });

    test('平手のヘッダーがあっても従来どおり平手の初期局面から始まる', () {
      final tree = KifParser.decode(kif('平手', '1 ７六歩(77)\n'));
      expect(SfenGenerator.generateKey(tree.root.state),
          SfenGenerator.generateKey(BoardState.initial()));
    });

    test('ヘッダー無しの平手KIFは従来と変わらない', () {
      final tree = KifParser.decode(kif(null, '1 ７六歩(77)\n2 ３四歩(33)\n'));
      expect(SfenGenerator.generateKey(tree.root.state),
          SfenGenerator.generateKey(BoardState.initial()));
      expect(tree.root.nextNodes.first.moveLabel, '７六歩(77)');
      expect(tree.root.nextNodes.first.nextNodes.first.moveLabel, '３四歩(33)');
    });

    test('プリセット外の手合割（歩三兵）は従来どおり平手として読む', () {
      final tree = KifParser.decode(kif('歩三兵', '1 ７六歩(77)\n'));
      expect(SfenGenerator.generateKey(tree.root.state),
          SfenGenerator.generateKey(BoardState.initial()));
      expect(tree.info['手合割'], '歩三兵');
    });
  });

  group('decode → encode → decode の往復', () {
    test('香落ちのKIFは開始局面と指し手を保って往復できる', () {
      const source = '''
手合割：香落ち
棋戦：テスト
手数----指手----消費時間--
   1 ７六歩(77)
   2 ３四歩(33)
   3 ２二飛(82)
''';
      final original = KifParser.decode(source);
      final encoded = KifParser.encode(original);
      final redecoded = KifParser.decode(encoded);

      expect(
        SfenGenerator.generateKey(redecoded.root.state),
        SfenGenerator.generateKey(HandicapPresets.stateFor('香落ち')!),
      );

      GameNode a = original.root;
      GameNode b = redecoded.root;
      while (a.nextNodes.isNotEmpty) {
        a = a.nextNodes.first;
        b = b.nextNodes.first;
        expect(b.moveNumber, a.moveNumber);
        expect(b.moveLabel, a.moveLabel);
        expect(SfenGenerator.generateKey(b.state), SfenGenerator.generateKey(a.state));
      }
    });

    test('二枚落ちのKIFも開始局面と指し手を保って往復できる', () {
      const source = '''
手合割：二枚落ち
棋戦：テスト
手数----指手----消費時間--
   1 ７六歩(77)
   2 ３四歩(33)
''';
      final original = KifParser.decode(source);
      final redecoded = KifParser.decode(KifParser.encode(original));

      expect(
        SfenGenerator.generateKey(redecoded.root.state),
        SfenGenerator.generateKey(HandicapPresets.stateFor('二枚落ち')!),
      );
      expect(redecoded.root.nextNodes.first.moveLabel, '７六歩(77)');
      expect(redecoded.root.nextNodes.first.nextNodes.first.moveLabel, '３四歩(33)');
    });
  });
}
