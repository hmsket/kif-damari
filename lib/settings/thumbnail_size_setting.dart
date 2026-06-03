import 'package:flutter/material.dart';
import 'package:kifdamari/widgets/app_settings.dart';

class ThumbnailSizeSetting extends StatelessWidget {
  final AppSettings settings;

  const ThumbnailSizeSetting({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text(
          'サムネイルの大きさ',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
        ),
        subtitle: Text(
          '現在のサイズ: ${settings.get<int>('thumbnailSize')} px',
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
            final num rawValue = settings.get('thumbnailSize');
            final double currentSliderValue = rawValue.toDouble();

            return AlertDialog(
              title: const Text('サムネイルの大きさ変更'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // プレビュー表示エリア
                    Container(
                      width: double.infinity,
                      height: 220,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0XFFF1F1F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: currentSliderValue,
                          height: currentSliderValue,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              'assets/images/initial.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // シークバー
                    Slider(
                      value: currentSliderValue,
                      min: 100.0,
                      max: 180.0,
                      divisions: 8,
                      label: currentSliderValue.toInt().toString(),
                      onChanged: (newValue) async {
                        await settings.set('thumbnailSize', newValue.toInt());
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
