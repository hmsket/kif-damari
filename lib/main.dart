import 'package:flutter/material.dart';

void main() => runApp(const KiflabApp());

class KiflabApp extends StatelessWidget {
  const KiflabApp({super.key});

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
    // Javaの TabHost や ViewPager + TabLayout に相当するコントローラー
    return DefaultTabController(
      length: 3, // タブの数
      child: Scaffold(
        appBar: AppBar(
          title: const Text('棋譜だまり'),
          leading: const Icon(Icons.menu), // ドロワーメニュー用
          actions: [
            IconButton(icon: const Icon(Icons.add), onPressed: () {}),
            IconButton(icon: const Icon(Icons.delete), onPressed: () {}),
            IconButton(icon: const Icon(Icons.sort), onPressed: () {}),
          ],
          // AppBarの下部にタブを配置
          bottom: const TabBar(
            tabs: [
              Tab(text: '四間飛車'),
              Tab(text: '矢倉'),
              Tab(text: '中飛車'),
            ],
          ),
        ),
        // 各タブをタップした時に表示される中身
        body: const TabBarView(
          children: [
            KifListView(strategy: '四間飛車'),
            KifListView(strategy: '矢倉'),
            KifListView(strategy: '中飛車'),
          ],
        ),
      ),
    );
  }
}

// リスト部分を別Widgetに切り出し（粒度の工夫）
class KifListView extends StatelessWidget {
  final String strategy;
  const KifListView({super.key, required this.strategy});

  @override
  Widget build(BuildContext context) {
    // 本来はDB(DAO)から取得しますが、ここではダミーデータ
    final List<String> dummyData = List.generate(5, (i) => '$strategy 棋譜 ${i + 1}');

    // Javaの ListView / RecyclerView に相当
    return ListView.builder(
      itemCount: dummyData.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            // 画像のように左側に盤面（プレビュー）を入れる想定
            leading: Container(
              width: 60,
              height: 60,
              color: Colors.grey[300],
              child: const Icon(Icons.grid_on), 
            ),
            title: Text(dummyData[index]),
            subtitle: const Text('2026/03/22 対局'),
            onTap: () {
              // ここで将棋盤画面へ遷移（Intentに相当）
              print('${dummyData[index]} がタップされました');
            },
          ),
        );
      },
    );
  }
}
