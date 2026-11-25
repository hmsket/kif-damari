import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/pages/kif_editor_page.dart';
import 'package:kifdamari/widgets/large_overlay_dial.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('kifdamari_editor_dial_test');
    Hive.init(dir.path);
    await Hive.openBox<dynamic>('settings_box');
  });

  testWidgets('編集画面に表示されたダイヤルは全マーカーが中心から等距離になる', (tester) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: KifEditorPage(
          kifEntity: KifEntity(
            id: 1,
            tabId: 1,
            kifId: 1,
            title: 'test',
            kifOrder: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final labelFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data == '0手目' &&
          widget.style?.fontSize == 11,
    );
    expect(labelFinder, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(labelFinder));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();

    expect(find.byType(LargeOverlayDial), findsOneWidget);

    final dialCenter = tester.getCenter(find.byType(LargeOverlayDial));
    final distances = <double>[
      for (var i = 0; i < LargeOverlayDial.markerCount; i++)
        (tester.getCenter(find.byKey(LargeOverlayDial.markerKey(i))) - dialCenter)
            .distance,
    ];

    expect(distances.first, greaterThan(0));
    for (final distance in distances) {
      expect(distance, closeTo(distances.first, 1e-6));
    }

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
