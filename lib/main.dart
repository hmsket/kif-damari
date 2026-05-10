import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kifdamari/utils/ui_utils.dart';
import 'package:kifdamari/widgets/kif_list_widget.dart';
import 'database/dao/tab_dao.dart';
import 'database/entity/tab_entity.dart';
import 'utils/dialog_utils.dart';

// AppModeにsortを追加
enum AppMode { normal, edit, sort, delete }

void main() => runApp(const KifdamariApp());

class KifdamariApp extends StatelessWidget {
  const KifdamariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomePage(),
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansJpTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late Future<List<TabEntity>> _tabsFuture;
  AppMode _currentMode = AppMode.normal;
  TabController? _tabController; 
  int _currentTabIndex = 0;

  // KifListWidgetのStateにアクセスするためのGlobalKeyを保持
  final Map<int, GlobalKey<KifListWidgetState>> _listKeys = {};

  @override
  void initState() {
    super.initState();
    _loadTabs();
  }

  void _loadTabs() {
    _tabsFuture = TabDao().getAllTabs();
  }

  void _syncTabIndex() {
    if (_tabController != null) {
      _currentTabIndex = _tabController!.index;
    }
  }

  void _updateMode(AppMode mode) {
    _syncTabIndex();
    setState(() {
      _currentMode = mode;
    });
  }

  void _refresh() {
    _syncTabIndex();
    setState(() {
      _loadTabs();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TabEntity>>(
      future: _tabsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _tabController == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final tabs = snapshot.data ?? [];

        if (_tabController == null || _tabController!.length != tabs.length) {
          _tabController?.dispose();
          
          if (_currentTabIndex >= tabs.length) {
            _currentTabIndex = tabs.isEmpty ? 0 : tabs.length - 1;
          }

          _tabController = TabController(
            length: tabs.length,
            vsync: this,
            initialIndex: _currentTabIndex,
          );

          _tabController!.addListener(() {
            if (!_tabController!.indexIsChanging) {
              _currentTabIndex = _tabController!.index;
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0XFFF1F1F5),
          appBar: AppBar(
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 0, 0, 0),
              child: Image.asset(
                'assets/images/appbar_icon.png',
                fit: BoxFit.contain,
              ),
            ),
            backgroundColor: const Color(0XFFFFFFFF),
            title: Row(
              children: [
                if (_currentMode != AppMode.normal) ...[
                  _buildModeBadge(),
                ],
              ],
            ),
            actions: [
              if (_currentMode != AppMode.normal)
                IconButton(
                  icon: const Icon(Icons.check, size: 30),
                  onPressed: () async {
                    // チェックボタン押下時、並べ替えモードならDB保存を実行
                    if (_currentMode == AppMode.sort) {
                      final currentTabId = tabs[_currentTabIndex].id;
                      final state = _listKeys[currentTabId]?.currentState;
                      if (state != null) {
                        await state.saveOrder(); // KifListWidget内の一時リストを保存
                        UiUtils.showSuccessSnackBar(context, "棋譜の並び順を更新しました");
                      }
                    }
                    _updateMode(AppMode.normal);
                  },
                )
              else ...[
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add),
                  tooltip: '追加',
                  onSelected: (value) {
                    if (value == 'add_tab') {
                      showAddTabDialog(context, _refresh);
                    } else if (value == 'add_kif') {
                      showAddKifDialog(context, _currentTabIndex, _refresh);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'add_tab', child: Text('タブを追加')),
                    if (tabs.isNotEmpty)
                      const PopupMenuItem(value: 'add_kif', child: Text('棋譜を追加')),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: '編集',
                  onPressed: () => _updateMode(AppMode.edit),
                ),
                // 並べ替えプルダウンメニュー
                PopupMenuButton<String>(
                  icon: const Icon(Icons.swap_vert),
                  tooltip: '並び替え',
                  onSelected: (value) {
                    if (value == 'sort_tabs') {
                      showSortTabsDialog(context, tabs, _refresh); 
                    } else if (value == 'sort_kifs') {
                      _updateMode(AppMode.sort);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'sort_tabs', child: Text('タブを並び替え')),
                    const PopupMenuItem(value: 'sort_kifs', child: Text('棋譜を並び替え')),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: '削除',
                  onPressed: () => _updateMode(AppMode.delete),
                ),
              ]
            ],
            bottom: tabs.isEmpty
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(48.0),
                    child: ColoredBox(
                      color: const Color(0XFFFFFFFF),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: Colors.black, 
                        unselectedLabelColor: Colors.grey[600], 
                        labelStyle: GoogleFonts.notoSansJp(fontWeight: FontWeight.bold),
                        unselectedLabelStyle: GoogleFonts.notoSansJp(fontWeight: FontWeight.normal),
                        tabs: tabs.map((t) {
                          return Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_currentMode == AppMode.delete)
                                  GestureDetector(
                                    onTap: () => showDeleteTabDialog(context, t, _refresh),
                                    child: const Padding(
                                      padding: EdgeInsets.fromLTRB(0, 4, 8, 4),
                                      child: Icon(Icons.cancel, size: 20, color: Colors.red),
                                    ),
                                  ),
                                if (_currentMode == AppMode.edit)
                                  GestureDetector(
                                    onTap: () => showEditTabDialog(context, t, _refresh),
                                    child: const Padding(
                                      padding: EdgeInsets.fromLTRB(0, 4, 8, 4),
                                      child: Icon(Icons.edit, size: 20, color: Colors.green),
                                    ),
                                  ),
                                Text(t.title),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
          body: tabs.isEmpty
              ? const Center(child: Text("タブを追加してください"))
              : TabBarView(
                  controller: _tabController,
                  children: tabs.map((t) {
                    // 各タブのStateを識別するためのKeyを管理
                    final key = _listKeys.putIfAbsent(t.id!, () => GlobalKey<KifListWidgetState>());
                    return KifListWidget(
                      key: key,
                      tabId: t.id!,
                      mode: _currentMode,
                      onRefresh: _refresh,
                    );
                  }).toList(),
                ),
        );
      },
    );
  }

  Widget _buildModeBadge() { 
    String text;
    Color color;

    switch (_currentMode) {
      case AppMode.delete:
        text = '削除モード';
        color = Colors.red[600]!;
        break;
      case AppMode.edit:
        text = '編集モード';
        color = Colors.green[600]!;
        break;
      case AppMode.sort:
        text = '並び替えモード';
        color = Colors.blue[600]!;
        break;
      case AppMode.normal:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
