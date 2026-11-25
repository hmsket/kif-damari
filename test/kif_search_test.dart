import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/logic/kif_search.dart';

KifEntity _kif({
  int id = 1,
  String title = '先手 vs 後手',
  String? detail = '棋戦：名人戦\n戦型：矢倉',
}) {
  return KifEntity(
    id: id,
    tabId: 1,
    kifId: id,
    title: title,
    detail: detail,
    kifOrder: id,
    color: 0xFFFFFFFF,
  );
}

void main() {
  group('KifSearch.filter', () {
    test('タイトルに含まれる棋譜だけを返す', () {
      final kifs = [
        _kif(id: 1, title: '四間飛車の一局'),
        _kif(id: 2, title: '矢倉の一局'),
      ];

      final results = KifSearch.filter(kifs, '四間飛車');

      expect(results.map((kif) => kif.id), [1]);
    });

    test('詳細テキストに含まれる棋譜も返す', () {
      final kifs = [
        _kif(id: 1, title: '一局目', detail: '棋戦：名人戦'),
        _kif(id: 2, title: '二局目', detail: '棋戦：王将戦'),
      ];

      final results = KifSearch.filter(kifs, '王将戦');

      expect(results.map((kif) => kif.id), [2]);
    });

    test('大文字・小文字を区別しない', () {
      final kifs = [_kif(id: 1, title: 'AI vs Human')];

      expect(KifSearch.filter(kifs, 'human').map((kif) => kif.id), [1]);
    });

    test('該当がなければ空になる', () {
      final results = KifSearch.filter([_kif()], '存在しない棋譜');

      expect(results, isEmpty);
    });

    test('空文字と空白だけの検索は空になる', () {
      final kifs = [_kif()];

      expect(KifSearch.filter(kifs, ''), isEmpty);
      expect(KifSearch.filter(kifs, '   '), isEmpty);
    });

    test('検索語の前後の空白は無視する', () {
      final kifs = [_kif(id: 1, title: '矢倉')];

      expect(KifSearch.filter(kifs, ' 矢倉 ').map((kif) => kif.id), [1]);
    });
  });
}
