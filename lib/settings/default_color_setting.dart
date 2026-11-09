import 'package:flutter/material.dart';

import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/constants.dart';
import 'package:kifdamari/widgets/kif_colors.dart';

class DefaultColorSetting extends StatelessWidget {
  final AppSettings settings;

  const DefaultColorSetting({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final mode = settings.get<String>('defaultKifColorMode');
    final fixedColor = settings.get<int>('defaultKifColor') ?? colorWhite;

    String subtitleText;
    switch (mode) {
      case KifColors.modeFixed:
        subtitleText = '現在の設定: 指定した色（${KifColors.colorLabel(fixedColor)}）';
      case KifColors.modeRandom:
        subtitleText = '現在の設定: ランダム';
      default:
        subtitleText = '現在の設定: 白';
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text(
          'デフォルトの色',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
        ),
        subtitle: Text(
          subtitleText,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => _showSelectDialog(context),
      ),
    );
  }

  void _showSelectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final mode = settings.get<String>('defaultKifColorMode');
            final fixedColor = settings.get<int>('defaultKifColor') ?? colorWhite;

            Widget modeTile(String value) {
              return RadioListTile<String>(
                value: value,
                groupValue: mode,
                activeColor: const Color(0xFF222222),
                title: Text(KifColors.modeLabel(value)),
                onChanged: (newValue) async {
                  if (newValue == null) return;
                  await settings.set('defaultKifColorMode', newValue);
                  setDialogState(() {});
                },
              );
            }

            return AlertDialog(
              title: const Text('デフォルトの色'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    modeTile(KifColors.modeWhite),
                    modeTile(KifColors.modeFixed),
                    modeTile(KifColors.modeRandom),
                    if (mode == KifColors.modeFixed) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: KifColors.palette.map((data) {
                          final colorVal = data['value'] as int;
                          final isSelected = colorVal == fixedColor;

                          return GestureDetector(
                            onTap: () async {
                              await settings.set('defaultKifColor', colorVal);
                              setDialogState(() {});
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Color(colorVal),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF222222) : Colors.black26,
                                  width: isSelected ? 2.5 : 0.8,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 18, color: Color(0xFF222222))
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
