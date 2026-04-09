import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'ui_utils.dart';
import '../database/dao/kif_dao.dart';
import '../database/dao/tab_dao.dart';
import '../database/entity/tab_entity.dart';
import '../database/entity/kif_entity.dart';
import '../widgets/kif_item_widget.dart';

void showAddTabDialog(BuildContext context, VoidCallback onRefresh) {
  final TextEditingController controller = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('タブを追加'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "タブ名"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final maxOrder = await TabDao().getMaxTabOrder();
                await TabDao().insertTab(TabEntity(
                  title: name,
                  tabOrder: maxOrder + 1,
                ));
                UiUtils.showSuccessSnackBar(context, "タブを追加しました");
                if (context.mounted) Navigator.pop(context);   
                onRefresh(); 
              }
            },
            child: const Text('追加'),
          ),
        ],
      );
    },
  );
}

Future<void> showEditTabDialog(BuildContext context, TabEntity tab, VoidCallback onRefresh) async {
  final controller = TextEditingController(text: tab.title);
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('タブ名の編集'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "タブ名"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final updatedTab = TabEntity(id: tab.id, title: controller.text, tabOrder: tab.tabOrder);
                await TabDao().updateTab(updatedTab);
                UiUtils.showSuccessSnackBar(context, "タブ名を更新しました");
                if (context.mounted) Navigator.pop(context);
                onRefresh();
              }
            },
            child: const Text('更新'),
          ),
        ],
      );
    },
  );
}

void showDeleteTabDialog(BuildContext context, TabEntity tab, VoidCallback onRefresh) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('タブを削除'),
        content: Text('「${tab.title}」を削除します。\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              await TabDao().deleteTab(tab.id!);
              UiUtils.showSuccessSnackBar(context, "タブを削除しました");
              if (context.mounted) {
                Navigator.pop(context);
                onRefresh();
              }
            },
            child: const Text('削除'),
          ),
        ],
      );
    },
  );
}

void showAddKifDialog(BuildContext context, VoidCallback onRefresh) async {
  final titleController = TextEditingController();
  final detailController = TextEditingController();
  final tabs = await TabDao().getAllTabs();
  
  int selectedTabId = tabs.isNotEmpty ? tabs.first.id! : -1;
  int selectedColor = 0xFF8FBC8F;
  String? kfilePath;
  String fileNameDisplay = "未選択";

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            title: const Text('棋譜を追加'),            
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Color(selectedColor).withOpacity(0.05),
                      border: Border.all(color: Color(selectedColor), width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: KifItemWidget(
                      title: titleController.text,
                      detail: detailController.text,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLabel('タブ'),
                          DropdownButton<int>(
                            value: selectedTabId,
                            isExpanded: true,
                            items: tabs.map((t) => DropdownMenuItem(value: t.id, child: Text(t.title))).toList(),
                            onChanged: (value) => setDialogState(() => selectedTabId = value!),
                          ),
                          _buildLabel('タイトル'),
                          TextField(
                            controller: titleController,
                            decoration: const InputDecoration(hintText: "タイトルを入力"),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          _buildLabel('詳細'),
                          TextField(
                            controller: detailController,
                            decoration: const InputDecoration(hintText: "詳細を入力"),
                            maxLines: 2,
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          _buildLabel('kifファイル'),
                          Row(
                            children: [
                              Expanded(child: Text(fileNameDisplay, style: const TextStyle(fontSize: 12))),
                              ElevatedButton(
                                onPressed: () async {
                                  FilePickerResult? result = await FilePicker.platform.pickFiles();
                                  if (result != null) {
                                    setDialogState(() {
                                      kfilePath = result.files.single.path;
                                      fileNameDisplay = result.files.single.name;
                                    });
                                  }
                                },
                                child: const Text('選択'),
                              ),
                            ],
                          ),
                          _buildLabel('色'),
                          DropdownButton<int>(
                            value: selectedColor,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 0xFF8FBC8F, child: Text("緑")),
                              DropdownMenuItem(value: 0xFFBC8F8F, child: Text("茶")),
                            ],
                            onChanged: (value) => setDialogState(() => selectedColor = value!),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: kfilePath == null ? null : () async {
                    if (kfilePath == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ファイルを選択してください')),
                      );
                      return;
                    }
                    final maxKifId = await KifDao().getMaxKifId(selectedTabId);
                    final newKif = KifEntity(
                      tabId: selectedTabId,
                      kifId: maxKifId + 1,
                      title: titleController.text,
                      detail: detailController.text,
                      kifOrder: maxKifId + 1,
                      kifPath: kfilePath!,
                      color: selectedColor,
                    );
                    await KifDao().insertKif(newKif);
                    UiUtils.showSuccessSnackBar(context, "棋譜を追加しました");
                    if (context.mounted) {
                      Navigator.pop(context);
                      onRefresh();
                    }
                },
                child: const Text('追加'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showEditKifDialog(BuildContext context, KifEntity kif, VoidCallback onRefresh) async {
  final titleController = TextEditingController(text: kif.title);
  final detailController = TextEditingController(text: kif.detail);
  final tabs = await TabDao().getAllTabs();
  
  int selectedTabId = kif.tabId;
  int? selectedColor = kif.color;
  String? kfilePath = kif.kifPath;
  String fileNameDisplay = kif.kifPath!.split('/').last;

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            title: const Text('棋譜を編集'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Color(selectedColor!).withOpacity(0.05),
                      border: Border.all(color: Color(selectedColor!), width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: KifItemWidget(
                      title: titleController.text,
                      detail: detailController.text,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLabel('タブ'),
                          DropdownButton<int>(
                            value: selectedTabId,
                            isExpanded: true,
                            items: tabs.map((t) => DropdownMenuItem(value: t.id, child: Text(t.title))).toList(),
                            onChanged: (value) => setDialogState(() => selectedTabId = value!),
                          ),
                          _buildLabel('タイトル'),
                          TextField(
                            controller: titleController,
                            decoration: const InputDecoration(hintText: "タイトルを入力"),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          _buildLabel('詳細'),
                          TextField(
                            controller: detailController,
                            decoration: const InputDecoration(hintText: "詳細を入力"),
                            maxLines: 2,
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          _buildLabel('kifファイル'),
                          Row(
                            children: [
                              Expanded(child: Text(fileNameDisplay, style: const TextStyle(fontSize: 12))),
                              ElevatedButton(
                                onPressed: () async {
                                  FilePickerResult? result = await FilePicker.platform.pickFiles();
                                  if (result != null) {
                                    setDialogState(() {
                                      kfilePath = result.files.single.path;
                                      fileNameDisplay = result.files.single.name;
                                    });
                                  }
                                },
                                child: const Text('変更'), // ラベルを「変更」に
                              ),
                            ],
                          ),
                          _buildLabel('色'),
                          DropdownButton<int>(
                            value: selectedColor,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 0xFF8FBC8F, child: Text("緑")),
                              DropdownMenuItem(value: 0xFFBC8F8F, child: Text("茶")),
                            ],
                            onChanged: (value) => setDialogState(() => selectedColor = value!),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                // ボタンのonPressed内
                onPressed: () async {
                  if (titleController.text.isNotEmpty) {
                    int finalKifId = kif.kifId;
                    int finalKifOrder = kif.kifOrder;

                    // タブが移動したかチェック
                    if (selectedTabId != kif.tabId) {
                      // 移動先のタブでの最大値を新規取得
                      final maxKifId = await KifDao().getMaxKifId(selectedTabId);
                      finalKifId = maxKifId + 1;
                      finalKifOrder = maxKifId + 1;
                    }

                    final updatedKif = KifEntity(
                      id: kif.id,
                      tabId: selectedTabId,
                      kifId: finalKifId,
                      title: titleController.text,
                      detail: detailController.text,
                      kifOrder: finalKifOrder,
                      kifPath: kfilePath,
                      color: selectedColor,
                    );

                    await KifDao().updateKif(updatedKif);
                    
                    UiUtils.showSuccessSnackBar(context, "棋譜を更新しました");
                    if (context.mounted) {
                      Navigator.pop(context);
                      onRefresh();
                    }
                  }
                },
                child: const Text('更新'),
              ),
            ],
          );
        },
      );
    },
  );
}

void showDeleteKifDialog(BuildContext context, KifEntity kif, VoidCallback onRefresh) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('棋譜を削除'),
        content: Text('「${kif.title}」を削除します。\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              await KifDao().deleteKif(kif.tabId, kif.kifId);
              UiUtils.showSuccessSnackBar(context, "棋譜を削除しました");
              if (context.mounted) {
                Navigator.pop(context);
                onRefresh();
              }
            },
            child: const Text('削除'),
          ),
        ],
      );
    },
  );
}

// ダイアログ内の見出し
Widget _buildLabel(String text) {
  return Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
    ),
  );
}
