import 'package:flutter/material.dart';
import 'package:kifdamari/database/dao/tab_dao.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

void showEditTabDialog(BuildContext context, TabEntity tab, VoidCallback onRefresh) {
  showDialog(
    context: context,
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.tab.title);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('タブ名の編集'),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: "タブ名",
          errorText: _errorMessage,
        ),
        autofocus: true,
        onChanged: (value) {
          if (_errorMessage != null) {
            setState(() => _errorMessage = null);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'キャンセル',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(
          onPressed: _updateData,
          child: const Text(
            '更新',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
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

    final count = await TabDao().countTabByName(name);
    if (count > 0) {
      setState(() => _errorMessage = '同じタブ名が存在しています');
      return;
    }

    final updatedTab = TabEntity(
      id: widget.tab.id,
      title: _controller.text,
      tabOrder: widget.tab.tabOrder,
    );

    await TabDao().updateTab(updatedTab);

    if (!mounted) return;
    ShowSuccessSnackbar.show(context, "タブ名を更新しました");
    Navigator.pop(context);
    widget.onRefresh();
  }
}
