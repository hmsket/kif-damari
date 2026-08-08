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
    return AlertDialog(
      title: const Text('タブの並び替え'),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
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
                        color: Colors.grey.withOpacity(0.3),
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
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text(
                  tab.title,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: () => _updateTabOrders(context),
          child: const Text('更新', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Future<void> _updateTabOrders(BuildContext context) async {
    await TabDao().updateAllTabOrders(tempTabs);
    ShowSuccessSnackbar.show(context, "タブの並び順を更新しました");

    if (!context.mounted) return;
    Navigator.pop(context);

    widget.onRefresh(); 
  }
}
