import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/position_search_result.dart';
import 'package:kifdamari/logic/position_searcher.dart';
import 'package:kifdamari/logic/sfen_generator.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/pages/position_search_result_page.dart';

/// (筋, 段, 駒コード) から盤面キーを作るテスト用ヘルパー。
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

PositionSearchResultRow row({
  required String positionKey,
  List<List<int>> matchedSquares = const [],
  int kifuCount = 0,
  String comment = '',
}) {
  return PositionSearchResultRow(
    hit: PositionSearchHit(
      positionKey: positionKey,
      matchedSquares: matchedSquares,
    ),
    kifuCount: kifuCount,
    comment: comment,
  );
}

void main() {
  group('並び順（sortRowsByKifuCount）', () {
    test('出現する棋譜の件数が多い順に並ぶ', () {
      final sorted = sortRowsByKifuCount([
        row(positionKey: 'a', kifuCount: 2),
        row(positionKey: 'b', kifuCount: 5),
        row(positionKey: 'c', kifuCount: 2),
        row(positionKey: 'd', kifuCount: 9),
      ]);

      expect(sorted.map((r) => r.hit.positionKey).toList(), ['d', 'b', 'a', 'c']);
    });

    test('件数が同じ行は入力の順序（安定）を保つ', () {
      final sorted = sortRowsByKifuCount([
        row(positionKey: 'first', kifuCount: 3),
        row(positionKey: 'second', kifuCount: 3),
      ]);

      expect(sorted.map((r) => r.hit.positionKey).toList(), ['first', 'second']);
    });
  });

  group('結果一覧画面', () {
    testWidgets('ヒットした局面がミニ盤と「出現する棋譜 n件」付きで一覧表示される', (tester) async {
      final key = keyFromPlacements([(5, 5, 'bka')]);
      final rows = [
        row(positionKey: key, matchedSquares: [[5, 5]], kifuCount: 3),
        row(
          positionKey: keyFromPlacements([(3, 3, 'bgi')]),
          matchedSquares: [[3, 3]],
          kifuCount: 1,
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: PositionSearchResultPage(
          pattern: patternFromPlacements([(5, 5, 'bka')]),
          mode: PositionSearchMode.exact,
          rows: rows,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('出現する棋譜 3件'), findsOneWidget);
      expect(find.text('出現する棋譜 1件'), findsOneWidget);

      // 件数が多い行が上に来る
      final top3 = tester.getTopLeft(find.text('出現する棋譜 3件')).dy;
      final top1 = tester.getTopLeft(find.text('出現する棋譜 1件')).dy;
      expect(top3, lessThan(top1));

      // 行のミニ盤にその局面の駒が表示される
      expect(find.byKey(const ValueKey('piece_44bka')), findsOneWidget);
    });

    testWidgets('マッチしたマスがハイライトされる', (tester) async {
      final key = keyFromPlacements([(5, 5, 'bka')]);

      await tester.pumpWidget(MaterialApp(
        home: PositionSearchResultPage(
          pattern: patternFromPlacements([(5, 5, 'bka')]),
          mode: PositionSearchMode.exact,
          rows: [row(positionKey: key, matchedSquares: [[5, 5]], kifuCount: 2)],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('result_highlight_5_5')), findsOneWidget);
    });

    testWidgets('局面コメントがある行は吹き出しアイコンとコメントの冒頭1行を出す', (tester) async {
      final key = keyFromPlacements([(5, 5, 'bka')]);

      await tester.pumpWidget(MaterialApp(
        home: PositionSearchResultPage(
          pattern: patternFromPlacements([(5, 5, 'bka')]),
          mode: PositionSearchMode.exact,
          rows: [
            row(
              positionKey: key,
              kifuCount: 1,
              comment: '先に角を交換したい\nここからは▼棒銀が強い',
            ),
            row(
              positionKey: keyFromPlacements([(3, 3, 'bgi')]),
              kifuCount: 1,
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chat_bubble), findsOneWidget);
      expect(find.text('先に角を交換したい'), findsOneWidget);
      // 2行目以降は出さない
      expect(find.text('ここからは▼棒銀が強い'), findsNothing);
    });

    testWidgets('コメントがない行には吹き出しアイコンを出さない', (tester) async {
      final key = keyFromPlacements([(5, 5, 'bka')]);

      await tester.pumpWidget(MaterialApp(
        home: PositionSearchResultPage(
          pattern: patternFromPlacements([(5, 5, 'bka')]),
          mode: PositionSearchMode.exact,
          rows: [row(positionKey: key, kifuCount: 1)],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chat_bubble), findsNothing);
    });

    testWidgets('ヒット0件は「見つかりませんでした」を表示する（パターンの概要は出す）', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PositionSearchResultPage(
          pattern: patternFromPlacements([(5, 5, 'bka')]),
          mode: PositionSearchMode.exact,
          rows: const [],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('見つかりませんでした'), findsOneWidget);
      // パターンの概要（小盤＋モードの説明）は出る
      expect(find.textContaining('場所も一致'), findsOneWidget);
      expect(find.byKey(const ValueKey('piece_44bka')), findsOneWidget);
    });

    testWidgets('「場所はどこでも」の概要には回転も対象である旨が出る', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PositionSearchResultPage(
          pattern: patternFromPlacements([(5, 5, 'bka')]),
          mode: PositionSearchMode.anywhere,
          rows: const [],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('回転'), findsOneWidget);
    });
  });
}
