import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/widgets/dial_dot_layout.dart';

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

    Offset dotCenter(Offset topLeft) =>
        topLeft + const Offset(size / 2, size / 2);

    test('全ての点の中心が同じ半径の円周上にある', () {
      for (final position in positions) {
        final relative = dotCenter(position) - const Offset(center, center);
        expect(
          math.sqrt(relative.dx * relative.dx + relative.dy * relative.dy),
          closeTo(radius, 1e-9),
        );
      }
    });

    test('点が等間隔（90度ずつ）に並ぶ', () {
      final angles = positions
          .map((position) {
            final relative = dotCenter(position) - const Offset(center, center);
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
      final top = dotCenter(positions.first);
      expect(top.dx, closeTo(center, 1e-9));
      expect(top.dy, lessThan(center));
    });
  });
}
