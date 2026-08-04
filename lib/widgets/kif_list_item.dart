import 'package:flutter/material.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/dialogs/edit_kif_dialog.dart';
import 'package:kifdamari/pages/home_page.dart';
import 'package:kifdamari/pages/kif_viewer_page.dart';
import 'package:kifdamari/widgets/kif_item_widget.dart';

class KifListItem extends StatelessWidget {
  final KifEntity kif;
  final AppMode mode;
  final VoidCallback onRefresh;
  final int? index;
  
  final bool isSelected;
  final ValueChanged<bool?>? onChanged;

  const KifListItem({
    super.key,
    required this.kif,
    required this.mode,
    required this.onRefresh,
    this.index,
    this.isSelected = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidget = Card(
      color: Color(kif.color!),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: InkWell(
        onTap: () {
          if (mode == AppMode.delete) {
            if (onChanged != null) {
              onChanged!(!isSelected);
            }
          } else if (mode == AppMode.edit) {
            showEditKifDialog(context, kif, onRefresh);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KifViewerPage(kifEntity: kif),
              ),
            ).then((_) => onRefresh());
          }
        },
        child: Row(
          children: [
            if (mode == AppMode.delete)
              Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: SizedBox(
                  width: 10,
                  child: Checkbox(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: isSelected,
                    onChanged: onChanged,
                  ),
                ),
              ),
            Expanded(
              child: KifItemWidget(
                title: kif.title,
                detail: kif.detail,
                imgPath: kif.imgPath,
                trailing: switch (mode) {
                  AppMode.delete => null,
                  AppMode.edit => const Icon(Icons.edit, color: Colors.green),
                  AppMode.sort => const Icon(Icons.drag_handle, color: Colors.grey),
                  AppMode.normal => null,
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (mode == AppMode.sort && index != null) {
      return ReorderableDragStartListener(
        index: index!,
        child: cardWidget,
      );
    }
    return cardWidget;
  }
}
