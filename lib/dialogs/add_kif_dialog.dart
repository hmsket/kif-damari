import 'package:flutter/material.dart';
import 'package:kifdamari/widgets/kif_form_content.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/dao/tab_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/settings/kif_reward_setting.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';
import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/constants.dart';

void showAddKifDialog(BuildContext context, int currentTabIndex, VoidCallback onRefresh) async {
  final tabs = await TabDao().getAllTabs();
  int selectedTabId = tabs.isNotEmpty ? tabs[currentTabIndex].id! : -1;

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (context) {
      String? errorMessage;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return KifFormContent(
            tabs: tabs,
            initialTabId: selectedTabId,
            confirmButtonText: '追加',
            errorMessage: errorMessage,
            onErrorMessageChanged: (error) => setDialogState(() => errorMessage = error),
            onSubmit: ({required tabId, required title, required detail, required kifPath, required color}) async {

              final currentKifCount = await KifDao().getTotalKifCount();

              final settings = AppSettings();
              final rawLimit = settings.get('kifLimit');
              final kifLimit = (rawLimit ?? defaultKifLimit) as int;

              if (currentKifCount >= kifLimit) {
                if (context.mounted) {
                  Navigator.pop(context);
                  KifRewardSetting(settings: settings).showConfirmationDialog(context);
                }
                return;
              }

              final rawMaxKifId = await KifDao().getMaxKifId(tabId);
              final maxKifId = rawMaxKifId ?? 0; 

              final newKif = KifEntity(
                tabId: tabId,
                kifId: maxKifId + 1,
                title: title,
                detail: detail,
                kifOrder: maxKifId + 1,
                kifPath: kifPath!,
                color: color,
              );
              await KifDao().insertKif(newKif);
              ShowSuccessSnackbar.show(context, "棋譜を追加しました");
              if (context.mounted) {
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
