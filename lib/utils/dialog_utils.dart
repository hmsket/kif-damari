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

void showSortTabsDialog(BuildContext context, List<TabEntity> currentTabs, VoidCallback onRefresh) {
  // ダイアログ内で管理するための、一時的なタブリストを作成
  List<TabEntity> tempTabs = List.from(currentTabs);

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder( // ダイアログ内の状態（tempTabsの並び順）を管理
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('タブの並べ替え'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400, // 高さは適宜調整してください
              child: ReorderableListView.builder(
                itemCount: tempTabs.length,
                itemBuilder: (context, index) {
                  final tab = tempTabs[index];
                  return ListTile(
                    key: ValueKey(tab.id), // 並べ替えには一意のKeyが必須
                    leading: const Icon(Icons.drag_handle),
                    title: Text(tab.title),
                  );
                },
                onReorder: (oldIndex, newIndex) {
                  setDialogState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = tempTabs.removeAt(oldIndex);
                    tempTabs.insert(newIndex, item);
                  });
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () async {
                  // 1. DBを更新（DAOを呼び出し）
                  await TabDao().updateAllTabOrders(tempTabs);
                  UiUtils.showSuccessSnackBar(context, "タブの並び順を更新しました");

                  // 2. ダイアログを閉じる
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  
                  // 3. 親画面をリフレッシュして並び替えを反映
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
        content: Text('「${tab.title}」を削除します。\nまた、このタブに追加されている棋譜もすべて削除します。\nこの操作は取り消せません。'),
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
  String? errorMessage; // ★ 追加：エラーメッセージ用の変数

  showDialog(
    context: context,
    builder: (context) {

      // 共通のスタイル定義
      final m3InputDecoration = InputDecoration(
        border: const UnderlineInputBorder(), 
        enabledBorder: UnderlineInputBorder(),
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
                        color: Color(selectedColor), 
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 左側：画像エリア
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
                          // 右側：入力エリア
                          Expanded(
                            child: SizedBox(
                              height: 120,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                                child: Column(
                                  children: [
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
                                    Expanded(
                                      child: TextField(
                                        controller: detailController,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        maxLines: null,
                                        expands: true,
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
                      inputDecorationTheme: InputDecorationTheme(
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
                      dropdownMenuEntries: tabs.map((t) {
                        return DropdownMenuEntry<int>(
                          value: t.id!,
                          label: t.title,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // ★ 修正箇所：kif選択時の拡張子エラーチェック処理
                    InkWell(
                      // ★ onTap の中身を以下に差し替え
                      onTap: () async {
                        try {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
                          if (result != null) {
                            final file = result.files.single;
                            final fileName = file.name;

                            if (fileName.toLowerCase().endsWith('.kif')) {
                              setDialogState(() {
                                kfilePath = file.path;          // 正しいのでパスを保存
                                fileNameDisplay = fileName;    // ファイル名を表示
                                errorMessage = null;           // エラーを消す
                              });
                            } else {
                              // ★ 変更：kfilePath や fileNameDisplay は元の状態を維持する
                              setDialogState(() {
                                errorMessage = "拡張子が .kif のファイルを選択してください";
                              });
                            }
                          }
                        } catch (e) {
                          setDialogState(() {
                            errorMessage = "ファイルの取得に失敗しました";
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    DropdownMenu<int>(
                      label: const Text('色'),
                      menuHeight: 300,
                      expandedInsets: EdgeInsets.zero, 
                      inputDecorationTheme: InputDecorationTheme(
                        border: const UnderlineInputBorder(),
                      ),
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
                // ★ kfilePathがnull（未選択 or エラー時）はボタンが非活性（押せない状態）になります
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

// ★ 解決策：関数のトップレベルから async を外し、ボタンを押した瞬間のクラッシュを防ぎます
void showEditKifDialog(BuildContext context, KifEntity kif, VoidCallback onRefresh) {
  final titleController = TextEditingController(text: kif.title);
  final detailController = TextEditingController(text: kif.detail);
  
  int selectedTabId = kif.tabId;
  int selectedColor = kif.color!;
  String? kfilePath = kif.kifPath;
  
  // ★ パスの区切り文字に依存しない安全なファイル名の切り出し方法に変更
  String fileNameDisplay = Uri.parse(kif.kifPath ?? "").pathSegments.isNotEmpty
      ? Uri.parse(kif.kifPath!).pathSegments.last
      : "未選択";
      
  String? errorMessage;

  showDialog(
    context: context,
    builder: (context) {
      // ★ FutureBuilder で安全にタブ一覧を非同期取得
      return FutureBuilder<List<TabEntity>>(
        future: TabDao().getAllTabs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const AlertDialog(content: Text('データの読み込みに失敗しました'));
          }

          final tabs = snapshot.data!;

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
                            color: Color(selectedColor), 
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                              Expanded(
                                child: SizedBox(
                                  height: 120,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                                    child: Column(
                                      children: [
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
                                        Expanded(
                                          child: TextField(
                                            controller: detailController,
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            maxLines: null,
                                            expands: true,
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
                          inputDecorationTheme: const InputDecorationTheme(
                            border: UnderlineInputBorder(),
                          ),
                          menuStyle: MenuStyle(
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                          initialSelection: selectedTabId,
                          onSelected: (value) => setDialogState(() => selectedTabId = value!),
                          dropdownMenuEntries: tabs.map((t) {
                            return DropdownMenuEntry<int>(value: t.id!, label: t.title);
                          }).toList(),
                        ),

                        const SizedBox(height: 20),

                        // --- 修正箇所：エラー時も元のファイルを維持するピッカー ---
                        InkWell(
                          onTap: () async {
                            try {
                              FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
                              if (result != null) {
                                final file = result.files.single;
                                final fileName = file.name;

                                if (fileName.toLowerCase().endsWith('.kif')) {
                                  setDialogState(() {
                                    kfilePath = file.path;          // 新しい正しいパスに更新
                                    fileNameDisplay = fileName;    // 表示名も更新
                                    errorMessage = null;           // エラーをクリア
                                  });
                                } else {
                                  // ★ エラーが出ても、元の kfilePath と fileNameDisplay は一切書き換えない
                                  setDialogState(() {
                                    errorMessage = "拡張子が .kif のファイルを選択してください";
                                  });
                                }
                              }
                            } catch (e) {
                              setDialogState(() {
                                errorMessage = "ファイルの取得に失敗しました";
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'kifファイル',
                              suffixIcon: const Icon(Icons.upload_file),
                              errorText: errorMessage,
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
                          expandedInsets: EdgeInsets.zero, 
                          inputDecorationTheme: const InputDecorationTheme(
                            border: UnderlineInputBorder(),
                          ),
                          menuStyle: MenuStyle(
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    // ★ 拡張子エラーが表示されている間だけボタンを無効化（元の中身が残っていても一時停止）
                    onPressed: errorMessage != null ? null : () async {
                      if (titleController.text.isNotEmpty) {
                        int finalKifId = kif.kifId;
                        int finalKifOrder = kif.kifOrder;

                        if (selectedTabId != kif.tabId) {
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
                          imgPath: kif.imgPath,
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
                    child: const Text('更新', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
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
