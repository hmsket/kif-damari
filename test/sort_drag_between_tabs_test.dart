import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/dao/tab_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
import 'package:kifdamari/pages/home_page.dart';
import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/kif_list_item.dart';

class _FakeTabDao extends TabDao {
  _FakeTabDao(this.tabs);

  final List<TabEntity> tabs;

  @override
  Future<List<TabEntity>> getAllTabs() async => List.of(tabs);
}

class _FakeKifDao extends KifDao {
  _FakeKifDao(this.kifsByTab);

  final Map<int, List<KifEntity>> kifsByTab;
  int getKifsByTabCallCount = 0;
  List<KifEntity>? lastSavedOrder;

  @override
  Future<List<KifEntity>> getKifsByTab(int tabId) async {
    getKifsByTabCallCount++;
    return List.of(kifsByTab[tabId] ?? const <KifEntity>[]);
  }

  @override
  Future<void> updateAllKifOrders(List<KifEntity> kifs) async {
    lastSavedOrder = List.of(kifs);
    if (kifs.isEmpty) return;
    kifsByTab[kifs.first.tabId] = List.of(kifs);
  }

  @override
  Future<void> moveKifToTab(
    KifEntity kif,
    int targetTabId, {
    int? targetIndex,
  }) async {
    KifEntity? moved;
    final from = kifsByTab[kif.tabId];
    if (from != null) {
      final index = from.indexWhere((item) => item.id == kif.id);
      if (index >= 0) moved = from.removeAt(index);
    }
    final target = kifsByTab.putIfAbsent(targetTabId, () => <KifEntity>[]);
    final insertAt =
        (targetIndex ?? target.length).clamp(0, target.length).toInt();
    final source = moved ?? kif;
    target.insert(
      insertAt,
      KifEntity(
        id: source.id,
        tabId: targetTabId,
        kifId: insertAt + 1,
        title: source.title,
        detail: source.detail,
        kifOrder: insertAt,
        kifPath: source.kifPath,
        imgPath: source.imgPath,
        color: source.color,
      ),
    );
  }

  @override
  Future<void> deleteKifs(List<int> ids) async {
    for (final kifs in kifsByTab.values) {
      kifs.removeWhere((item) => ids.contains(item.id));
    }
  }
}

KifEntity _kif({
  required int id,
  required int tabId,
  required int order,
  required String title,
}) {
  return KifEntity(
    id: id,
    tabId: tabId,
    kifId: order + 1,
    title: title,
    detail: '',
    kifOrder: order,
    kifPath: '',
    color: 0xFFFFFFFF,
  );
}

List<TabEntity> _tabs({int count = 2}) => [
      for (var i = 0; i < count; i++)
        TabEntity(id: i + 1, title: 'タブ${String.fromCharCode(65 + i)}', tabOrder: i),
    ];

Map<int, List<KifEntity>> _kifs() => {
      1: [
        _kif(id: 11, tabId: 1, order: 0, title: '棋譜A'),
        _kif(id: 12, tabId: 1, order: 1, title: '棋譜B'),
        _kif(id: 13, tabId: 1, order: 2, title: '棋譜C'),
      ],
      2: <KifEntity>[],
    };

Future<void> _pumpHomePage(
  WidgetTester tester,
  _FakeTabDao tabDao,
  _FakeKifDao kifDao,
) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    home: HomePage(
      tabDao: tabDao,
      kifDao: kifDao,
      useGoogleFonts: false,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _enterSortMode(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.swap_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text('棋譜を並び替え'));
  await tester.pumpAndSettle();
}

Future<TestGesture> _startLongPressDrag(WidgetTester tester, Finder card) async {
  final gesture = await tester.startGesture(tester.getCenter(card));
  await tester.pump();
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  return gesture;
}

double get _screenWidth => 400;

Offset _edgePosition(WidgetTester tester, Finder card, {required bool right}) {
  final y = tester.getCenter(card).dy;
  final x = right ? _screenWidth - 5 : 5.0;
  return Offset(x, y);
}

/// 端ゾーンへ移動し、タブ切り替えが起こるまで待つ。
Future<void> _hoverAtEdge(
  WidgetTester tester,
  TestGesture gesture,
  Offset edge, {
  int switches = 1,
}) async {
  await gesture.moveTo(edge);
  // 最初の切り替え（約0.5秒）と、2回目以降（約0.7秒間隔）を待つ。
  await tester.pump(const Duration(milliseconds: 600));
  for (var i = 1; i < switches; i++) {
    await tester.pump(const Duration(milliseconds: 800));
  }
  // タブ切り替えアニメーションを完了させる。
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _reorderWithinTab(WidgetTester tester) async {
  final start = tester.getCenter(find.text('棋譜A'));
  final target = tester.getCenter(find.text('棋譜C'));
  final gesture = await _startLongPressDrag(tester, find.text('棋譜A'));
  // 実際のドラッグに近づけるため、少しずつ移動して並び替えを確定させる。
  for (var i = 1; i <= 10; i++) {
    await gesture.moveTo(Offset.lerp(start, target, i / 10)!);
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.up();
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.check));
  await tester.pumpAndSettle();
}

/// 操作完了時に表示される成功スナックバーのタイマーを消化する。
Future<void> _drainSnackbar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('kifdamari_sort_drag_test');
    Hive.init(hiveDir.path);
    await Hive.openBox('settings_box');
  });

  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) {
      hiveDir.deleteSync(recursive: true);
    }
  });

  testWidgets('グリッド: 右端に留まると右のタブへ切り替わり、そのままドロップで移動できる',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await tester.runAsync(() => AppSettings().set('homeViewMode', 'grid'));
    final kifDao = _FakeKifDao(_kifs());
    await _pumpHomePage(tester, _FakeTabDao(_tabs()), kifDao);
    expect(find.byType(KifGridItem), findsWidgets);

    await _enterSortMode(tester);

    final card = find.text('棋譜A');
    final gesture = await _startLongPressDrag(tester, card);
    await _hoverAtEdge(
      tester,
      gesture,
      _edgePosition(tester, card, right: true),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(kifDao.kifsByTab[1]!.any((kif) => kif.title == '棋譜A'), isFalse);
    expect(kifDao.kifsByTab[2]!.any((kif) => kif.title == '棋譜A'), isTrue);
    expect(find.text('棋譜A'), findsOneWidget);
    expect(find.text('『タブB』へ移動しました'), findsOneWidget);

    await _drainSnackbar(tester);
  });

  testWidgets('リスト: 右端に留まると右のタブへ切り替わり、そのままドロップで移動できる',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await tester.runAsync(() => AppSettings().set('homeViewMode', 'list'));
    final kifDao = _FakeKifDao(_kifs());
    await _pumpHomePage(tester, _FakeTabDao(_tabs()), kifDao);
    expect(find.byType(KifListItem), findsWidgets);

    await _enterSortMode(tester);

    final card = find.text('棋譜A');
    final gesture = await _startLongPressDrag(tester, card);
    await _hoverAtEdge(
      tester,
      gesture,
      _edgePosition(tester, card, right: true),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(kifDao.kifsByTab[1]!.any((kif) => kif.title == '棋譜A'), isFalse);
    expect(kifDao.kifsByTab[2]!.any((kif) => kif.title == '棋譜A'), isTrue);
    expect(find.text('棋譜A'), findsOneWidget);
    expect(find.text('『タブB』へ移動しました'), findsOneWidget);

    await _drainSnackbar(tester);
  });

  testWidgets('グリッド: 左端に留まると左のタブへ切り替わり、そのままドロップで移動できる',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await tester.runAsync(() => AppSettings().set('homeViewMode', 'grid'));
    final kifDao = _FakeKifDao({
      1: <KifEntity>[],
      2: [
        _kif(id: 21, tabId: 2, order: 0, title: '棋譜A'),
        _kif(id: 22, tabId: 2, order: 1, title: '棋譜B'),
      ],
    });
    await _pumpHomePage(tester, _FakeTabDao(_tabs()), kifDao);

    // 最初のタブから左へは戻れないため、タブBを開いてから並び替えを始める。
    await tester.tap(find.text('タブB'));
    await tester.pumpAndSettle();
    await _enterSortMode(tester);
    expect(find.byType(KifGridItem), findsWidgets);

    final card = find.text('棋譜A');
    final gesture = await _startLongPressDrag(tester, card);
    await _hoverAtEdge(
      tester,
      gesture,
      _edgePosition(tester, card, right: false),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(kifDao.kifsByTab[2]!.any((kif) => kif.title == '棋譜A'), isFalse);
    expect(kifDao.kifsByTab[1]!.any((kif) => kif.title == '棋譜A'), isTrue);
    expect(find.text('棋譜A'), findsOneWidget);
    expect(find.text('『タブA』へ移動しました'), findsOneWidget);

    await _drainSnackbar(tester);
  });

  testWidgets('グリッド: 右端に留まり続けると複数のタブを順に送れる',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await tester.runAsync(() => AppSettings().set('homeViewMode', 'grid'));
    final kifDao = _FakeKifDao({
      1: [
        _kif(id: 11, tabId: 1, order: 0, title: '棋譜A'),
        _kif(id: 12, tabId: 1, order: 1, title: '棋譜B'),
      ],
      2: <KifEntity>[],
      3: <KifEntity>[],
    });
    await _pumpHomePage(tester, _FakeTabDao(_tabs(count: 3)), kifDao);
    await _enterSortMode(tester);

    final card = find.text('棋譜A');
    final gesture = await _startLongPressDrag(tester, card);
    await _hoverAtEdge(
      tester,
      gesture,
      _edgePosition(tester, card, right: true),
      switches: 2,
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(kifDao.kifsByTab[1]!.any((kif) => kif.title == '棋譜A'), isFalse);
    expect(kifDao.kifsByTab[2]!, isEmpty);
    expect(kifDao.kifsByTab[3]!.any((kif) => kif.title == '棋譜A'), isTrue);
    expect(find.text('『タブC』へ移動しました'), findsOneWidget);

    await _drainSnackbar(tester);
  });

  testWidgets('グリッド: 1件だけのタブから端ゾーンで切り替えてドロップしても浮遊表示が残らない',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await tester.runAsync(() => AppSettings().set('homeViewMode', 'grid'));
    final kifDao = _FakeKifDao({
      1: [_kif(id: 11, tabId: 1, order: 0, title: '棋譜A')],
      2: <KifEntity>[],
    });
    await _pumpHomePage(tester, _FakeTabDao(_tabs()), kifDao);
    await _enterSortMode(tester);

    final card = find.text('棋譜A');
    final gesture = await _startLongPressDrag(tester, card);
    await _hoverAtEdge(
      tester,
      gesture,
      _edgePosition(tester, card, right: true),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    // 元タブが空になっても、ドロップ後に浮遊表示が残っていないこと。
    expect(kifDao.kifsByTab[1]!, isEmpty);
    expect(kifDao.kifsByTab[2]!.any((kif) => kif.title == '棋譜A'), isTrue);
    expect(find.text('棋譜A'), findsOneWidget);
    expect(find.text('『タブB』へ移動しました'), findsOneWidget);

    await _drainSnackbar(tester);
  });

  testWidgets('リスト: 1件だけのタブから端ゾーンで切り替えてドロップしても浮遊表示が残らない',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await tester.runAsync(() => AppSettings().set('homeViewMode', 'list'));
    final kifDao = _FakeKifDao({
      1: [_kif(id: 11, tabId: 1, order: 0, title: '棋譜A')],
      2: <KifEntity>[],
    });
    await _pumpHomePage(tester, _FakeTabDao(_tabs()), kifDao);
    await _enterSortMode(tester);

    final card = find.text('棋譜A');
    final gesture = await _startLongPressDrag(tester, card);
    await _hoverAtEdge(
      tester,
      gesture,
      _edgePosition(tester, card, right: true),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    // 元タブが空になっても、ドロップ後に浮遊表示が残っていないこと。
    expect(kifDao.kifsByTab[1]!, isEmpty);
    expect(kifDao.kifsByTab[2]!.any((kif) => kif.title == '棋譜A'), isTrue);
    expect(find.text('棋譜A'), findsOneWidget);
    expect(find.text('『タブB』へ移動しました'), findsOneWidget);

    await _drainSnackbar(tester);
  });

  testWidgets('グリッド: 端ゾーンで切り替えた後にドラッグをキャンセルしても浮遊表示が残らない',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await tester.runAsync(() => AppSettings().set('homeViewMode', 'grid'));
    final kifDao = _FakeKifDao({
      1: [_kif(id: 11, tabId: 1, order: 0, title: '棋譜A')],
      2: <KifEntity>[],
    });
    await _pumpHomePage(tester, _FakeTabDao(_tabs()), kifDao);
    await _enterSortMode(tester);

    final card = find.text('棋譜A');
    final gesture = await _startLongPressDrag(tester, card);
    await _hoverAtEdge(
      tester,
      gesture,
      _edgePosition(tester, card, right: true),
    );
    await gesture.cancel();
    await tester.pumpAndSettle();

    // キャンセルなので移動していない。
    expect(kifDao.kifsByTab[1]!.any((kif) => kif.title == '棋譜A'), isTrue);
    expect(kifDao.kifsByTab[2]!, isEmpty);

    // 元のタブへ戻したときに浮遊表示が重複していないこと。
    await tester.tap(find.text('タブA'));
    await tester.pumpAndSettle();
    expect(find.text('棋譜A'), findsOneWidget);
  });

  testWidgets('グリッド: 端ゾーンに入らない同一タブ内の並び替えではタブが切り替わらない',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await tester.runAsync(() => AppSettings().set('homeViewMode', 'grid'));
    final kifDao = _FakeKifDao(_kifs());
    await _pumpHomePage(tester, _FakeTabDao(_tabs()), kifDao);

    await _enterSortMode(tester);
    await _reorderWithinTab(tester);

    expect(kifDao.lastSavedOrder, isNotNull);
    final titles = kifDao.lastSavedOrder!.map((kif) => kif.title).toList();
    expect(titles.toSet(), {'棋譜A', '棋譜B', '棋譜C'});
    expect(titles, isNot(equals(['棋譜A', '棋譜B', '棋譜C'])));
    // タブ移動は起きていない。
    expect(kifDao.kifsByTab[2]!, isEmpty);

    await _drainSnackbar(tester);
  });

  testWidgets('リスト: 端ゾーンに入らない同一タブ内の並び替えではタブが切り替わらない',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await tester.runAsync(() => AppSettings().set('homeViewMode', 'list'));
    final kifDao = _FakeKifDao(_kifs());
    await _pumpHomePage(tester, _FakeTabDao(_tabs()), kifDao);

    await _enterSortMode(tester);
    await _reorderWithinTab(tester);

    expect(kifDao.lastSavedOrder, isNotNull);
    final titles = kifDao.lastSavedOrder!.map((kif) => kif.title).toList();
    expect(titles.toSet(), {'棋譜A', '棋譜B', '棋譜C'});
    expect(titles, isNot(equals(['棋譜A', '棋譜B', '棋譜C'])));
    expect(kifDao.kifsByTab[2]!, isEmpty);

    await _drainSnackbar(tester);
  });
}
