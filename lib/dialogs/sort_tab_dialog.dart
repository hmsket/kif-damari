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
      title: const Text('タブの並べ替え'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ReorderableListView.builder(
          itemCount: tempTabs.length,
          itemBuilder: (context, index) {
            final tab = tempTabs[index];
            return ListTile(
              key: ValueKey(tab.id),
              leading: const Icon(Icons.drag_handle),
              title: Text(tab.title),
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
