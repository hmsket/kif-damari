import 'package:flutter/material.dart';
import 'package:kifdamari/widgets/kif_form_content.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/dao/tab_dao.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

void showEditKifDialog(BuildContext context, KifEntity kif, VoidCallback onRefresh) {
  showDialog(
    context: context,
    builder: (context) {
      return FutureBuilder<List<TabEntity>>(
        future: TabDao().getAllTabs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const AlertDialog(content: Text('データの読み込みに失敗しました'));
          }

          final tabs = snapshot.data!;
          String? errorMessage;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return KifFormContent(
                initialKif: kif,
                tabs: tabs,
                initialTabId: kif.tabId,
                confirmButtonText: '更新',
                errorMessage: errorMessage,
                onErrorMessageChanged: (error) => setDialogState(() => errorMessage = error),
                onSubmit: ({required tabId, required title, required detail, required kifPath, required color}) async {
                  int finalKifId = kif.kifId;
                  int finalKifOrder = kif.kifOrder;

                  if (tabId != kif.tabId) {
                    final maxKifId = await KifDao().getMaxKifId(tabId);
                    finalKifId = maxKifId + 1;
                    finalKifOrder = maxKifId + 1;
                  }

                  final updatedKif = KifEntity(
                    id: kif.id,
                    tabId: tabId,
                    kifId: finalKifId,
                    title: title,
                    detail: detail,
                    kifOrder: finalKifOrder,
                    kifPath: kifPath,
                    imgPath: kif.imgPath,
                    color: color,
                  );

                  await KifDao().updateKif(updatedKif);
                  ShowSuccessSnackbar.show(context, "棋譜を更新しました");
                  if (context.mounted) {
                    Navigator.pop(context);
                    onRefresh();
                  }
                }
              );
            },
          );
        },
      );
    },
  );
}
