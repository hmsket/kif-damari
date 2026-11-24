import 'package:flutter/material.dart';

import 'dial_dot_layout.dart';

/// 文字なし仕様の大型オーバーレイダイヤル。
///
/// 回転ポインター（黒丸）と目盛りドット（グレー）の中心が、すべて
/// [markerRadius] の同一円周上に等間隔で並ぶ。
class LargeOverlayDial extends StatelessWidget {
  const LargeOverlayDial({
    super.key,
    required this.rotation,
    this.controlKey,
  });

  /// ダイヤル本体の直径。
  static const double diameter = 120;

  /// 中心から各マーカーの中心までの距離。
  static const double markerRadius = 45;

  /// マーカーの個数（黒丸1つ＋グレー3つ）。
  static const int markerCount = 4;

  static const double _knobSize = 14;
  static const double _dotSize = 5;

  /// ダイヤルの回転角（ラジアン）。
  final double rotation;

  /// 回転操作の基準位置を取得するためのキーをダイヤル本体に付ける。
  final Key? controlKey;

  /// [index] 番目のマーカーをテストから特定するためのキー。
  static Key markerKey(int index) => ValueKey('large-overlay-dial-marker-$index');

  @override
  Widget build(BuildContext context) {
    return Container(
      key: controlKey,
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Transform.rotate(
        angle: rotation,
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final center = constraints.maxWidth / 2;
              Offset offsetOf(int index, double size) => dialDotPosition(
                    center: center,
                    radius: markerRadius,
                    index: index,
                    count: markerCount,
                    size: size,
                  );
              return Stack(
                alignment: Alignment.center,
                children: [
                  // 中心のフラットな円
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF5F5F5),
                    ),
                  ),
                  // 回転ポインター（ツマミ）
                  Positioned(
                    left: offsetOf(0, _knobSize).dx,
                    top: offsetOf(0, _knobSize).dy,
                    child: Container(
                      key: markerKey(0),
                      width: _knobSize,
                      height: _knobSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF424242),
                      ),
                    ),
                  ),
                  // 周囲の目盛りドット
                  for (var i = 1; i < markerCount; i++)
                    Positioned(
                      left: offsetOf(i, _dotSize).dx,
                      top: offsetOf(i, _dotSize).dy,
                      child: Container(
                        key: markerKey(i),
                        width: _dotSize,
                        height: _dotSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
