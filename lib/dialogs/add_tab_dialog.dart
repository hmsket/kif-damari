import 'package:flutter/material.dart';
import 'package:kifdamari/database/dao/tab_dao.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

void showAddTabDialog(BuildContext context, VoidCallback onRefresh) {
  showDialog(
    context: context,
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
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('タブを追加'),
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
          onPressed: _submitData,
          child: const Text(
            '追加',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
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
