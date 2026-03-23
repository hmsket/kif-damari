import 'package:flutter/material.dart';
import 'database/dao/tab_dao.dart';
import 'database/dao/kif_dao.dart';
import 'database/entity/tab_entity.dart';
import 'database/entity/kif_entity.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(const KifdamariApp());

class KifdamariApp extends StatelessWidget {
  const KifdamariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomePage(),
      theme: ThemeData(useMaterial3: true),
    );
  }
}

// 1. 器となるクラス
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// 2. 実体（状態とUI）を管理するクラス
class _HomePageState extends State<HomePage> {
  // Javaのメンバ変数と同じ。ここに「画面の状態」を持つ。
  late Future<List<TabEntity>> _tabsFuture;

  @override
  void initState() {
    super.initState();
    // ライフサイクルの初期化（Androidの onCreate 相当）
    _tabsFuture = TabDao().getAllTabs();
  }

  // 画面を更新するメソッド（Javaの notifyDataSetChanged 相当）
  void _refresh() {
    setState(() {
      _tabsFuture = TabDao().getAllTabs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TabEntity>>(
      future: _tabsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final tabs = snapshot.data ?? [];

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Kifdamari'),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add),
                  onSelected: (value) {
                    if (value == 'add_tab') {
                      _showAddTabDialog(context);
                    } else if (value == 'add_kif') {
                      _showAddKifDialog(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'add_tab', child: Text('タブを追加')),
                    const PopupMenuItem(value: 'add_kif', child: Text('棋譜を追加')),
                  ],
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: tabs.map((t) => Tab(text: t.title)).toList(),
              ),
            ),
            body: TabBarView(
              children: tabs.map((t) => KifListScreen(tabId: t.id!)).toList(),
            ),
          ),
        );
      },
    );
  }

  // タブ追加ダイアログを表示するメソッド
  void _showAddTabDialog(BuildContext context) {
    // Javaの EditText に相当するコントローラー
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('タブを追加'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "タブ名",
              border: UnderlineInputBorder(),
            ),
            autofocus: true, // ダイアログが開いた瞬間にキーボードを出す
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // キャンセル（ダイアログを閉じる）
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final maxOrder = await TabDao().getMaxTabOrder();
                  // 1. DBに保存
                  await TabDao().insertTab(TabEntity(
                    title: name,
                    tabOrder: maxOrder + 1,
                  ));
                  // 2. ダイアログを閉じる
                  if (context.mounted) Navigator.pop(context);
                  // 3. 親画面をリフレッシュ（setStateを呼ぶメソッド）
                  _refresh(); 
                }
              },
              child: const Text('追加'),
            ),
          ],
        );
      },
    );
  }

  void _showAddKifDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final detailController = TextEditingController();
    final tabs = await TabDao().getAllTabs();
    
    int selectedTabId = tabs.isNotEmpty ? tabs.first.id! : -1;
    int selectedColor = 0xFF8FBC8F;

    // ★ 選択されたファイル情報を保持する変数
    String? kfilePath;
    String fileNameDisplay = "未選択";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('棋譜を追加'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
// 7. 将棋盤プレビュー（画像）
                  Container(
                    width: 200, height: 200,
                    color: Colors.grey[200], // 仮のプレビュー
                    child: const Center(child: Icon(Icons.grid_3x3, size: 50, color: Colors.grey)),
                  ),
                  const SizedBox(height: 16),

                  // 8. タブ選択（DropdownButton）
                  _buildLabel('タブ'),
                  DropdownButton<int>(
                    value: selectedTabId,
                    isExpanded: true,
                    items: tabs.map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(t.title),
                    )).toList(),
                    onChanged: (value) {
                      // 9. ダイアログ内の状態を更新（重要！）
                      setDialogState(() => selectedTabId = value!);
                    },
                  ),

                  // 10. タイトル入力
                  _buildLabel('タイトル'),
                  TextField(controller: titleController, decoration: const InputDecoration(hintText: "タイトル")),

                  // 11. 詳細入力
                  _buildLabel('詳細'),
                  TextField(controller: detailController, decoration: const InputDecoration(hintText: "詳細")),
                    _buildLabel('kifファイル'),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            // ★ 選択されたファイル名を表示する
                            controller: TextEditingController(text: fileNameDisplay),
                            readOnly: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            // ★ 「選択」ボタンでピッカーを起動
                            FilePickerResult? result = await FilePicker.platform.pickFiles(
                              type: FileType.any, // または前述の通りプログラム側で.kifチェック
                            );

                            if (result != null && result.files.single.path != null) {
                              // ★ ダイアログの状態を更新して再描画
                              setDialogState(() {
                                kfilePath = result.files.single.path;
                                fileNameDisplay = result.files.single.name;
                                
                                // もしタイトルが空なら、ファイル名を自動入力してあげる（親切設計）
                                if (titleController.text.isEmpty) {
                                  titleController.text = fileNameDisplay;
                                }
                              });
                            }
                          },
                          child: const Text('選択'),
                        ),
                      ],
                    ),

                    // 15. 色選択
                    _buildLabel('色'),
                    DropdownButton<int>(
                      value: selectedColor,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 0xFF8FBC8F, child: Text("緑")),
                        DropdownMenuItem(value: 0xFFBC8F8F, child: Text("茶")),
                        // 必要に応じて増やす
                      ],
                      onChanged: (value) {
                        setDialogState(() => selectedColor = value!);
                      },
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
                  onPressed: () async {
                    // ★ 「追加」ボタンはDB保存のみに専念
                    if (kfilePath == null) {
                      // ファイルが選ばれていない時のバリデーション
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
                      kifOrder: maxKifId + 1, // maxKifIdを再利用しても問題ないはず
                      kifPath: kfilePath!,
                      color: selectedColor,
                    );

                    await KifDao().insertKif(newKif);

                    if (context.mounted) {
                      Navigator.pop(context);
                      _refresh();
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

  // 共通のラベル用Widget（Javaの TextView 相当）
  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
      ),
    );
  }
}

// 4. 棋譜リスト部分（タブごとにインスタンス化される）
class KifListScreen extends StatelessWidget {
  final int tabId;
  const KifListScreen({super.key, required this.tabId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KifEntity>>(
      future: KifDao().getKifsByTab(tabId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final kifs = snapshot.data ?? [];
        if (kifs.isEmpty) {
          return const Center(child: Text('棋譜がまだありません'));
        }

        return ListView.builder(
          itemCount: kifs.length,
          itemBuilder: (context, index) {
            final kif = kifs[index];
            return Card(
              elevation: 0,
              clipBehavior: Clip.antiAlias, // 画像の角をCardの角丸に合わせる
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Colors.grey, width: 1),
              ),
              margin: const EdgeInsets.all(1),
              
              // InkWell で包んでタップ反応を付ける（ListTileのonTapの代わり）
              child: InkWell(
                onTap: () {
                  // TODO: 将棋盤画面へ
                },
                
                // ListTile の代わりに Row を使う
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    // 1. 将棋盤画像（左側）
                    SizedBox(
                      width: 120,  // 幅を固定
                      height: 120, // ★ Cardの高さに合わせる                      
                      child: Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: Image.asset(
                          'assets/images/initial.png', // assetsのパス
                          
                          // ★重要：上下左右に途切れないようにする（画像全体を表示）
                          // Javaの ScaleType.FIT_CENTER 相当
                          // SizedBox自体の80x80から、Padding（10px x 2 = 20px）を引いた
                          // 60x60のエリア内で、最大サイズで表示されます。
                          fit: BoxFit.contain, 
                        ),
                      ),
                    ),
                    
                    // 画像とテキストの間の余白
                    // const SizedBox(width: 4),

                    // 2. テキストエリア（右側）
                    Expanded(
                      child: Padding(
                        // 右側と上下に少しパディングを入れる
                        padding: const EdgeInsets.fromLTRB(2, 8, 4, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.max, // テキストの高さに合わせる
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start, // 左寄せ
                          children: [
                            // タイトル
                            Text(
                              kif.title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1, // 1行に収める
                              overflow: TextOverflow.ellipsis, // はみ出したら '...'
                            ),
                            // const SizedBox(height: 4), // タイトルと詳細の隙間
                            // 詳細
                            Text(
                              kif.detail ?? '詳細なし',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                              maxLines: 4, // 最大4行
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
