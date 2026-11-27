import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
import 'package:kifdamari/widgets/kif_search_view.dart';

TabEntity _tab({required int id}) {
  return TabEntity(id: id, title: 'タブ$id', tabOrder: id);
}

KifEntity _kif({
  required int id,
  required int tabId,
  required String title,
  String? detail,
}) {
  return KifEntity(
    id: id,
    tabId: tabId,
    kifId: id,
    title: title,
    detail: detail,
    kifOrder: id,
    color: 0xFFFFFFFF,
  );
}

Future<void> _pumpSearch(
  WidgetTester tester, {
  required String query,
  required KifSearchTabsLoader loadTabs,
  required KifSearchKifsLoader loadKifsByTab,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: KifSearchView(
          query: query,
          loadTabs: loadTabs,
          loadKifsByTab: loadKifsByTab,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('読み込みに失敗したタブを除いて、他のタブの棋譜を検索できる', (tester) async {
    final tabs = [_tab(id: 1), _tab(id: 2)];

    Future<List<TabEntity>> loadTabs() async => tabs;

    Future<List<KifEntity>> loadKifsByTab(int tabId) async {
      if (tabId == 1) {
        throw StateError('壊れた棋譜行');
      }
      return [
        _kif(
          id: 2,
          tabId: 2,
          title: 'たろう vs 後手',
          detail: '棋戦：たなか',
        ),
      ];
    }

    await _pumpSearch(
      tester,
      query: 'たろう',
      loadTabs: loadTabs,
      loadKifsByTab: loadKifsByTab,
    );

    expect(find.byKey(const ValueKey('search_grid_2')), findsOneWidget);
    expect(find.text('該当する棋譜がありません'), findsNothing);
    expect(find.text('一部のタブを読み込めませんでした（1件）'), findsOneWidget);

    // 検索語を詳細テキストに変えても同じ棋譜がヒットする。
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KifSearchView(
            query: 'たなか',
            loadTabs: loadTabs,
            loadKifsByTab: loadKifsByTab,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search_grid_2')), findsOneWidget);
  });

  testWidgets('全タブの読み込みに失敗したらエラーと再試行を表示する', (tester) async {
    final tabs = [_tab(id: 1), _tab(id: 2)];
    var shouldFail = true;

    Future<List<TabEntity>> loadTabs() async => tabs;

    Future<List<KifEntity>> loadKifsByTab(int tabId) async {
      if (shouldFail) {
        throw StateError('読み込み失敗');
      }
      return [
        _kif(
          id: tabId == 2 ? 2 : 1,
          tabId: tabId,
          title: tabId == 2 ? 'たろう vs 後手' : '別の棋譜',
          detail: tabId == 2 ? '棋戦：たなか' : null,
        ),
      ];
    }

    await _pumpSearch(
      tester,
      query: 'たろう',
      loadTabs: loadTabs,
      loadKifsByTab: loadKifsByTab,
    );

    expect(find.text('棋譜を読み込めませんでした'), findsOneWidget);
    expect(find.text('エラー: StateError'), findsOneWidget);
    expect(find.text('再試行'), findsOneWidget);
    expect(find.text('該当する棋譜がありません'), findsNothing);

    shouldFail = false;
    await tester.tap(find.text('再試行'));
    await tester.pumpAndSettle();

    expect(find.text('棋譜を読み込めませんでした'), findsNothing);
    expect(find.text('再試行'), findsNothing);
    expect(find.byKey(const ValueKey('search_grid_2')), findsOneWidget);
    expect(find.text('一部のタブを読み込めませんでした（1件）'), findsNothing);
  });

  testWidgets('タブ一覧の取得に失敗してもエラーと再試行を表示する', (tester) async {
    Future<List<TabEntity>> loadTabs() async {
      throw StateError('タブ取得失敗');
    }

    await _pumpSearch(
      tester,
      query: 'たろう',
      loadTabs: loadTabs,
      loadKifsByTab: (_) async => const [],
    );

    expect(find.text('棋譜を読み込めませんでした'), findsOneWidget);
    expect(find.text('エラー: StateError'), findsOneWidget);
    expect(find.text('再試行'), findsOneWidget);
    expect(find.text('該当する棋譜がありません'), findsNothing);
  });
}
