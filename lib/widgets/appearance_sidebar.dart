import 'package:flutter/material.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/database/entity/position_appearance_entity.dart';

/// 局面の出現情報から「この局面を含む棋譜」の一覧を開くサイドバー。
/// 再生画面・統合ツリー画面のどちらでも同じ見た目・操作で再利用する。
/// ページ側の Stack に直接置く（スクリーン全体を覆う）。
class AppearanceSidebar extends StatelessWidget {
  final bool open;
  final List<PositionAppearanceEntity> appearances;
  final Map<int, KifEntity> kifById;
  final bool Function(PositionAppearanceEntity appearance) isCurrent;
  final void Function(PositionAppearanceEntity appearance) onTap;
  final VoidCallback onClose;

  const AppearanceSidebar({
    super.key,
    required this.open,
    required this.appearances,
    required this.kifById,
    required this.isCurrent,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final double sidebarWidth = MediaQuery.of(context).size.width * 0.85;

    return Stack(
      children: [
        if (open)
          Positioned.fill(
            child: GestureDetector(
              onTap: onClose,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          left: open ? 0 : -sidebarWidth,
          top: 0,
          bottom: 0,
          width: sidebarWidth,
          child: Material(
            elevation: 16,
            color: Colors.white,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '出現する棋譜',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.brown[800],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: onClose,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: appearances.isEmpty
                        ? const Center(
                            child: Text(
                              'この局面を含む棋譜はありません',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: appearances.length,
                            itemBuilder: (context, index) {
                              final appearance = appearances[index];
                              final kif = kifById[appearance.kifId];
                              final selected = isCurrent(appearance);

                              return ListTile(
                                dense: true,
                                selected: selected,
                                // 項目の境目が分かるように白と薄いグレーを交互に敷く。
                                // 選択中の項目は selectedTileColor を優先して見分けられるようにする。
                                tileColor: index.isEven
                                    ? Colors.white
                                    : Colors.grey[100],
                                selectedTileColor: Colors.orange[100],
                                title: Text(
                                  (kif?.title.isNotEmpty ?? false) ? kif!.title : '（タイトルなし）',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${appearance.moveNumber}手目',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                onTap: () => onTap(appearance),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
