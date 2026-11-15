import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/pages/home_page.dart';
import 'package:kifdamari/widgets/kif_list_item.dart';

KifEntity _kif({required String? pendingTreeUri}) {
  return KifEntity(
    id: 1,
    tabId: 1,
    kifId: 1,
    title: 'テスト棋譜',
    kifOrder: 1,
    kifPath: '/app/Kifdamari/1000.kif',
    pendingTreeUri: pendingTreeUri,
  );
}

void main() {
  setUpAll(() async {
    Hive.init(Directory.systemTemp.createTempSync('kifdamari_badge_test').path);
    await Hive.openBox('settings_box');
  });

  Future<void> pumpItem(WidgetTester tester, KifEntity kif) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: KifListItem(
          kif: kif,
          mode: AppMode.normal,
          onRefresh: () {},
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('送信待ちの棋譜カードには送信待ちの印が出る', (tester) async {
    await pumpItem(tester, _kif(pendingTreeUri: 'content://tree/drive'));

    expect(find.text('送信待ち'), findsOneWidget);
  });

  testWidgets('通常の棋譜カードには送信待ちの印は出ない', (tester) async {
    await pumpItem(tester, _kif(pendingTreeUri: null));

    expect(find.text('送信待ち'), findsNothing);
  });
}
