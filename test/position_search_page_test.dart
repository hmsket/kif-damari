import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kifdamari/logic/position_searcher.dart';
import 'package:kifdamari/pages/position_search_page.dart';
import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/home_drawer.dart';

Finder pieceOnBoard(int gridX, int gridY, String pieceName) =>
    find.byKey(ValueKey('piece_${gridX}${gridY}$pieceName'));

/// パレットで駒を選択する
Future<void> selectPiece(WidgetTester tester, String pieceKey) async {
  await tester.tap(find.byKey(ValueKey(pieceKey)));
  await tester.pumpAndSettle();
}

/// 盤のマスをタップする
Future<void> tapSquare(WidgetTester tester, int gridX, int gridY) async {
  await tester.tap(find.byKey(ValueKey('square_${gridX}_$gridY')));
  await tester.pumpAndSettle();
}

/// 指定した表面サイズで検索画面を表示する
Future<void> pumpAtSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: PositionSearchPage()));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('kifdamari_drawer_test');
    Hive.init(dir.path);
    await Hive.openBox('settings_box');
  });

  tearDown(() async {
    await AppSettings().set('showAdvancedFeatures', false);
  });

  testWidgets('デフォルトではドロワーに上級機能の入口が出ない', (tester) async {
    expect(AppSettings().showAdvancedFeatures, isFalse);

    await tester.pumpWidget(const MaterialApp(home: HomeDrawer()));
    await tester.pumpAndSettle();

    expect(find.text('統合ツリー'), findsNothing);
    expect(find.text('局面検索'), findsNothing);
  });

  testWidgets('上級機能フラグをONにするとドロワーに入口が出る', (tester) async {
    await tester.runAsync(
      () => AppSettings().set('showAdvancedFeatures', true),
    );

    await tester.pumpWidget(const MaterialApp(home: HomeDrawer()));
    await tester.pumpAndSettle();

    expect(find.text('統合ツリー'), findsOneWidget);
    expect(find.text('局面検索'), findsOneWidget);
  });

  testWidgets('ドロワーの「局面検索」から検索画面を開ける', (tester) async {
    await tester.runAsync(
      () => AppSettings().set('showAdvancedFeatures', true),
    );

    await tester.pumpWidget(const MaterialApp(home: HomeDrawer()));
    await tester.tap(find.text('局面検索'));
    await tester.pumpAndSettle();

    expect(find.byType(PositionSearchPage), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('パレットで先手の歩を選んでマスをタップすると配置できる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PositionSearchPage()));
    await tester.pumpAndSettle();

    await selectPiece(tester, 'piece_tile_b_fu');
    await tapSquare(tester, 4, 8);

    expect(pieceOnBoard(4, 8, 'bfu'), findsOneWidget);
  });

  testWidgets('選択は保持され、同じ駒を連続で置ける', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PositionSearchPage()));
    await tester.pumpAndSettle();

    await selectPiece(tester, 'piece_tile_b_fu');
    await tapSquare(tester, 4, 8);
    await tapSquare(tester, 3, 8);

    expect(pieceOnBoard(4, 8, 'bfu'), findsOneWidget);
    expect(pieceOnBoard(3, 8, 'bfu'), findsOneWidget);
  });

  testWidgets('置き済みのマスを別の駒でタップすると上書きされる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PositionSearchPage()));
    await tester.pumpAndSettle();

    await selectPiece(tester, 'piece_tile_b_fu');
    await tapSquare(tester, 4, 8);
    expect(pieceOnBoard(4, 8, 'bfu'), findsOneWidget);

    await selectPiece(tester, 'piece_tile_b_hi');
    await tapSquare(tester, 4, 8);

    expect(pieceOnBoard(4, 8, 'bfu'), findsNothing);
    expect(pieceOnBoard(4, 8, 'bhi'), findsOneWidget);
  });

  testWidgets('消しゴム選択中はマスタップで駒を消せて、全消しボタンで盤が空になる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PositionSearchPage()));
    await tester.pumpAndSettle();

    // 先手の歩を配置
    await selectPiece(tester, 'piece_tile_b_fu');
    await tapSquare(tester, 4, 8);
    expect(pieceOnBoard(4, 8, 'bfu'), findsOneWidget);

    // 消しゴムを選んで同じマスをタップすると消える
    await tester.tap(find.byKey(const ValueKey('palette_eraser')));
    await tester.pumpAndSettle();
    await tapSquare(tester, 4, 8);
    expect(pieceOnBoard(4, 8, 'bfu'), findsNothing);

    // 後手の玉を配置して全消し
    await tester.tap(find.text('後手'));
    await tester.pumpAndSettle();
    await selectPiece(tester, 'piece_tile_w_gy');
    await tapSquare(tester, 4, 0);
    expect(pieceOnBoard(4, 0, 'wgy'), findsOneWidget);

    await tester.tap(find.text('全消し'));
    await tester.pumpAndSettle();
    expect(pieceOnBoard(4, 0, 'wgy'), findsNothing);
  });

  testWidgets('先手/後手の切替で選択中の駒種が保持され、相手側の同種駒に切り替わる', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PositionSearchPage()));
    await tester.pumpAndSettle();

    await selectPiece(tester, 'piece_tile_b_fu');
    await tester.tap(find.text('後手'));
    await tester.pumpAndSettle();

    // パレットが後手の駒に変わる
    expect(find.byKey(const ValueKey('piece_tile_b_fu')), findsNothing);
    expect(find.byKey(const ValueKey('piece_tile_w_fu')), findsOneWidget);

    // 選択は後手の歩に引き継がれている（再選択なしで置ける）
    await tapSquare(tester, 4, 0);
    expect(pieceOnBoard(4, 0, 'wfu'), findsOneWidget);
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

    // 先手の歩をスタンプしてから検索する
    await selectPiece(tester, 'piece_tile_b_fu');
    await tapSquare(tester, 4, 8);

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

  group('どんな画面サイズでも縦スクロールなしで表示できる', () {
    const Map<String, Size> surfaceSizes = {
      '320x568': Size(320, 568),
      '360x640': Size(360, 640),
      '375x667': Size(375, 667),
      '390x844': Size(390, 844),
    };

    surfaceSizes.forEach((label, size) {
      testWidgets('$label で overflow エラーが出ず、検索ボタンまで表示される', (tester) async {
        await pumpAtSize(tester, size);

        expect(tester.takeException(), isNull);

        final searchButton = find.text('検索');
        expect(searchButton, findsOneWidget);
        final rect = tester.getRect(searchButton);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));

        // 検索ボタンが実際に押せる
        await tester.tap(searchButton);
        await tester.pumpAndSettle();
        expect(find.text('検索結果'), findsOneWidget);
      });
    });
  });
}
