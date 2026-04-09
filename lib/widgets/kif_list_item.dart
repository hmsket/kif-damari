import 'package:flutter/material.dart';
import 'package:kifdamari/utils/dialog_utils.dart';
import 'package:kifdamari/widgets/kif_item_widget.dart';
import '../database/entity/kif_entity.dart';
import '../main.dart';

class KifListItem extends StatelessWidget {
  final KifEntity kif;
  final AppMode mode;
  final VoidCallback onRefresh;

  const KifListItem({
    super.key,
    required this.kif,
    required this.mode,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Colors.grey, width: 1),
      ),
      margin: const EdgeInsets.all(1),
      child: InkWell(
        onTap: () {
          if (mode == AppMode.delete) {
            showDeleteKifDialog(context, kif, onRefresh);
          } else if (mode == AppMode.edit) {
            showEditKifDialog(context, kif, onRefresh);
          } else {
            // TODO: 将棋盤画面へ
          }
        },
        child: KifItemWidget(
          title: kif.title,
          detail: kif.detail,
          trailing: switch (mode) {
            AppMode.delete => const Icon(Icons.cancel, color: Colors.red),
            AppMode.edit => const Icon(Icons.edit, color: Colors.green),
            AppMode.normal => null,
          },
        ),
      ),
    );
  }
}
