import 'package:flutter/material.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

void showDeleteSelectedKifsDialog(BuildContext context, int count, Future<void> Function() onDeleteConfirmed) {
  showDialog(
    context: context,
    builder: (context) => DeleteSelectedKifsDialogContent(
      count: count,
      onDeleteConfirmed: onDeleteConfirmed,
    ),
  );
}

class DeleteSelectedKifsDialogContent extends StatelessWidget {
  final int count;
  final Future<void> Function() onDeleteConfirmed;

  const DeleteSelectedKifsDialogContent({
    super.key,
    required this.count,
    required this.onDeleteConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('棋譜を削除'),
      content: Text('選択した $count件 の棋譜を削除します。\nこの操作は取り消せません。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: () async {
            await onDeleteConfirmed();
            if (context.mounted) {
              Navigator.pop(context);
              ShowSuccessSnackbar.show(context, "$count件の棋譜を削除しました");
            }
          },
          child: const Text('削除', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        ),
      ],
    );
  }
}
