import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/position_searcher.dart';
import 'package:kifdamari/logic/sfen_generator.dart';
import 'package:kifdamari/models/board_state.dart';

/// (筋, 段, 駒コード) から盤面キーを作るテスト用ヘルパー。
/// 筋・段は 1〜9（先手から見た座標）。
String keyFromPlacements(List<(int, int, String)> placements) {
  final grid = List.generate(9, (_) => List<String?>.filled(9, null));
  for (final (file, rank, piece) in placements) {
    grid[rank - 1][9 - file] = piece;
  }
  return SfenGenerator.generateKey(BoardState(
    grid: grid,
    senteHand: const {},
    goteHand: const {},
    nextPlayer: Player.sente,
  ));
}

/// パターン盤を作るヘルパー。
List<List<String?>> patternFromPlacements(List<(int, int, String)> placements) {
  final pattern = List.generate(9, (_) => List<String?>.filled(9, null));
  for (final (file, rank, piece) in placements) {
    pattern[rank - 1][9 - file] = piece;
  }
  return pattern;
}

void main() {
  group('場所も一致モード', () {
    test('指定マスにその駒がある局面だけヒットする', () {
      final keys = [
        keyFromPlacements([(7, 7, 'bgi')]),
        keyFromPlacements([(8, 7, 'bgi')]),
        keyFromPlacements([(7, 7, 'wgi')]),
      ];
      final pattern = patternFromPlacements([(7, 7, 'bgi')]);

      final hits = PositionSearcher.search(keys, pattern, PositionSearchMode.exact);

      expect(hits, hasLength(1));
      expect(hits.first.positionKey, keys[0]);
      expect(hits.first.matchedSquares, [
        [7, 7],
      ]);
    });

    test('置いていないマス・手番・持駒は不問', () {
      // 同じマスに同じ駒があれば、他の駒や手番が違ってもヒットする
      final keys = [
        keyFromPlacements([(7, 7, 'bgi'), (5, 3, 'whi')]),
        'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPSPPPPPP/1B5R1/LNSGKGSNL w R',
      ];
      final pattern = patternFromPlacements([(7, 7, 'bgi')]);

      final hits = PositionSearcher.search(keys, pattern, PositionSearchMode.exact);

      expect(hits, hasLength(2));
    });

    test('パターンに駒がない場合は何もヒットしない', () {
      final keys = [keyFromPlacements([(7, 7, 'bgi')])];
      final pattern = List.generate(9, (_) => List<String?>.filled(9, null));

      expect(
        PositionSearcher.search(keys, pattern, PositionSearchMode.exact),
        isEmpty,
      );
    });
  });

  group('場所はどこでもモード', () {
    test('相対配置が同じなら別の場所でもヒットする', () {
      // 飛の右上に金（相対位置 +1筋 / -1段）
      final keys = [
        keyFromPlacements([(4, 3, 'bhi'), (5, 2, 'bki')]),
        keyFromPlacements([(4, 3, 'bhi'), (5, 3, 'bki')]), // 相対位置が違う
        keyFromPlacements([(4, 3, 'bhi'), (5, 2, 'wki')]), // 先後が違う
      ];
      final pattern = patternFromPlacements([(8, 8, 'bhi'), (9, 7, 'bki')]);

      final hits = PositionSearcher.search(keys, pattern, PositionSearchMode.anywhere);

      expect(hits, hasLength(1));
      expect(hits.first.positionKey, keys[0]);
      // マッチしたマスはターゲット側の座標で返る（②のハイライト用）
      expect(hits.first.matchedSquares, [
        [4, 3],
        [5, 2],
      ]);
    });

    test('180°回転＋先後入替（後手向き）の配置もヒットする', () {
      // パターン: 8八の飛の9七（右上）に金 → 回転後手向き: 2九の飛の3八（右下）に金
      final keys = [
        keyFromPlacements([(8, 8, 'bhi'), (9, 7, 'bki')]), // そのまま一致
        keyFromPlacements([(2, 2, 'whi'), (1, 3, 'wki')]), // 後手向きで一致
        keyFromPlacements([(2, 2, 'bhi'), (1, 3, 'wki')]), // 回転のみで先後が違う
      ];
      final pattern = patternFromPlacements([(8, 8, 'bhi'), (9, 7, 'bki')]);

      final hits = PositionSearcher.search(keys, pattern, PositionSearchMode.anywhere);

      expect(hits, hasLength(2));
      expect(hits[0].positionKey, keys[0]);
      expect(hits[0].matchedSquares, [
        [8, 8],
        [9, 7],
      ]);
      expect(hits[1].positionKey, keys[1]);
      expect(hits[1].matchedSquares, [
        [2, 2],
        [1, 3],
      ]);
    });

    test('パターンが盤からはみ出す相対配置は考慮されない', () {
      // パターンの相対配置は盤内に収まる置き方だけを試す
      final keys = [
        keyFromPlacements([(4, 3, 'bhi'), (5, 2, 'bki')]),
      ];
      final pattern = patternFromPlacements([(1, 9, 'bhi'), (2, 8, 'bki')]);

      final hits = PositionSearcher.search(keys, pattern, PositionSearchMode.anywhere);
      // 1九の飛の2八金 → 平行移動で (4,3),(5,2) に一致する
      expect(hits, hasLength(1));
    });
  });

  group('盤面キーの走査', () {
    test('不正なキーはスキップされる', () {
      final hits = PositionSearcher.search(
        ['not a key', keyFromPlacements([(7, 7, 'bgi')])],
        patternFromPlacements([(7, 7, 'bgi')]),
        PositionSearchMode.exact,
      );
      expect(hits, hasLength(1));
    });
  });
}
