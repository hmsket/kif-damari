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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. まずDBから全てのタブを取得する
    return FutureBuilder<List<TabEntity>>(
      future: TabDao().getAllTabs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final tabs = snapshot.data ?? [];

        // 2. タブの数に合わせてコントローラーを自動設定
        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Kifdamari'),
              bottom: TabBar(
                tabAlignment: TabAlignment.start,
                isScrollable: true, // タブが多い場合に横スクロール可能に
                tabs: tabs.map((t) => Tab(text: t.title)).toList(),
              ),
            ),
            body: TabBarView(
              // 3. 各タブに対応するリストを表示
              children: tabs.map((t) => KifListScreen(tabId: t.id!)).toList(),
            ),
          ),
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
