import 'package:flutter/material.dart';
import 'package:kifdamari/logic/handicap_presets.dart';

/// 編集画面の棋譜情報「手合割」を選択するバー。
/// [label] は info の「手合割」（無い場合は平手として表示する）。
/// [enabled] が false（指し手が入っている等）の場合は選択できず、その旨を表示する。
class HandicapSelector extends StatelessWidget {
  final String? label;
  final bool enabled;
  final ValueChanged<String> onSelected;

  const HandicapSelector({
    super.key,
    this.label,
    required this.enabled,
    required this.onSelected,
  });

  Future<void> _select(BuildContext context) async {
    final current = label ?? '平手';

    final String? selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('手合割を選択'),
          children: [
            for (final name in HandicapPresets.sfenByLabel.keys)
              SimpleDialogOption(
                key: ValueKey('handicap_option_$name'),
                onPressed: () => Navigator.of(context).pop(name),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          color: name == current
                              ? const Color(0xFF222222)
                              : Colors.black87,
                          fontWeight: name == current
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (name == current)
                      const Icon(Icons.check, size: 18, color: Color(0xFF222222)),
                  ],
                ),
              ),
          ],
        );
      },
    );

    if (selected != null) {
      onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = label ?? '平手';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        key: const ValueKey('handicap_selector'),
        onTap: enabled ? () => _select(context) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Row(
            children: [
              Text(
                '手合割',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: enabled ? Colors.black87 : Colors.grey[500],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                current,
                style: TextStyle(
                  fontSize: 13,
                  color: enabled ? Colors.black87 : Colors.grey[500],
                ),
              ),
              const SizedBox(width: 4),
              if (enabled)
                const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey)
              else
                Expanded(
                  child: Text(
                    '指し手があるため変更できません',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
