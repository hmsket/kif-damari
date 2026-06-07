import 'package:flutter/material.dart';
import 'package:kifdamari/database/dao/tab_dao.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

void showDeleteTabDialog(BuildContext context, TabEntity tab, VoidCallback onRefresh) {
  showDialog(
    context: context,
    builder: (context) => DeleteTabDialogContent(tab: tab, onRefresh: onRefresh),
  );
}

class DeleteTabDialogContent extends StatelessWidget {
  final TabEntity tab;
  final VoidCallback onRefresh;

  const DeleteTabDialogContent({
    super.key,
    required this.tab,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('タブを削除'),
      content: Text('「${tab.title}」を削除します。\nまた、このタブに追加されている棋譜もすべて削除します。\nこの操作は取り消せません。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: () => _deleteTab(context),
          child: const Text('削除', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Future<void> _deleteTab(BuildContext context) async {
    await TabDao().deleteTab(tab.id!);
    ShowSuccessSnackbar.show(context, "タブを削除しました");
    if (context.mounted) {
      Navigator.pop(context);
      onRefresh();
    }
  }
}
