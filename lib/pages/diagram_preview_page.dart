import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:kifdamari/snackbars/show_error_snackbar.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

class DiagramPreviewPage extends StatefulWidget {
  final Uint8List initialPngBytes;
  final int moveNumber;
  final Future<Uint8List> Function(bool highlightLastMove) onToggleHighlight;

  const DiagramPreviewPage({
    super.key,
    required this.initialPngBytes,
    required this.moveNumber,
    required this.onToggleHighlight,
  });

  @override
  State<DiagramPreviewPage> createState() => _DiagramPreviewPageState();
}

class _DiagramPreviewPageState extends State<DiagramPreviewPage> {
  bool _isSaving = false;
  bool _isGenerating = false;
  bool _highlightLastMove = true;
  late Uint8List _currentPngBytes;

  @override
  void initState() {
    super.initState();
    _currentPngBytes = widget.initialPngBytes;
  }

  Future<void> _updateImage(bool newValue) async {
    setState(() {
      _highlightLastMove = newValue;
      _isGenerating = true;
    });

    try {
      final newBytes = await widget.onToggleHighlight(newValue);
      setState(() {
        _currentPngBytes = newBytes;
      });
    } catch (e) {
      if (mounted) {
        ShowErrorSnackbar.show(context, '画像の再生成に失敗しました');
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    try {
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }

      if (hasAccess) {
        await Gal.putImageBytes(_currentPngBytes);
        if (mounted) {
          ShowSuccessSnackbar.show(context, '画像を保存しました');
        }
      } else {
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
                child: _isGenerating
                    ? const CircularProgressIndicator()
                    : Image.memory(
                        _currentPngBytes,
                        fit: BoxFit.contain,
                      ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: const Text(
                    '最終手を強調表示する',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  value: _highlightLastMove,
                  onChanged: _isGenerating ? null : (bool value) => _updateImage(value),
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
                  onPressed: (_isSaving || _isGenerating) ? null : _saveImage,
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
