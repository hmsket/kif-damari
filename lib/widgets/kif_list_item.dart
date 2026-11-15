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
    Widget? trailingWidget;
    if (mode == AppMode.edit) {
      trailingWidget = const Icon(Icons.edit, color: Colors.green);
    }

    return Card(
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
          } else if (mode == AppMode.normal) {
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
                trailing: trailingWidget,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ホームのグリッド表示用カード（ミニ盤 + 1行テキストのみ）
class KifGridItem extends StatelessWidget {
  final KifEntity kif;
  final AppMode mode;
  final VoidCallback onRefresh;

  final bool isSelected;
  final ValueChanged<bool?>? onChanged;

  const KifGridItem({
    super.key,
    required this.kif,
    required this.mode,
    required this.onRefresh,
    this.isSelected = false,
    this.onChanged,
  });

  void _handleTap(BuildContext context) {
    if (mode == AppMode.delete) {
      onChanged?.call(!isSelected);
    } else if (mode == AppMode.edit) {
      showEditKifDialog(context, kif, onRefresh);
    } else if (mode == AppMode.normal) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KifViewerPage(kifEntity: kif),
        ),
      ).then((_) => onRefresh());
    }
  }

  Widget _buildBadge() {
    if (mode == AppMode.delete) {
      return Checkbox(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        value: isSelected,
        onChanged: onChanged,
      );
    } else if (mode == AppMode.edit) {
      return const Icon(Icons.edit, color: Colors.green);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Color(kif.color!),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _handleTap(context),
        onLongPress: mode == AppMode.normal
            ? () => showKifDetailSheet(context, kif, onRefresh)
            : null,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: KifItemWidget.buildKifuImage(kif.imgPath),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    kif.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (mode == AppMode.delete)
              Positioned(
                top: 0,
                left: 0,
                child: _buildBadge(),
              ),
            if (mode == AppMode.edit)
              Positioned(
                top: 6,
                right: 6,
                child: _buildBadge(),
              ),
          ],
        ),
      ),
    );
  }
}

/// グリッドカードの長押しで棋譜の詳細を表示するボトムシート
void showKifDetailSheet(
  BuildContext context,
  KifEntity kif,
  VoidCallback onRefresh,
) {
  final detailItems = (kif.detail ?? '')
      .split('/')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '棋譜の詳細',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildSheetRow('対局者', kif.title),
              for (final item in detailItems) _buildSheetRow(null, item),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showEditKifDialog(context, kif, onRefresh);
                  },
                  icon: const Icon(Icons.edit, size: 20),
                  label: const Text('編集'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildSheetRow(String? label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ),
      ],
    ),
  );
}
