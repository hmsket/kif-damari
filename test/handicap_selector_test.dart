import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/widgets/handicap_selector.dart';

void main() {
  Widget buildPickerButton({
    required String? label,
    required ValueChanged<String?> onPicked,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            key: const ValueKey('open_handicap_picker'),
            onPressed: () async {
              onPicked(await HandicapSelector.pick(context, label: label));
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  testWidgets('プリセット一覧が開き、選ぶと手合割名が返る', (tester) async {
    String? selected;
    await tester.pumpWidget(buildPickerButton(
      label: null,
      onPicked: (value) => selected = value,
    ));

    await tester.tap(find.byKey(const ValueKey('open_handicap_picker')));
    await tester.pumpAndSettle();

    expect(find.text('手合割を選択'), findsOneWidget);
    expect(find.text('平手'), findsOneWidget);
    expect(find.text('二枚落ち'), findsOneWidget);
    expect(find.text('十枚落ち'), findsOneWidget);

    await tester.tap(find.text('二枚落ち'));
    await tester.pumpAndSettle();

    expect(find.text('手合割を選択'), findsNothing);
    expect(selected, '二枚落ち');
  });

  testWidgets('現在の手合割にはチェックが付く', (tester) async {
    await tester.pumpWidget(buildPickerButton(
      label: '二枚落ち',
      onPicked: (_) {},
    ));

    await tester.tap(find.byKey(const ValueKey('open_handicap_picker')));
    await tester.pumpAndSettle();

    expect(find.text('二枚落ち'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
