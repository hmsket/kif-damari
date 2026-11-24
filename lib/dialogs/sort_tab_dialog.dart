import 'package:flutter/material.dart';
import 'package:kifdamari/database/dao/tab_dao.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

void showSortTabsDialog(BuildContext context, List<TabEntity> currentTabs, VoidCallback onRefresh) {
  showDialog(
    context: context,
    builder: (context) => SortTabsDialogContent(currentTabs: currentTabs, onRefresh: onRefresh),
  );
}

class SortTabsDialogContent extends StatefulWidget {
  final List<TabEntity> currentTabs;
  final VoidCallback onRefresh;

  const SortTabsDialogContent({
    super.key,
    required this.currentTabs,
    required this.onRefresh,
  });

  @override
  State<SortTabsDialogContent> createState() => _SortTabsDialogContentState();
}

class _SortTabsDialogContentState extends State<SortTabsDialogContent> {
  late List<TabEntity> tempTabs;

  @override
  void initState() {
    super.initState();
    tempTabs = List.from(widget.currentTabs);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28.0),
      ),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // タイトル
              const Text(
                'タブの並び替え',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // 並び替えリスト
              SizedBox(
                height: 380,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ReorderableListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: tempTabs.length,
                    buildDefaultDragHandles: false, // デフォルトの長押し挙動を無効化
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          return Material(
                            elevation: 4,
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFCCCCCC),
                                  width: 1,
                                ),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final tab = tempTabs[index];
                      return Container(
                        key: ValueKey(tab.id),
                        color: index.isEven
                            ? Colors.white
                            : const Color(0xFFF2F2F2),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          title: Text(
                            tab.title,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.drag_handle,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final item = tempTabs.removeAt(oldIndex);
                        tempTabs.insert(newIndex, item);
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 右寄せ横並びのボタンエリア（カプセル型ボタン）
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // キャンセルボタン
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: const BorderSide(
                        color: Color(0xFFCCCCCC),
                        width: 1.5,
                      ),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'キャンセル',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 更新ボタン
                  ElevatedButton(
                    onPressed: () => _updateTabOrders(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF222222),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      '更新',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateTabOrders(BuildContext context) async {
    await TabDao().updateAllTabOrders(tempTabs);
    if (!context.mounted) return;
    ShowSuccessSnackbar.show(context, "タブの並び順を更新しました");
    Navigator.pop(context);

    widget.onRefresh();
  }
}
