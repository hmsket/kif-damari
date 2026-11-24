import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/widgets/dial_dot_layout.dart';
import 'package:kifdamari/widgets/large_overlay_dial.dart';

void main() {
  group('dialDotPosition ダイヤルの点の配置', () {
    const center = 59.0;
    const radius = 45.0;
    const size = 5.0;
    const count = 4;

    final positions = List.generate(
      count,
      (index) => dialDotPosition(
        center: center,
        radius: radius,
        index: index,
        count: count,
        size: size,
      ),
    );

    Offset dotCenter(Offset topLeft, double dotSize) =>
        topLeft + Offset(dotSize / 2, dotSize / 2);

    double distanceFromCenter(Offset point) => math.sqrt(
          math.pow(point.dx - center, 2) + math.pow(point.dy - center, 2),
        );

    test('全ての点の中心が同じ半径の円周上にある', () {
      for (final position in positions) {
        expect(
          distanceFromCenter(dotCenter(position, size)),
          closeTo(radius, 1e-9),
        );
      }
    });

    test('大きさが違う点でも中心は同じ半径の円周上にある（選択中の黒点を含む）', () {
      const knobSize = 14.0;
      const dotSize = 5.0;
      const sizes = <double>[knobSize, dotSize, dotSize, dotSize];

      final centers = <Offset>[
        for (var index = 0; index < sizes.length; index++)
          dotCenter(
            dialDotPosition(
              center: center,
              radius: radius,
              index: index,
              count: sizes.length,
              size: sizes[index],
            ),
            sizes[index],
          ),
      ];

      final distances = centers.map(distanceFromCenter).toList();
      for (final distance in distances) {
        expect(distance, closeTo(radius, 1e-9));
      }
      for (final distance in distances.skip(1)) {
        expect(distance, closeTo(distances.first, 1e-9));
      }
    });

    test('点が等間隔（90度ずつ）に並ぶ', () {
      final angles = positions
          .map((position) {
            final relative =
                dotCenter(position, size) - const Offset(center, center);
            return math.atan2(relative.dy, relative.dx);
          })
          .toList();

      for (var i = 1; i < count; i++) {
        var difference = angles[i] - angles[i - 1];
        if (difference < 0) difference += 2 * math.pi;
        expect(difference, closeTo(2 * math.pi / count, 1e-9));
      }
    });

    test('0番目の点は真上に配置される', () {
      final top = dotCenter(positions.first, size);
      expect(top.dx, closeTo(center, 1e-9));
      expect(top.dy, lessThan(center));
    });
  });

  group('LargeOverlayDial の点の配置', () {
    testWidgets('選択中の黒点を含む全点の中心がダイヤル中心から等距離になる',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LargeOverlayDial(rotation: 0),
            ),
          ),
        ),
      );

      final dialCenter = tester.getCenter(find.byType(LargeOverlayDial));
      final distances = <double>[
        for (var index = 0; index < LargeOverlayDial.markerCount; index++)
          (tester.getCenter(find.byKey(LargeOverlayDial.markerKey(index))) -
                  dialCenter)
              .distance,
      ];

      for (final distance in distances) {
        expect(distance, closeTo(LargeOverlayDial.markerRadius, 1e-6));
      }
      for (final distance in distances.skip(1)) {
        expect(distance, closeTo(distances.first, 1e-6));
      }
    });
  });
}
