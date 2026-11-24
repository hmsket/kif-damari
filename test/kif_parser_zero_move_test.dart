import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/logic/sfen_generator.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/models/kif_tree.dart';

void main() {
  group('KifParser.decode の0手KIF対応', () {
    test('氏名入り0手のKIFはencode→decodeでヘッダーが保持される', () {
      final tree = KifTree.initial();
      tree.info['先手'] = '山田太郎';
      tree.info['後手'] = '佐藤花子';

      final decoded = KifParser.decode(KifParser.encode(tree));

      expect(decoded.info['先手'], '山田太郎');
      expect(decoded.info['後手'], '佐藤花子');
      expect(decoded.root.nextNodes, isEmpty);
      expect(
        SfenGenerator.generateKey(decoded.root.state),
        SfenGenerator.generateKey(BoardState.initial()),
      );
    });

    test('ヘッダー情報だけの0手KIFを読み込める', () {
      const source = '''
先手：山田太郎
後手：佐藤花子
棋戦：テスト
手数----指手---------消費時間--
''';

      final decoded = KifParser.decode(source);

      expect(decoded.info['先手'], '山田太郎');
      expect(decoded.info['後手'], '佐藤花子');
      expect(decoded.info['棋戦'], 'テスト');
      expect(decoded.root.nextNodes, isEmpty);
    });

    test('指し手もヘッダー情報もないテキストは従来通りエラーになる', () {
      expect(
        () => KifParser.decode('ただの文章です\n二行目です'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => KifParser.decode('手数----指手---------消費時間--\n'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
