import 'package:flutter/material.dart';
import 'package:kifdamari/widgets/app_settings.dart';

class HomeViewModeSetting extends StatelessWidget {
  final AppSettings settings;

  const HomeViewModeSetting({
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
          'ホームの表示形式',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
        ),
        subtitle: Text(
          '現在: ${_label(settings.get<String>('homeViewMode'))}',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => _showSelectDialog(context),
      ),
    );
  }

  String _label(String value) => value == 'list' ? '詳細リスト' : 'グリッド';

  void _showSelectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return RadioGroup<String>(
              groupValue: settings.get<String>('homeViewMode'),
              onChanged: (value) async {
                await settings.set('homeViewMode', value);
                setDialogState(() {});
              },
              child: AlertDialog(
                title: const Text('ホームの表示形式'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      value: 'grid',
                      title: const Text('グリッド'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      value: 'list',
                      title: const Text('詳細リスト'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('閉じる'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
