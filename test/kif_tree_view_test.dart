import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/models/game_node.dart';
import 'package:kifdamari/widgets/comment_bubble_icon.dart';
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

  testWidgets('画面外のノードはウィジェット化されない', (tester) async {
    final root = buildNode(0);
    GameNode current = root;
    for (int i = 1; i <= 120; i++) {
      final node = buildNode(i, moveLabel: '+7776FU');
      current.addChild(node);
      current = node;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KifTreeView(
            rootNode: root,
            currentNode: root,
            onNodeSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 画面外（下方）のノードは組み立てられていない
    expect(
      tester.widgetList(find.byType(AnimatedContainer)).length,
      lessThan(120),
    );
    expect(find.text('120手目'), findsNothing);

    // 下端までスクロールすると、その範囲のノードが遅延なく表示される
    await tester.drag(find.byType(KifTreeView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    expect(find.text('120手目'), findsOneWidget);
  });

  testWidgets('コメント付きノードには丸い吹き出しアイコンが付き、コメントなしには付かない', (tester) async {
    final root = buildNode(0);
    root.addComment('コメントあり');
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

    expect(find.byType(CommentBubbleIcon), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble), findsNothing);
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

  GameNode buildTreeWithComments() {
    final root = buildNode(0);
    root.addComment('開始局面のコメント');
    final first = buildNode(1, moveLabel: '+7776FU');
    first.addComment('コメントあり');
    root.addChild(first);
    final branch = buildNode(1, moveLabel: '+3334FU');
    branch.addPositionComment('局面メモあり');
    root.addChild(branch);
    return first;
  }

  testWidgets('showNodeIcons が false なら吹き出し・分岐アイコンは出ず×ボタンだけ残る', (tester) async {
    final current = buildTreeWithComments();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KifTreeView(
            rootNode: current.parent!,
            currentNode: current,
            showNodeIcons: false,
            onNodeSelected: (_) {},
            onNodeDeleted: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CommentBubbleIcon), findsNothing);
    expect(find.byIcon(Icons.alt_route), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNWidgets(2));
  });

  testWidgets('デフォルトでは吹き出しと分岐アイコンを表示する', (tester) async {
    final current = buildTreeWithComments();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KifTreeView(
            rootNode: current.parent!,
            currentNode: current,
            onNodeSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CommentBubbleIcon), findsNWidgets(3));
    expect(find.byIcon(Icons.alt_route), findsOneWidget);
  });

  testWidgets('統合ツリー設定でも吹き出しは従来通り表示する', (tester) async {
    final current = buildTreeWithComments();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KifTreeView(
            rootNode: current.parent!,
            currentNode: current,
            showBranchIcon: false,
            flatNodeCards: true,
            onNodeSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CommentBubbleIcon), findsNWidgets(3));
    expect(find.byIcon(Icons.alt_route), findsNothing);
  });
}
