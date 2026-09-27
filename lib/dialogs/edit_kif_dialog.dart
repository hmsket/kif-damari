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
    barrierDismissible: false, // 背景タップで閉じないように統一
    builder: (context) {
      return FutureBuilder<List<TabEntity>>(
        future: TabDao().getAllTabs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            // エラー表示用ダイアログも統一デザインに変更
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28.0),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'エラー',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'データの読み込みに失敗しました',
                      style: TextStyle(fontSize: 15, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Color(0xFFCCCCCC), width: 1.5),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          '閉じる',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
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
    },
  );
}
