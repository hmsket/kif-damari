import 'package:flutter/material.dart';
import 'package:kifdamari/database/dao/tab_dao.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

void showEditTabDialog(BuildContext context, TabEntity tab, VoidCallback onRefresh) {
  showDialog(
    context: context,
    barrierDismissible: false, // ダイアログ外タップで閉じないように統一
    builder: (context) => EditTabDialogContent(tab: tab, onRefresh: onRefresh),
  );
}

class EditTabDialogContent extends StatefulWidget {
  final TabEntity tab;
  final VoidCallback onRefresh;

  const EditTabDialogContent({
    super.key,
    required this.tab,
    required this.onRefresh,
  });

  @override
  State<EditTabDialogContent> createState() => _EditTabDialogContentState();
}

class _EditTabDialogContentState extends State<EditTabDialogContent> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.tab.title);
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ラベルテキストの色を取得するヘルパーメソッド
  Color _getLabelColor() {
    if (_errorMessage != null) {
      return Colors.redAccent; // エラー時は赤色
    }
    if (_focusNode.hasFocus) {
      return const Color(0xFF222222); // フォーカス時は濃い黒色
    }
    return const Color(0xFF888888); // 初期・非フォーカス時は薄いグレー
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.0), // ダイアログ角丸 28px
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // タイトル
              const Text(
                'タブ名を編集',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // 入力フィールド
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'タブ名',
                  labelStyle: TextStyle(
                    color: _getLabelColor(),
                    fontSize: 14,
                    fontWeight: (_focusNode.hasFocus || _errorMessage != null)
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  hintText: '例: 四間飛車',
                  hintStyle: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 14,
                  ),
                  errorText: _errorMessage,
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF222222), width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onChanged: (value) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
              const SizedBox(height: 28),

              // 右寄せ横並びのボタンエリア（カプセル型ボタン）
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // キャンセルボタン
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: const BorderSide(color: Color(0xFFCCCCCC), width: 1.5),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'キャンセル',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 更新ボタン
                  ElevatedButton(
                    onPressed: _updateData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF222222),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      '更新',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateData() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'タブ名を入力してください';
      });
      return;
    }

    // 変更がない場合は重複チェックを行わずにそのまま閉じる
    if (name != widget.tab.title) {
      final count = await TabDao().countTabByName(name);
      if (count > 0) {
        setState(() => _errorMessage = '同じタブ名が存在しています');
        return;
      }
    }

    final updatedTab = TabEntity(
      id: widget.tab.id,
      title: name,
      tabOrder: widget.tab.tabOrder,
    );

    await TabDao().updateTab(updatedTab);

    if (!mounted) return;
    ShowSuccessSnackbar.show(context, "タブ名を更新しました");
    Navigator.pop(context);
    widget.onRefresh();
  }
}
