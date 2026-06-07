import 'package:flutter/material.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

void showDeleteKifDialog(BuildContext context, KifEntity kif, VoidCallback onRefresh) {
  showDialog(
    context: context,
    builder: (context) => DeleteKifDialogContent(kif: kif, onRefresh: onRefresh),
  );
}

class DeleteKifDialogContent extends StatelessWidget {
  final KifEntity kif;
  final VoidCallback onRefresh;

  const DeleteKifDialogContent({
    super.key,
    required this.kif,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('棋譜を削除'),
      content: Text('「${kif.title}」を削除します。\nこの操作は取り消せません。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: () => _deleteKif(context),
          child: const Text('削除', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Future<void> _deleteKif(BuildContext context) async {
    await KifDao().deleteKif(kif.tabId, kif.kifId);
    ShowSuccessSnackbar.show(context, "棋譜を削除しました");
    if (context.mounted) {
      Navigator.pop(context);
      onRefresh();
    }
  }
}
