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
  String? errorMessage;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('タブを追加'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: "タブ名",
                errorText: errorMessage,
              ),
              autofocus: true,
              onChanged: (value) {
                if (errorMessage != null) {
                  setState(() => errorMessage = null);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    setState(() {
                      errorMessage = 'タブ名を入力してください';
                    });
                    return;
                  }
                  final count = await TabDao().countTabByName(name);
                  if (count > 0) {
                    setState(() => errorMessage = '同じタブ名が存在しています');
                    return;
                  }
                  final maxOrder = await TabDao().getMaxTabOrder();
                  await TabDao().insertTab(TabEntity(
                    title: name,
                    tabOrder: maxOrder + 1,
                  ));
                  if (context.mounted) {
                    UiUtils.showSuccessSnackBar(context, "タブを追加しました");
                    Navigator.pop(context);
                  }
                  onRefresh();
                },
                child: const Text('追加', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showEditTabDialog(BuildContext context, TabEntity tab, VoidCallback onRefresh) async {
  final controller = TextEditingController(text: tab.title);
  String? errorMessage;
  
  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('タブ名の編集'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: "タブ名",
                errorText: errorMessage,
              ),
              autofocus: true,
              onChanged: (value) {
                if (errorMessage != null) {
                  setState(() => errorMessage = null);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    setState(() {
                      errorMessage = 'タブ名を入力してください';
                    });
                    return;
                  }
                  final count = await TabDao().countTabByName(name);
                  if (count > 0) {
                    setState(() => errorMessage = '同じタブ名が存在しています');
                    return;
                  }
                  final updatedTab = TabEntity(id: tab.id, title: controller.text, tabOrder: tab.tabOrder);
                  await TabDao().updateTab(updatedTab);
                  UiUtils.showSuccessSnackBar(context, "タブ名を更新しました");
                  if (context.mounted) Navigator.pop(context);
                  onRefresh();
                },
                child: const Text('更新', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
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

void showAddKifDialog(BuildContext context, int currentTabIndex, VoidCallback onRefresh) async {
  final titleController = TextEditingController();
  final detailController = TextEditingController();
  final tabs = await TabDao().getAllTabs();

  int selectedTabId = tabs.isNotEmpty ? tabs[currentTabIndex].id! : -1;
  int selectedColor = 0xFFFFFFFF;
  String? kfilePath;
  String fileNameDisplay = "未選択";

  showDialog(
    context: context,
    builder: (context) {

      // 共通のスタイル定義
      final m3InputDecoration = InputDecoration(
        // filled: true,
        // fillColor: Colors.grey.withOpacity(0.1),
        // 下線のみにする設定
        border: const UnderlineInputBorder(), 
        enabledBorder: UnderlineInputBorder(
          // borderSide: BorderSide(color: Colors.grey.withOpacity(0.5)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
      );

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            title: const Text('棋譜を追加'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- KifItemWidgetのレイアウトを維持した編集エリア ---
                    Container(
                      decoration: BoxDecoration(
                        // 以前の opacity(0.05) をやめて、選択された色をそのまま背景にします
                        color: Color(selectedColor), 
                        // border: Border.all(...) の行を削除します
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 左側：画像エリア（レイアウト維持用）
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.asset('assets/images/initial.png', fit: BoxFit.contain),
                              ),
                            ),
                          ),
                          // 右側：入力エリア（TextField）
                          Expanded(
                            child: SizedBox(
                              height: 120, // 左側の画像エリアと同じ高さに固定
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                                child: Column(
                                  children: [
                                    // タイトル入力
                                    TextField(
                                      controller: titleController,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      onChanged: (_) => setDialogState(() {}),
                                      decoration: InputDecoration(
                                        hintText: 'タイトルを入力',
                                        filled: true,
                                        fillColor: Colors.grey.withOpacity(0.1),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                        enabledBorder: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Colors.grey, width: 1),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // 詳細入力（残りの高さを埋める）
                                    Expanded(
                                      child: TextField(
                                        controller: detailController,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        maxLines: null, // 高さいっぱいに広げるためにnullに設定
                                        expands: true,  // 親のExpanded内でいっぱいに広がる
                                        textAlignVertical: TextAlignVertical.top,
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: InputDecoration(
                                          hintText: '詳細を入力',
                                          filled: true,
                                          fillColor: Colors.grey.withOpacity(0.1),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.all(2),
                                          enabledBorder: const UnderlineInputBorder(
                                            borderSide: BorderSide(color: Colors.grey, width: 1),
                                          ),
                                        ),
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
                    const SizedBox(height: 20),

                    DropdownMenu<int>(
                      label: const Text('タブ'),
                      expandedInsets: EdgeInsets.zero,
                      // 前回の InputDecorator とスタイルを合わせる
                      inputDecorationTheme: InputDecorationTheme(
                        // filled: true,
                        // fillColor: Colors.grey.withOpacity(0.1),
                        border: const UnderlineInputBorder(),
                      ),
                      menuStyle: MenuStyle(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),

                      initialSelection: selectedTabId,
                      onSelected: (value) => setDialogState(() => selectedTabId = value!),
                      // ↓ この dropdownMenuEntries が必須（Required）です！
                      dropdownMenuEntries: tabs.map((t) {
                        return DropdownMenuEntry<int>(
                          value: t.id!,
                          label: t.title,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    InkWell(
                      onTap: () async {
                        FilePickerResult? result = await FilePicker.platform.pickFiles();
                        if (result != null) {
                          setDialogState(() {
                            kfilePath = result.files.single.path;
                            fileNameDisplay = result.files.single.name;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'kifファイル',
                          suffixIcon: Icon(Icons.upload_file),
                        ),
                        child: Text(
                          fileNameDisplay,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    DropdownMenu<int>(
                      label: const Text('色'),
                      menuHeight: 300,
                      // 1. 横幅を他の項目（タブ・ファイル）と揃える
                      expandedInsets: EdgeInsets.zero, 
                      // 2. 下線スタイル（Filled）を適用して枠線を消す
                      inputDecorationTheme: InputDecorationTheme(
                        // filled: true,
                        // fillColor: Colors.grey.withOpacity(0.1),
                        border: const UnderlineInputBorder(),
                      ),
                      // 3. メニュー（ポップアップ）の丸みはそのまま維持
                      menuStyle: MenuStyle(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      initialSelection: selectedColor,
                      onSelected: (val) => setDialogState(() => selectedColor = val!),
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
                      ].map((data) => DropdownMenuEntry<int>(
                        value: data['value'] as int,
                        label: data['label'] as String,
                        style: MenuItemButton.styleFrom(
                          backgroundColor: Color(data['value'] as int),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),

            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold),),),
              TextButton(
                onPressed: kfilePath == null ? null : () async {
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
                child: const Text('追加', style: TextStyle(fontWeight: FontWeight.bold),),
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
  int selectedColor = kif.color!;
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- KifItemWidgetのレイアウトを維持した編集エリア ---
                    Container(
                      decoration: BoxDecoration(
                        // 以前の opacity(0.05) をやめて、選択された色をそのまま背景にします
                        color: Color(selectedColor), 
                        // border: Border.all(...) の行を削除します
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 左側：画像エリア（レイアウト維持用）
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.asset('assets/images/initial.png', fit: BoxFit.contain),
                              ),
                            ),
                          ),
                          // 右側：入力エリア（TextField）
                          Expanded(
                            child: SizedBox(
                              height: 120, // 左側の画像エリアと同じ高さに固定
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                                child: Column(
                                  children: [
                                    // タイトル入力
                                    TextField(
                                      controller: titleController,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      onChanged: (_) => setDialogState(() {}),
                                      decoration: InputDecoration(
                                        hintText: 'タイトルを入力',
                                        filled: true,
                                        fillColor: Colors.grey.withOpacity(0.1),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                        enabledBorder: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Colors.grey, width: 1),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // 詳細入力（残りの高さを埋める）
                                    Expanded(
                                      child: TextField(
                                        controller: detailController,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        maxLines: null, // 高さいっぱいに広げるためにnullに設定
                                        expands: true,  // 親のExpanded内でいっぱいに広がる
                                        textAlignVertical: TextAlignVertical.top,
                                        onChanged: (_) => setDialogState(() {}),
                                        decoration: InputDecoration(
                                          hintText: '詳細を入力',
                                          filled: true,
                                          fillColor: Colors.grey.withOpacity(0.1),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.all(2),
                                          enabledBorder: const UnderlineInputBorder(
                                            borderSide: BorderSide(color: Colors.grey, width: 1),
                                          ),
                                        ),
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
                    const SizedBox(height: 20),

                    DropdownMenu<int>(
                      label: const Text('タブ'),
                      expandedInsets: EdgeInsets.zero,
                      // 前回の InputDecorator とスタイルを合わせる
                      inputDecorationTheme: InputDecorationTheme(
                        // filled: true,
                        // fillColor: Colors.grey.withOpacity(0.1),
                        border: const UnderlineInputBorder(),
                      ),
                      menuStyle: MenuStyle(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),

                      initialSelection: selectedTabId,
                      onSelected: (value) => setDialogState(() => selectedTabId = value!),
                      // ↓ この dropdownMenuEntries が必須（Required）です！
                      dropdownMenuEntries: tabs.map((t) {
                        return DropdownMenuEntry<int>(
                          value: t.id!,
                          label: t.title,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    InkWell(
                      onTap: () async {
                        FilePickerResult? result = await FilePicker.platform.pickFiles();
                        if (result != null) {
                          setDialogState(() {
                            kfilePath = result.files.single.path;
                            fileNameDisplay = result.files.single.name;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'kifファイル',
                          suffixIcon: Icon(Icons.upload_file),
                        ),
                        child: Text(
                          fileNameDisplay,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    DropdownMenu<int>(
                      label: const Text('色'),
                      menuHeight: 300,
                      // 1. 横幅を他の項目（タブ・ファイル）と揃える
                      expandedInsets: EdgeInsets.zero, 
                      // 2. 下線スタイル（Filled）を適用して枠線を消す
                      inputDecorationTheme: InputDecorationTheme(
                        // filled: true,
                        // fillColor: Colors.grey.withOpacity(0.1),
                        border: const UnderlineInputBorder(),
                      ),
                      // 3. メニュー（ポップアップ）の丸みはそのまま維持
                      menuStyle: MenuStyle(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      initialSelection: selectedColor,
                      onSelected: (val) => setDialogState(() => selectedColor = val!),
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
                      ].map((data) => DropdownMenuEntry<int>(
                        value: data['value'] as int,
                        label: data['label'] as String,
                        style: MenuItemButton.styleFrom(
                          backgroundColor: Color(data['value'] as int),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold),),
              ),
              TextButton(
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
                child: const Text('更新', style: TextStyle(fontWeight: FontWeight.bold),),
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
