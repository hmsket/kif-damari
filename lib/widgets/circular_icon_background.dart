import 'package:flutter/material.dart';

/// 盤面やカードの色の上でも視認できる、丸い白背景。
/// 枠線は付けず、薄い影で浮き出しを出す。
class CircularIconBackground extends StatelessWidget {
  final Widget child;
  final double size;

  const CircularIconBackground({
    super.key,
    required this.child,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
