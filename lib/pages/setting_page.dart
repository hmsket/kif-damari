import 'package:flutter/material.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _isDarkMode = false;
  double _fontSize = 14.0;
  String _defaultPlayerName = 'プレイヤー';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: const Color(0XFFF1F1F5),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle('ホーム画面'),
          _buildSettingCard(
            title: '追加できる棋譜の上限数を増やす',
            subtitle: '現在のサイズ: ${_fontSize.toInt()}',
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
              _showFontSizeDialog(context);
            },
          ),
          _buildSettingCard(
            title: 'ダークモードを有効にする',
            subtitle: 'アプリ全体の配色を暗くします',
            trailing: Switch(
              value: _isDarkMode,
              onChanged: (value) {
                setState(() {
                  _isDarkMode = value; // その場で切り替わる
                });
              },
            ),
          ),
          _buildSettingCard(
            title: 'サムネイルの大きさ',
            subtitle: '現在のサイズ: ${_fontSize.toInt()}',
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
              _showFontSizeDialog(context);
            },
          ),
          const SizedBox(height: 12),
          _buildSectionTitle('棋譜再生画面'),
          _buildSettingCard(
            title: 'デフォルトの対局者名',
            subtitle: _defaultPlayerName,
            trailing: const Icon(Icons.edit, size: 20, color: Colors.grey),
            onTap: () {
              // ここをタップした時の動きも、後から作れます
            },
          ),
          _buildSettingCard(
            title: '棋譜コメントの文字サイズを変更する',
            subtitle: _defaultPlayerName,
            trailing: const Icon(Icons.edit, size: 20, color: Colors.grey),
            onTap: () {
              // ここをタップした時の動きも、後から作れます
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          title, 
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)
        ),
        subtitle: Text(
          subtitle, 
          style: const TextStyle(color: Colors.grey, fontSize: 13)
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  // --- タップで開くシークバー＆プレビュー付きダイアログ ---
  void _showFontSizeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        // ダイアログ内のシークバーの動きとプレビューを連動させるための仕掛け
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('文字の大きさ変更'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // プレビュー表示エリア（枠線付きのグレー背景）
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0XFFF1F1F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '▲先手 △後手\nここにプレビューが表示されます。',
                      style: TextStyle(fontSize: _fontSize), // スライダーとリアルタイム連動！
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // シークバー（スライダー）
                  Slider(
                    value: _fontSize,
                    min: 12.0,
                    max: 30.0,
                    divisions: 18,
                    label: _fontSize.toInt().toString(),
                    onChanged: (newValue) {
                      // 1. 親画面の変数を変える
                      setState(() {
                        _fontSize = newValue;
                      });
                      // 2. ダイアログ自身も再描画する
                      setDialogState(() {});
                    },
                  ),
                ],
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
