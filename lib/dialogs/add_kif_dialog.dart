import 'package:flutter/material.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/dao/tab_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/pages/kif_editor_page.dart';
import 'package:kifdamari/settings/kif_reward_setting.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';
import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/constants.dart';

void showAddKifDialog(BuildContext context, int currentTabIndex, VoidCallback onRefresh) {
  showDialog(
    context: context,
    builder: (context) => AddKifDialogContent(
      currentTabIndex: currentTabIndex, 
      onRefresh: onRefresh,
    ),
  );
}

class AddKifDialogContent extends StatefulWidget {
  final int currentTabIndex;
  final VoidCallback onRefresh;

  const AddKifDialogContent({
    super.key,
    required this.currentTabIndex,
    required this.onRefresh,
  });

  @override
  State<AddKifDialogContent> createState() => _AddKifDialogContentState();
}

class _AddKifDialogContentState extends State<AddKifDialogContent> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _pathController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tabs = await TabDao().getAllTabs();
      int selectedTabId = tabs.isNotEmpty ? tabs[widget.currentTabIndex].id! : -1;

      final currentKifCount = await KifDao().getTotalKifCount();
      final settings = AppSettings();
      final rawLimit = settings.get('kifLimit');
      final kifLimit = (rawLimit ?? defaultKifLimit) as int;

      if (currentKifCount >= kifLimit) {
        if (mounted) {
          Navigator.pop(context);
          KifRewardSetting(settings: settings).showConfirmationDialog(context);
        }
        return;
      }

      final rawMaxKifId = await KifDao().getMaxKifId(selectedTabId);
      final maxKifId = rawMaxKifId ?? 0;

      final newKif = KifEntity(
        tabId: selectedTabId,
        kifId: maxKifId + 1,
        title: _titleController.text.trim(),
        detail: '',
        kifOrder: maxKifId + 1,
        kifPath: _pathController.text.trim(),
        color: 0xFFFFFFFF,
      );

      await KifDao().insertKif(newKif);

      if (mounted) {
        ShowSuccessSnackbar.show(context, "棋譜を追加しました");
        
        Navigator.pop(context);
        
        widget.onRefresh();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => KifEditorPage(kifEntity: newKif),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = '保存中にエラーが発生しました';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: const Text('棋譜を作成'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _titleController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'ファイル名を入力',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'ファイル名を入力してください';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        TextButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('作成', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
