import 'package:flutter/material.dart';
import 'package:kifdamari/logic/saf_helper.dart';
import 'package:kifdamari/widgets/app_settings.dart';

/// 「デフォルトの保存先」設定。
///
/// Android のフォルダ選択（SAF のツリーピッカー）でフォルダを選ぶと、
/// 以後に新規作成する棋譜はそのフォルダへ保存される。
/// 選んだ権限は永続化される。解除すると未設定（アプリ内部フォルダ）に戻る。
class DefaultSaveLocationSetting extends StatelessWidget {
  final AppSettings settings;

  const DefaultSaveLocationSetting({
    super.key,
    required this.settings,
  });

  Future<void> _pickFolder() async {
    final String? treeUri = await SafHelper.pickTree();
    if (treeUri != null && treeUri.isNotEmpty) {
      await settings.set('defaultSaveTreeUri', treeUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSet = settings.get<String>('defaultSaveTreeUri').isNotEmpty;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: const Text(
          'デフォルトの保存先',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
        ),
        subtitle: Text(
          isSet ? '選択したフォルダに新規棋譜を保存します' : '未設定（アプリ内部フォルダに保存）',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isSet
            ? TextButton(
                onPressed: () => settings.set('defaultSaveTreeUri', ''),
                child: const Text(
                  '解除',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
              )
            : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: _pickFolder,
      ),
    );
  }
}
