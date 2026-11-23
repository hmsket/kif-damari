import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/dialogs/comment_edit_dialog.dart';

void main() {
  testWidgets('下スワイプでコメント編集シートがキャンセルとして閉じる', (tester) async {
    List<String>? result;
    bool returned = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showCommentEditDialog(context, 'old');
                returned = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('コメント編集'), findsOneWidget);

    await tester.drag(find.text('コメント編集'), const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(find.text('コメント編集'), findsNothing);
    expect(returned, isTrue);
    expect(result, isNull);
  });

  testWidgets('決定ボタンは従来どおりコメントを返す', (tester) async {
    List<String>? result;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showCommentEditDialog(context, '');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'line1\nline2');
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();

    expect(result, <String>['line1', 'line2']);
  });
}
