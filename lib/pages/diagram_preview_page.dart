import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:kifdamari/snackbars/show_error_snackbar.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

class DiagramPreviewPage extends StatefulWidget {
  final Uint8List initialPngBytes;
  final int moveNumber;
  final String initialSenteName; 
  final String initialGoteName;  
  
  final Future<Uint8List> Function({
    required bool highlightLastMove,
    required String senteName,
    required String goteName,
  }) onUpdateDiagram;

  const DiagramPreviewPage({
    super.key,
    required this.initialPngBytes,
    required this.moveNumber,
    required this.initialSenteName, 
    required this.initialGoteName,  
    required this.onUpdateDiagram,  
  });

  @override
  State<DiagramPreviewPage> createState() => _DiagramPreviewPageState();
}

class _DiagramPreviewPageState extends State<DiagramPreviewPage> {
  bool _isSaving = false;
  bool _isGenerating = false;
  bool _highlightLastMove = true;
  bool _showPlayerNames = true;
  late Uint8List _currentPngBytes;

  late TextEditingController _senteController;
  late TextEditingController _goteController;

  @override
  void initState() {
    super.initState();
    _currentPngBytes = widget.initialPngBytes;
    _senteController = TextEditingController(text: widget.initialSenteName);
    _goteController = TextEditingController(text: widget.initialGoteName);
  }

  @override
  void dispose() {
    _senteController.dispose();
    _goteController.dispose();
    super.dispose();
  }

  Future<void> _updateImage() async {
    setState(() => _isGenerating = true);
    try {
      final targetSente = _showPlayerNames ? _senteController.text : '';
      final targetGote = _showPlayerNames ? _goteController.text : '';

      final newBytes = await widget.onUpdateDiagram(
        highlightLastMove: _highlightLastMove, 
        senteName: targetSente,
        goteName: targetGote,
      );
      if (mounted) {
        setState(() {
          _currentPngBytes = newBytes;
        });
      }
    } catch (e) {
      if (mounted) ShowErrorSnackbar.show(context, '画像の再生成に失敗しました');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

void _showEditNameDialog() {
    if (!_showPlayerNames) return;

    // ダイアログが開く前に、現在の値を再セット（念のための同期）
    _senteController.text = _senteController.text;
    _goteController.text = _goteController.text;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('対局者名の編集', style: TextStyle(fontSize: 20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              TextField(
                controller: _senteController,
                decoration: const InputDecoration(labelText: '先手名', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _goteController,
                decoration: const InputDecoration(labelText: '後手名', border: OutlineInputBorder(), isDense: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _updateImage();
              },
              child: const Text('反映する', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    try {
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) hasAccess = await Gal.requestAccess();

      if (hasAccess) {
        await Gal.putImageBytes(_currentPngBytes);
        if (mounted) ShowSuccessSnackbar.show(context, '画像を保存しました');
      } else {
        if (mounted) ShowErrorSnackbar.show(context, '保存にはストレージへのアクセス許可が必要です');
      }
    } catch (e) {
      if (mounted) ShowErrorSnackbar.show(context, '画像の保存に失敗しました');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 画面全体のサイズを取得して固定値として扱う
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    
    // システムのステータスバー（通知バー）の高さと、標準AppBarの高さ（56px）を合計
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double customAppBarHeight = statusBarHeight + 56;

    return Scaffold(
      backgroundColor: const Color(0XFFF1F1F5),
      // キーボード出現時に背後のコンテンツサイズを絶対に自動変更させない
      resizeToAvoidBottomInset: false, 
      
      // ★ポイント：ScaffoldのappBar属性は使わず、Stack内でヘッダーをピン留めします
      body: Stack(
        children: [
          
          // 1. 【最背面レイヤー】プレビュー画像エリア
          // 自作AppBarのすぐ真下（top: customAppBarHeight）から、画面高の45%のサイズで完全に固定
          Positioned(
            top: customAppBarHeight,
            left: 0,
            width: screenWidth,
            height: screenHeight * 0.45, 
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: _isGenerating
                    ? const CircularProgressIndicator()
                    : Image.memory(
                        _currentPngBytes,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          ),

// 2. 【前面レイヤー】コントロールパネルと保存ボタンを配置
          Positioned(
            top: customAppBarHeight + (screenHeight * 0.45),
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false, 
              child: Column(
                // ★ 変更点：中身をすべて画面の「最下部」に集める
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  
                  // コントロールパネル (Card)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      color: const Color(0XFFF9F9FB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 対局者名表示トグル
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('対局者名を表示する', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              value: _showPlayerNames,
                              onChanged: _isGenerating
                                  ? null
                                  : (bool value) {
                                      setState(() => _showPlayerNames = value);
                                      _updateImage(); 
                                    },
                            ),
                            const Divider(height: 1),

                            // 对局者名編集ボタン
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                '対局者名を編集する', 
                                style: TextStyle(
                                  fontWeight: FontWeight.w600, 
                                  fontSize: 15,
                                  color: _showPlayerNames ? Colors.black87 : Colors.black38,
                                ),
                              ),
                              trailing: Icon(
                                Icons.edit, 
                                size: 20,
                                color: _showPlayerNames ? Colors.black54 : Colors.black26,
                              ),
                              onTap: _showPlayerNames ? _showEditNameDialog : null,
                            ),
                            const Divider(height: 1),

                            // 最終手強調トグル
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('現在手を強調表示する', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              value: _highlightLastMove,
                              onChanged: _isGenerating
                                  ? null
                                  : (bool value) {
                                      setState(() => _highlightLastMove = value);
                                      _updateImage();
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ★ コントロールパネルと保存ボタンの間の隙間を少し空けたい場合は、ここを調整してください
                  const SizedBox(height: 8.0),

                  // 保存ボタン
                  Padding(
                    padding: const EdgeInsets.all(16.0), // ここの上部paddingが残っているので自然な隙間が生まれます
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_isSaving || _isGenerating) ? null : _saveImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                                : const Icon(Icons.download, size: 22),
                            const SizedBox(width: 4),
                            const Text('この画像を保存する', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. 【最前面レイヤー】自作固定AppBar（OSのリレイアウトによる上下ブレを完全にシャットアウト）
          Positioned(
            top: 0,
            left: 0,
            width: screenWidth,
            height: customAppBarHeight,
            child: Container(
              padding: EdgeInsets.only(top: statusBarHeight),
              color: Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
              child: NavigationToolbar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.maybePop(context),
                ),
                middle: Text(
                  widget.moveNumber == 0 ? '開始局面図' : '${widget.moveNumber}手目の局面図',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                centerMiddle: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
