import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:kifdamari/snackbars/show_error_snackbar.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

class DiagramPreviewPage extends StatefulWidget {
  final Uint8List pngBytes;
  final int moveNumber;

  const DiagramPreviewPage({
    super.key,
    required this.pngBytes,
    required this.moveNumber,
  });

  @override
  State<DiagramPreviewPage> createState() => _DiagramPreviewPageState();
}

class _DiagramPreviewPageState extends State<DiagramPreviewPage> {
  bool _isSaving = false;
  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    try {
      // 保存権限があるかチェック
      bool hasAccess = await Gal.hasAccess();
      
      // 権限がなければ、ユーザーに許可を求めるダイアログを表示
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }

      // 許可が得られた場合のみ保存を実行
      if (hasAccess) {
        await Gal.putImageBytes(widget.pngBytes);
        if (mounted) {
          ShowSuccessSnackbar.show(context, '画像を保存しました');
        }
      } else {
        // ユーザーが拒否した場合
        if (mounted) {
          ShowErrorSnackbar.show(context, '保存にはストレージへのアクセス許可が必要です');
        }
      }
    } catch (e) {
      if (mounted) {
        ShowErrorSnackbar.show(context, '画像の保存に失敗しました');
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFFF1F1F5),
      appBar: AppBar(
        title: Text(
          widget.moveNumber == 0 ? '開始局面図' : '${widget.moveNumber}手目の局面図',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 上半分：プレビュー画像
            Expanded(
              child: Center(
                child: Image.memory(
                  widget.pngBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // 下半分：保存ボタン
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black54,
                              ),
                            )
                          : const Icon(Icons.download, size: 22),
                      const SizedBox(width: 4),
                      Text(
                        'この画像を保存する',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
