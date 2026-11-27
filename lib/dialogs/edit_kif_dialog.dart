import 'package:flutter/material.dart';
import 'package:kifdamari/widgets/kif_form_content.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

void showEditKifDialog(BuildContext context, KifEntity kif, VoidCallback onRefresh) {
  showDialog(
    context: context,
    barrierDismissible: false, // 背景タップで閉じないように統一
    builder: (context) {
      String? errorMessage;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return KifFormContent(
            initialKif: kif,
            confirmButtonText: '更新',
            errorMessage: errorMessage,
            onErrorMessageChanged: (error) => setDialogState(() => errorMessage = error),
            onSubmit: ({required title, required detail, required kifPath, required color}) async {
              final updatedKif = KifEntity(
                id: kif.id,
                tabId: kif.tabId,
                kifId: kif.kifId,
                title: title,
                detail: detail,
                kifOrder: kif.kifOrder,
                kifPath: kifPath,
                imgPath: kif.imgPath,
                color: color,
                pendingTreeUri: kif.pendingTreeUri,
              );

              await KifDao().updateKif(updatedKif);
              if (context.mounted) {
                ShowSuccessSnackbar.show(context, "棋譜を更新しました");
                Navigator.pop(context);
                onRefresh();
              }
            },
          );
        },
      );
    },
  );
}
