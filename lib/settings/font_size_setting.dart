import 'package:flutter/material.dart';
import 'package:kifdamari/widgets/app_settings.dart';

class FontSizeSetting extends StatelessWidget {
  final AppSettings settings;

  const FontSizeSetting({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final int currentSize = settings.get<double>('fontSize').toInt();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text(
          '棋譜コメントの文字サイズ',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
        ),
        subtitle: Text(
          '現在のサイズ: $currentSize',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        trailing: const Icon(Icons.edit, size: 20, color: Colors.grey),
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
            final double currentSliderValue = settings.get<double>('fontSize');

            return AlertDialog(
              title: const Text('文字の大きさ変更'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 150,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0XFFF1F1F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: SingleChildScrollView(
                          child: Text(
                            '▲先手 △後手\nこの文字サイズで表示します',
                            style: TextStyle(fontSize: currentSliderValue, height: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Slider(
                      value: currentSliderValue,
                      min: 1.0,
                      max: 30.0,
                      divisions: 29,
                      label: currentSliderValue.toInt().toString(),
                      onChanged: (newValue) async {
                        await settings.set('fontSize', newValue);
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
