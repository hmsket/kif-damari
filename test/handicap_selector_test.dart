import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/widgets/handicap_selector.dart';

void main() {
  Future<void> pumpSelector(
    WidgetTester tester, {
    String? label,
    required bool enabled,
    required ValueChanged<String> onSelected,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HandicapSelector(
          label: label,
          enabled: enabled,
          onSelected: onSelected,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('info に手合割が無い棋譜でも「平手」として表示される', (tester) async {
    await pumpSelector(
      tester,
      label: null,
      enabled: true,
      onSelected: (_) {},
    );

    expect(find.text('手合割'), findsOneWidget);
    expect(find.text('平手'), findsOneWidget);
  });

  testWidgets('タップするとプリセット一覧が開き、選ぶと選択がコールバックに渡る', (tester) async {
    String? selected;
    await pumpSelector(
      tester,
      label: null,
      enabled: true,
      onSelected: (value) => selected = value,
    );

    await tester.tap(find.byKey(const ValueKey('handicap_selector')));
    await tester.pumpAndSettle();

    expect(find.text('手合割を選択'), findsOneWidget);
    expect(find.text('平手'), findsNWidgets(2));
    expect(find.text('二枚落ち'), findsOneWidget);
    expect(find.text('十枚落ち'), findsOneWidget);

    await tester.tap(find.text('二枚落ち'));
    await tester.pumpAndSettle();

    expect(find.text('手合割を選択'), findsNothing);
    expect(selected, '二枚落ち');
  });

  testWidgets('指し手がある場合は選択できず、その旨が表示される', (tester) async {
    String? selected;
    await pumpSelector(
      tester,
      label: '平手',
      enabled: false,
      onSelected: (value) => selected = value,
    );

    expect(find.text('指し手があるため変更できません'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('handicap_selector')));
    await tester.pumpAndSettle();

    expect(find.text('手合割を選択'), findsNothing);
    expect(selected, isNull);
  });
}
