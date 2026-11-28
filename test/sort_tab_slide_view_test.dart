import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/widgets/sort_tab_slide_view.dart';

void main() {
  testWidgets('animateTo の途中でタブが横方向へスライドする', (tester) async {
    final controller = TabController(length: 2, vsync: const TestVSync());
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 800,
            child: SortTabSlideView(
              controller: controller,
              children: const [
                _TabPane(key: ValueKey('tab0'), color: Colors.red),
                _TabPane(key: ValueKey('tab1'), color: Colors.blue),
              ],
            ),
          ),
        ),
      ),
    ));

    expect(tester.getTopLeft(find.byKey(const ValueKey('tab0'))).dx, 0);
    expect(tester.getTopLeft(find.byKey(const ValueKey('tab1'))).dx, 400);

    controller.animateTo(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 切り替え途中では、元のタブが左へ、次のタブが右から入ってくる。
    final tab0During = tester.getTopLeft(find.byKey(const ValueKey('tab0'))).dx;
    final tab1During = tester.getTopLeft(find.byKey(const ValueKey('tab1'))).dx;
    expect(tab0During, lessThan(0));
    expect(tab1During, greaterThan(0));
    expect(tab1During, lessThan(400));

    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byKey(const ValueKey('tab0'))).dx, -400);
    expect(tester.getTopLeft(find.byKey(const ValueKey('tab1'))).dx, 0);
  });
}

class _TabPane extends StatelessWidget {
  const _TabPane({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => ColoredBox(color: color);
}
