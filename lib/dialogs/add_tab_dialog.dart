import 'package:flutter/material.dart';
import 'package:kifdamari/database/dao/tab_dao.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

void showAddTabDialog(BuildContext context, VoidCallback onRefresh) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AddTabDialogContent(onRefresh: onRefresh),
  );
}

class AddTabDialogContent extends StatefulWidget {
  final VoidCallback onRefresh;

  const AddTabDialogContent({
    super.key,
    required this.onRefresh,
  });

  @override
  State<AddTabDialogContent> createState() => _AddTabDialogContentState();
}

class _AddTabDialogContentState extends State<AddTabDialogContent> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
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
          borderRadius: BorderRadius.circular(28.0),
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
                'タブを追加',
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
                  // エラー時・フォーカス時・通常時で色を制御
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

              // 右寄せ横並びのボタンエリア
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

                  // 追加ボタン
                  ElevatedButton(
                    onPressed: _submitData,
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
                      '追加',
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

  Future<void> _submitData() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'タブ名を入力してください';
      });
      return;
    }

    final count = await TabDao().countTabByName(name);
    if (count > 0) {
      setState(() => _errorMessage = '同じタブ名が存在しています');
      return;
    }

    final maxOrder = await TabDao().getMaxTabOrder();
    await TabDao().insertTab(TabEntity(
      title: name,
      tabOrder: maxOrder + 1,
    ));

    if (!mounted) return;
    ShowSuccessSnackbar.show(context, "タブを追加しました");
    Navigator.pop(context);
    widget.onRefresh();
  }
}
