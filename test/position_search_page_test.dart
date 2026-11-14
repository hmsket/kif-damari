import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/position_searcher.dart';
import 'package:kifdamari/pages/position_search_page.dart';
import 'package:kifdamari/widgets/home_drawer.dart';

Finder pieceOnBoard(int gridX, int gridY, String pieceName) =>
    find.byKey(ValueKey('piece_${gridX}${gridY}$pieceName'));

void main() {
  testWidgets('ドロワーの「局面検索」から検索画面を開ける', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeDrawer()));
    await tester.tap(find.text('局面検索'));
    await tester.pumpAndSettle();

    expect(find.byType(PositionSearchPage), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('マスをタップして駒ピッカーから先手の歩を配置できる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PositionSearchPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('square_4_8')));
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('piece_tile_b_fu'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(pieceOnBoard(4, 8, 'bfu'), findsOneWidget);
  });

  testWidgets('駒のあるマスで「駒を消す」ができ、全消しボタンで盤が空になる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PositionSearchPage()));
    await tester.pumpAndSettle();

    // 先手の飛を配置
    await tester.tap(find.byKey(const ValueKey('square_1_8')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('piece_tile_b_hi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('piece_tile_b_hi')));
    await tester.pumpAndSettle();
    expect(pieceOnBoard(1, 8, 'bhi'), findsOneWidget);

    // 同じマスをタップすると「駒を消す」が出る
    await tester.tap(find.byKey(const ValueKey('square_1_8')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('駒を消す'));
    await tester.pumpAndSettle();
    expect(pieceOnBoard(1, 8, 'bhi'), findsNothing);

    // 後手の玉を配置して全消し
    await tester.tap(find.byKey(const ValueKey('square_4_0')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('piece_tile_w_gy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('piece_tile_w_gy')));
    await tester.pumpAndSettle();
    expect(pieceOnBoard(4, 0, 'wgy'), findsOneWidget);

    await tester.tap(find.text('全消し'));
    await tester.pumpAndSettle();
    expect(pieceOnBoard(4, 0, 'wgy'), findsNothing);
    expect(pieceOnBoard(1, 8, 'bhi'), findsNothing);
  });

  testWidgets('モードを「場所はどこでも」に切り替えられる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PositionSearchPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('場所はどこでも'));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<PositionSearchMode>), findsOneWidget);
  });

  testWidgets('検索ボタンで結果一覧画面へ遷移する（0件）', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PositionSearchPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('検索'));
    await tester.pumpAndSettle();

    expect(find.text('検索結果'), findsOneWidget);
    expect(find.text('見つかりませんでした'), findsOneWidget);
  });

  testWidgets('結果一覧画面の0件表示でもパターンの概要（小盤＋モード説明）が出る', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PositionSearchPage()));
    await tester.pumpAndSettle();

    // 先手の歩を配置してから検索する
    await tester.tap(find.byKey(const ValueKey('square_4_8')));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('piece_tile_b_fu'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    await tester.tap(find.text('検索'));
    await tester.pumpAndSettle();

    expect(find.text('見つかりませんでした'), findsOneWidget);
    // パターンの概要の小盤に置いた駒が表示される
    expect(find.byKey(const ValueKey('piece_48bfu')), findsOneWidget);
    expect(find.textContaining('場所も一致'), findsOneWidget);
  });

  testWidgets('「場所はどこでも」で検索すると回転も対象である旨が概要に出る', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PositionSearchPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('場所はどこでも'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('検索'));
    await tester.pumpAndSettle();

    expect(find.text('見つかりませんでした'), findsOneWidget);
    expect(find.textContaining('回転'), findsOneWidget);
  });
}
