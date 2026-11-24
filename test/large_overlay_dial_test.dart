import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/widgets/large_overlay_dial.dart';

void main() {
  group('LargeOverlayDial', () {
    Future<void> pumpDial(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LargeOverlayDial(rotation: 0),
            ),
          ),
        ),
      );
    }

    testWidgets('黒丸とグレーの点の中心が同一円周上に並ぶ', (tester) async {
      await pumpDial(tester);

      final dialCenter = tester.getCenter(find.byType(LargeOverlayDial));
      for (var i = 0; i < LargeOverlayDial.markerCount; i++) {
        final markerCenter = tester.getCenter(
          find.byKey(LargeOverlayDial.markerKey(i)),
        );
        expect(
          (markerCenter - dialCenter).distance,
          closeTo(LargeOverlayDial.markerRadius, 1e-6),
        );
      }
    });
  });
}
