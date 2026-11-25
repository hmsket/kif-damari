import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:kifdamari/logic/backup_service.dart';
import 'package:kifdamari/logic/kif_file_reader.dart';
import 'package:kifdamari/snackbars/show_error_snackbar.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

/// データの全バックアップ／復元の設定項目。
class DataBackupSetting extends StatefulWidget {
  const DataBackupSetting({super.key});

  @override
  State<DataBackupSetting> createState() => _DataBackupSettingState();
}

class _DataBackupSettingState extends State<DataBackupSetting> {
  bool _isBusy = false;

  Future<void> _createBackup() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      final bytes = await const BackupService().createBackup();
      if (!mounted) return;

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'バックアップの保存先を選択',
        fileName: _backupFileName(),
        type: FileType.any,
        bytes: bytes,
      );

      if (!mounted) return;
      if (savedPath != null && savedPath.isNotEmpty) {
        ShowSuccessSnackbar.show(context, 'バックアップを保存しました');
      }
    } catch (_) {
      if (mounted) {
        ShowErrorSnackbar.show(context, 'バックアップの作成に失敗しました');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'バックアップファイルを選択',
        type: FileType.any,
        withData: true,
      );
      if (!mounted) return;
      if (picked == null || picked.files.isEmpty) return;

      final file = picked.files.single;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await KifFileReader.readBytes(file.path!);
      }
      if (bytes == null) {
        if (mounted) {
          ShowErrorSnackbar.show(context, 'バックアップファイルを読み込めませんでした');
        }
        return;
      }

      if (!mounted) return;
      final confirmed = await _confirmRestore();
      if (!mounted || confirmed != true) return;

      final result = await const BackupService().restore(bytes);
      if (!mounted) return;
      await _showRestoreResult(result);
    } on BackupFormatException catch (e) {
      if (mounted) ShowErrorSnackbar.show(context, e.message);
    } catch (_) {
      if (mounted) {
        ShowErrorSnackbar.show(context, 'バックアップの復元に失敗しました');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<bool?> _confirmRestore() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('バックアップから復元'),
          content: const Text(
            '現在のタブ・棋譜・設定・サムネイルをすべて上書きして復元します。\n'
            'この操作は元に戻せません。よろしいですか？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                '復元する',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRestoreResult(BackupRestoreResult result) {
    final message = result.unopenableKifCount > 0
        ? '棋譜${result.restoredKifCount}件を復元しました。\n'
            'ファイルを開けない棋譜が${result.unopenableKifCount}件あります。'
        : '棋譜${result.restoredKifCount}件を復元しました。';

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('復元が完了しました'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  String _backupFileName() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'kifdamari_backup_'
        '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}.zip';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            enabled: !_isBusy,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: const Text(
              'データのバックアップ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            subtitle: const Text(
              'DB・設定・サムネイル・棋譜ファイルを1つのZIPに保存します',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            trailing: _isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: _createBackup,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            enabled: !_isBusy,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: const Text(
              'バックアップから復元',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            subtitle: const Text(
              'バックアップファイルで現在のデータを上書きします',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: _restoreBackup,
          ),
        ),
      ],
    );
  }
}
