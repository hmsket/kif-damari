import 'package:flutter/material.dart';
import 'package:kifdamari/logic/handicap_presets.dart';

/// 手合割プリセット一覧を表示して選択させるピッカー。
class HandicapSelector {
  const HandicapSelector._();

  /// [label] は現在の手合割（無い場合は平手として扱う）。
  /// 選択された手合割名を返し、キャンセルされた場合は null を返す。
  static Future<String?> pick(BuildContext context, {String? label}) {
    final current = label ?? '平手';

    return showDialog<String>(
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
  }
}
