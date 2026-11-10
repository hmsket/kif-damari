import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/models/game_node.dart';
import 'package:kifdamari/widgets/kif_tree_view.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('kifdamari_test_hive');
    Hive.init(dir.path);
    await Hive.openBox<dynamic>('settings_box');
  });

  GameNode buildNode(int moveNumber, {String? moveLabel}) {
    return GameNode(
      moveNumber: moveNumber,
      state: BoardState.initial(),
      moveLabel: moveLabel,
    );
  }

  testWidgets('削除コールバックがあれば、開始局面以外のノードに×ボタンが付く', (tester) async {
    final root = buildNode(0);
    final child = buildNode(1, moveLabel: '+7776FU');
    root.addChild(child);
    final grandChild = buildNode(2, moveLabel: '+3334FU');
    child.addChild(grandChild);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KifTreeView(
            rootNode: root,
            currentNode: child,
            onNodeSelected: (_) {},
            onNodeDeleted: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 根（開始局面）には×が付かず、子・孫にだけ付く
    expect(find.byIcon(Icons.cancel), findsNWidgets(2));
  });

  testWidgets('×をタップすると削除対象のノードでコールバックが呼ばれる', (tester) async {
    final root = buildNode(0);
    final child = buildNode(1, moveLabel: '+7776FU');
    root.addChild(child);

    GameNode? deleted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KifTreeView(
            rootNode: root,
            currentNode: child,
            onNodeSelected: (_) {},
            onNodeDeleted: (node) => deleted = node,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cancel), findsOneWidget);
    await tester.tap(find.byIcon(Icons.cancel));
    expect(deleted, same(child));
  });

  testWidgets('削除コールバックがなければ（閲覧モード）×ボタンは出ない', (tester) async {
    final root = buildNode(0);
    final child = buildNode(1, moveLabel: '+7776FU');
    root.addChild(child);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KifTreeView(
            rootNode: root,
            currentNode: child,
            onNodeSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cancel), findsNothing);
  });
}
