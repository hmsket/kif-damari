import 'package:flutter/material.dart';
import 'package:kifdamari/pages/kif_viewer_page.dart';
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
      color: Color(kif.color!),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: InkWell(
        onTap: () {
          if (mode == AppMode.delete) {
            showDeleteKifDialog(context, kif, onRefresh);
          } else if (mode == AppMode.edit) {
            showEditKifDialog(context, kif, onRefresh);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KifViewerPage(kifPath: kif.kifPath),
              ),
            );
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
