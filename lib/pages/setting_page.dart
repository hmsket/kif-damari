import 'package:flutter/material.dart';
import 'package:kifdamari/settings/thumbnail_size_setting.dart';
import 'package:kifdamari/widgets/app_settings.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings();

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: const Color(0XFFF1F1F5),
      body: ValueListenableBuilder(
        valueListenable: settings.listenable,
        builder: (context, box, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSectionTitle('ホーム画面'),
              
              _buildSettingCard(
                title: '追加できる棋譜の上限数を増やす',
                subtitle: '現在の設定: ${settings.get<double>('fontSize').toInt()}',
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                },
              ),

              ThumbnailSizeSetting(settings: settings),

              const SizedBox(height: 12),

              _buildSectionTitle('棋譜再生画面'),
              
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
    );
  }

  Widget _buildSettingCard({required String title, required String subtitle, required Widget trailing, VoidCallback? onTap}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
