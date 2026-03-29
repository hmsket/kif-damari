import 'package:flutter/material.dart';
import 'package:kifdamari/widgets/kif_list_widget.dart';
import 'database/dao/tab_dao.dart';
import 'database/entity/tab_entity.dart';
import 'utils/dialog_utils.dart';

enum AppMode { normal, edit, delete }

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<TabEntity>> _tabsFuture;
  AppMode _currentMode = AppMode.normal;

  @override
  void initState() {
    super.initState();
    _tabsFuture = TabDao().getAllTabs();
  }

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
              backgroundColor: switch(_currentMode) {
                AppMode.edit => Colors.green[300],
                AppMode.delete => Colors.red[300],
                AppMode.normal => null,
              },
              actions: [
                if (_currentMode != AppMode.normal)
                  IconButton(
                    icon: const Icon(Icons.check, size: 30),
                    onPressed: () {
                      setState(() {
                        _currentMode = AppMode.normal;
                      });
                    },
                  )
                else ...[
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add),
                    onSelected: (value) {
                      if (value == 'add_tab') {
                        showAddTabDialog(context, _refresh);
                      } else if (value == 'add_kif') {
                        showAddKifDialog(context, _refresh);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'add_tab', child: Text('タブを追加')),
                      const PopupMenuItem(value: 'add_kif', child: Text('棋譜を追加')),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      setState(() {
                        _currentMode = AppMode.edit;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _currentMode = AppMode.delete;
                      });
                    },
                  ),
                ]
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: tabs.map((t) {
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_currentMode == AppMode.delete)
                          GestureDetector(
                            onTap: () {
                              showDeleteTabDialog(context, t, _refresh);
                            },
                            // アイコンの周りに少し余白を持たせてタップしやすくする
                            child: const Padding(
                              padding: EdgeInsets.fromLTRB(0, 4, 8, 4), 
                              child: Icon(
                                Icons.cancel,
                                size: 20, 
                                color: Colors.red,
                              ),
                            ),
                          ),
                        Text(t.title),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            body: TabBarView(
              children: tabs.map((t) => KifListWidget(tabId: t.id!, mode: _currentMode, onRefresh: _refresh,)).toList(),
            ),
          ),
        );
      },
    );
  }
}
