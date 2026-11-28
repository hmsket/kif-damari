import 'package:flutter/material.dart';

/// 並び替えドラッグ中に使うタブ表示。
///
/// [TabController] のアニメーション値に合わせて、全タブを横方向へ
/// スライドさせながら切り替える。`IndexedStack` と同じく全タブを
/// レイアウトしたまま保持するため、ドラッグ元タブのジオメトリを
/// 失わずにカードを掴んだままタブをまたげる。
class SortTabSlideView extends StatelessWidget {
  const SortTabSlideView({
    super.key,
    required this.controller,
    required this.children,
  });

  final TabController controller;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final animation = controller.animation;
    // アニメーションが無い場合は従来どおりの即時切り替えにフォールバックする。
    if (animation == null) {
      return IndexedStack(
        index: controller.index,
        sizing: StackFit.expand,
        children: children,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return ClipRect(
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final position = animation.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  for (var i = 0; i < children.length; i++)
                    Positioned.fill(
                      child: Transform.translate(
                        // 現在位置より右のタブは右側から、左のタブは左側から入る。
                        offset: Offset((i - position) * width, 0),
                        child: children[i],
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
