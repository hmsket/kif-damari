import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/database/entity/position_appearance_entity.dart';
import 'package:kifdamari/widgets/appearance_sidebar.dart';

KifEntity kif(int id, String title) {
  return KifEntity(tabId: 1, kifId: id, title: title, kifOrder: 0);
}

PositionAppearanceEntity appearance(int kifId, int moveNumber) {
  return PositionAppearanceEntity(
    positionId: 1,
    kifId: kifId,
    moveNumber: moveNumber,
  );
}

Widget host({
  required List<PositionAppearanceEntity> appearances,
  required Map<int, KifEntity> kifById,
  bool Function(PositionAppearanceEntity appearance)? isCurrent,
  void Function(PositionAppearanceEntity appearance)? onTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: AppearanceSidebar(
        open: true,
        appearances: appearances,
        kifById: kifById,
        isCurrent: isCurrent ?? (_) => false,
        onTap: onTap ?? (_) {},
        onClose: () {},
      ),
    ),
  );
}

void main() {
  final appearances = [
    appearance(1, 1),
    appearance(2, 2),
    appearance(3, 3),
  ];
  final kifById = {
    1: kif(1, '棋譜A'),
    2: kif(2, '棋譜B'),
    3: kif(3, '棋譜C'),
  };

  testWidgets('項目ごとに背景色が白と薄いグレーで交互に変わる', (tester) async {
    await tester.pumpWidget(host(
      appearances: appearances,
      kifById: kifById,
    ));
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles.length, 3);
    expect(tiles[0].tileColor, Colors.white);
    expect(tiles[1].tileColor, Colors.grey[100]);
    expect(tiles[2].tileColor, Colors.white);
  });

  testWidgets('選択中の項目は選択色で見分けられる', (tester) async {
    await tester.pumpWidget(host(
      appearances: appearances,
      kifById: kifById,
      isCurrent: (appearance) => appearance.kifId == 2,
    ));
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles[1].selected, isTrue);
    expect(tiles[1].selectedTileColor, Colors.orange[100]);
  });

  testWidgets('項目をタップすると対応する出現情報が渡される', (tester) async {
    final tapped = <PositionAppearanceEntity>[];
    await tester.pumpWidget(host(
      appearances: appearances,
      kifById: kifById,
      onTap: tapped.add,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('棋譜B'));
    await tester.pumpAndSettle();

    expect(tapped.length, 1);
    expect(tapped.single.kifId, 2);
    expect(tapped.single.moveNumber, 2);
  });
}
