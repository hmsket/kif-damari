import 'package:flutter/material.dart';
import 'database/dao/tab_dao.dart';
import 'database/dao/kif_dao.dart';
import 'database/entity/tab_entity.dart';
import 'database/entity/kif_entity.dart';

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
                    if (value == 'add_tab') _showAddTabDialog(context);
                    // ここに棋譜追加の分岐も入る
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
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: const Icon(Icons.description),
                title: Text(kif.title),
                subtitle: Text(kif.detail ?? '詳細なし'),
                onTap: () {
                  // TODO: 将棋盤画面へ
                },
              ),
            );
          },
        );
      },
    );
  }
}
