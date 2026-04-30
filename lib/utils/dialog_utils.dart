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
            child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold),),
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
            child: const Text('追加', style: TextStyle(fontWeight: FontWeight.bold),),
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
  int selectedColor = 0XFFFFFFFF;
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
                          DropdownMenu<int>(
                            menuHeight: 300,
                            menuStyle: MenuStyle(
                              padding: WidgetStateProperty.all(EdgeInsets.zero),
                            ),
                            initialSelection: selectedColor,
                            // 横幅を親いっぱいに広げたい場合はここを調整
                            width: MediaQuery.of(context).size.width * 0.8, 
                            label: const Text("Select Color"),
                            // 入力欄の見た目設定
                            inputDecorationTheme: const InputDecorationTheme(
                              filled: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16),
                              border: UnderlineInputBorder(),
                            ),
                            onSelected: (int? value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedColor = value;
                                });
                              }
                            },
                            dropdownMenuEntries: [
                              {'value': 0xFFFFFFFF, 'label': 'white'},
                              {'value': 0xFFF7D6D3, 'label': 'red'},
                              {'value': 0xFFFFE6C7, 'label': 'orange'},
                              {'value': 0xFFFFF6CC, 'label': 'yellow'},
                              {'value': 0xFFE6F5D6, 'label': 'green'},
                              {'value': 0xFFDFF5EE, 'label': 'teal'},
                              {'value': 0xFFE3F1F8, 'label': 'blue'},
                              {'value': 0xFFE0E9FB, 'label': 'dark_blue'},
                              {'value': 0xFFE9DDF8, 'label': 'violet'},
                              {'value': 0xFFF9DDEA, 'label': 'pink'},
                              {'value': 0xFFEEE4D6, 'label': 'brown'},
                              {'value': 0xFFEFF1F4, 'label': 'gray'},
                            ].map((data) {
                              final int colorValue = data['value'] as int;
                              final String colorLabel = data['label'] as String;

                              return DropdownMenuEntry<int>(
                                value: colorValue,
                                label: colorLabel,
                                // 💡 メニュー内の各アイテムの背景色と文字色を設定
                                style: MenuItemButton.styleFrom(
                                  backgroundColor: Color(colorValue),
                                  foregroundColor: colorValue == 0xFFFFFFFF ? Colors.black : Colors.black87,
                                ),
                              );
                            }).toList(),
                          )
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
                            items: [
                              DropdownMenuItem<int>(value: 0xFFFFFFFF, child: Text("white")),
                              DropdownMenuItem<int>(value: 0xFFF7D6D3, child: Text("red")),
                              DropdownMenuItem<int>(value: 0xFFFFE6C7, child: Text("orange")),
                              DropdownMenuItem<int>(value: 0xFFFFF6CC, child: Text("yellow")),
                              DropdownMenuItem<int>(value: 0xFFE6F5D6, child: Text("green")),
                              DropdownMenuItem<int>(value: 0xFFDFF5EE, child: Text("teal")),
                              DropdownMenuItem<int>(value: 0xFFE3F1F8, child: Text("blue")),
                              DropdownMenuItem<int>(value: 0xFFE0E9FB, child: Text("dark_blue")),
                              DropdownMenuItem<int>(value: 0xFFE9DDF8, child: Text("violet")),
                              DropdownMenuItem<int>(value: 0xFFF9DDEA, child: Text("pink")),
                              DropdownMenuItem<int>(value: 0xFFEEE4D6, child: Text("brown")),
                              DropdownMenuItem<int>(value: 0xFFEFF1F4, child: Text("gray")),
                            ],
                            onChanged: (int? value) {
                              if (value != null) {
                                setDialogState(() => selectedColor = value);
                              }
                            },
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
