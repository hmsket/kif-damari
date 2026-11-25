import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/pages/home_page.dart';
import 'package:kifdamari/widgets/kif_list_item.dart';

KifEntity _kif() {
  return KifEntity(
    id: 1,
    tabId: 1,
    kifId: 1,
    title: 'テスト棋譜',
    kifOrder: 1,
    kifPath: '/app/Kifdamari/1000.kif',
    color: 0xFFFFFFFF,
  );
}

void main() {
  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('kifdamari_delete_badge_test').path);
    await Hive.openBox('settings_box');
  });

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: child),
    ));
    await tester.pump();
  }

  testWidgets('削除モードの詳細リストはチェックボックスで選択状態を表示する', (tester) async {
    await pumpWidget(
      tester,
      KifListItem(
        kif: _kif(),
        mode: AppMode.delete,
        onRefresh: () {},
        isSelected: true,
        onChanged: (_) {},
      ),
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    await pumpWidget(
      tester,
      KifListItem(
        kif: _kif(),
        mode: AppMode.delete,
        onRefresh: () {},
        isSelected: false,
        onChanged: (_) {},
      ),
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });

  testWidgets('削除モードのグリッドはチェックボックスで選択状態を表示する', (tester) async {
    await pumpWidget(
      tester,
      KifGridItem(
        kif: _kif(),
        mode: AppMode.delete,
        onRefresh: () {},
        isSelected: true,
        onChanged: (_) {},
      ),
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    await pumpWidget(
      tester,
      KifGridItem(
        kif: _kif(),
        mode: AppMode.delete,
        onRefresh: () {},
        isSelected: false,
        onChanged: (_) {},
      ),
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });
}
