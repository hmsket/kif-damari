import 'package:flutter/material.dart';

/// コメント付き局面を表す、横長で丸い吹き出しのアイコン。
/// Material の既存アイコンに一致する形が無いため、パスで描画する。
class CommentBubbleIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CommentBubbleIcon({
    super.key,
    this.size = 10,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CommentBubblePainter(color: color),
      ),
    );
  }
}

class _CommentBubblePainter extends CustomPainter {
  final Color color;

  const _CommentBubblePainter({required this.color});

  static final Path _bubblePath = _buildBubblePath();

  static Path _buildBubblePath() {
    final Path body = Path()
      ..addRRect(
        RRect.fromLTRBR(
          1.5,
          3.5,
          22.5,
          17.0,
          const Radius.circular(7.0),
        ),
      );
    final Path tail = Path()
      ..moveTo(7.5, 13.5)
      ..lineTo(3.8, 22.5)
      ..lineTo(12.5, 16.8)
      ..close();
    return Path.combine(PathOperation.union, body, tail);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 24.0;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      _bubblePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CommentBubblePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
