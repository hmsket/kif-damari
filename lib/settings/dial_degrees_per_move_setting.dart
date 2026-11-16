import 'package:flutter/material.dart';
import 'package:kifdamari/widgets/app_settings.dart';

class DialDegreesPerMoveSetting extends StatelessWidget {
  final AppSettings settings;

  const DialDegreesPerMoveSetting({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final double currentDegrees = settings.get<double>('dialDegreesPerMove');

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text(
          'ダイヤルの回転量（1手あたり）',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
        ),
        subtitle: Text(
          '現在の回転量: ${currentDegrees.toStringAsFixed(1)}°',
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
            final double currentSliderValue = settings.get<double>('dialDegreesPerMove');

            return AlertDialog(
              title: const Text('ダイヤルの回転量の変更'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      '${currentSliderValue.toStringAsFixed(1)}°',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // シークバー
                    Slider(
                      value: currentSliderValue,
                      min: 5.0,
                      max: 45.0,
                      divisions: 40,
                      label: currentSliderValue.toStringAsFixed(1),
                      onChanged: (newValue) async {
                        await settings.set('dialDegreesPerMove', newValue);
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
