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
  Future<void> moveKifToTab(KifEntity kif, int targetTabId) async {
    final from = kifsByTab[kif.tabId];
    from?.removeWhere((item) => item.id == kif.id);
    final target = kifsByTab.putIfAbsent(targetTabId, () => <KifEntity>[]);
    target.add(KifEntity(
      id: kif.id,
      tabId: targetTabId,
      kifId: target.length + 1,
      title: kif.title,
      detail: kif.detail,
      kifOrder: target.length,
      kifPath: kif.kifPath,
      imgPath: kif.imgPath,
      color: kif.color,
    ));
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

List<TabEntity> _tabs() => [
      TabEntity(id: 1, title: 'タブA', tabOrder: 0),
      TabEntity(id: 2, title: 'タブB', tabOrder: 1),
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

Future<void> _moveToNextTabAndDrop(
  WidgetTester tester,
  Finder card,
  String tabTitle,
) async {
  final gesture = await _startLongPressDrag(tester, card);
  await gesture.moveTo(tester.getCenter(find.text(tabTitle)));
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pumpAndSettle();
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

  testWidgets('グリッド: 並び替えモードに入って最初の長押しドラッグで他タブへ移動できる',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await tester.runAsync(() => AppSettings().set('homeViewMode', 'grid'));
    final kifDao = _FakeKifDao(_kifs());
    await _pumpHomePage(tester, _FakeTabDao(_tabs()), kifDao);
    expect(find.byType(KifGridItem), findsWidgets);

    final loadsBeforeSort = kifDao.getKifsByTabCallCount;
    await _enterSortMode(tester);
    expect(kifDao.getKifsByTabCallCount, loadsBeforeSort);

    await _moveToNextTabAndDrop(tester, find.text('棋譜A'), 'タブB');

    expect(kifDao.kifsByTab[1]!.any((kif) => kif.title == '棋譜A'), isFalse);
    expect(kifDao.kifsByTab[2]!.any((kif) => kif.title == '棋譜A'), isTrue);

    await tester.tap(find.text('タブB'));
    await tester.pumpAndSettle();
    expect(find.text('棋譜A'), findsOneWidget);

    await _drainSnackbar(tester);
  });

  testWidgets('リスト: 並び替えモードに入って最初の長押しドラッグで他タブへ移動できる',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await tester.runAsync(() => AppSettings().set('homeViewMode', 'list'));
    final kifDao = _FakeKifDao(_kifs());
    await _pumpHomePage(tester, _FakeTabDao(_tabs()), kifDao);
    expect(find.byType(KifListItem), findsWidgets);

    final loadsBeforeSort = kifDao.getKifsByTabCallCount;
    await _enterSortMode(tester);
    expect(kifDao.getKifsByTabCallCount, loadsBeforeSort);

    await _moveToNextTabAndDrop(tester, find.text('棋譜A'), 'タブB');

    expect(kifDao.kifsByTab[1]!.any((kif) => kif.title == '棋譜A'), isFalse);
    expect(kifDao.kifsByTab[2]!.any((kif) => kif.title == '棋譜A'), isTrue);

    await tester.tap(find.text('タブB'));
    await tester.pumpAndSettle();
    expect(find.text('棋譜A'), findsOneWidget);

    await _drainSnackbar(tester);
  });

  testWidgets('グリッド: 同一タブ内の長押しドラッグ並び替えが従来どおりできる',
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

    await _drainSnackbar(tester);
  });

  testWidgets('リスト: 同一タブ内の長押しドラッグ並び替えが従来どおりできる',
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

    await _drainSnackbar(tester);
  });
}
