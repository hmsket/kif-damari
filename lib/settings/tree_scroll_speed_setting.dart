import 'package:flutter/material.dart';
import 'package:kifdamari/widgets/app_settings.dart';

class TreeScrollSpeedSetting extends StatelessWidget {
  final AppSettings settings;

  const TreeScrollSpeedSetting({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final double currentSpeed = settings.get<double>('treeScrollSpeed');

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text(
          '棋譜ツリーのスクロール速度',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
        ),
        subtitle: Text(
          '現在の倍率: ${currentSpeed.toStringAsFixed(1)}倍',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => _showSliderDialog(context),
      ),
    );
  }

  void _showSliderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double currentSliderValue = settings.get<double>('treeScrollSpeed');

            return AlertDialog(
              title: const Text('スクロール速度の変更'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      '${currentSliderValue.toStringAsFixed(1)}倍',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // シークバー
                    Slider(
                      value: currentSliderValue,
                      min: 0.5,
                      max: 3.0,
                      divisions: 5,
                      label: currentSliderValue.toStringAsFixed(1),
                      onChanged: (newValue) async {
                        await settings.set('treeScrollSpeed', newValue);
                        setDialogState(() {});
                      },
                    ),
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
