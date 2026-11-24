import 'dart:math' as math;
import 'dart:ui';

/// ダイヤルの点の中心を同一円周上に等間隔で配置するための左上座標を返す。
///
/// [center] は正方形の親の中心座標、[radius] は中心から各点の中心までの距離。
/// [index] は 0 から数えた点の番号で、0 番は真上（12 時方向）から始まる。
/// [size] は点の直径で、返される座標は点の左上の座標。
Offset dialDotPosition({
  required double center,
  required double radius,
  required int index,
  required int count,
  required double size,
}) {
  final angle = -math.pi / 2 + 2 * math.pi * index / count;
  return Offset(
    center + radius * math.cos(angle) - size / 2,
    center + radius * math.sin(angle) - size / 2,
  );
}
