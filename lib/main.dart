import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansJpTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF1E88E5)),
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
                fit: BoxFit.contain, // 枠内に収める
              ),
            ),
            backgroundColor: const Color(0XFFFFFFFF), // 背景色は白に固定
            title: Row(
              children: [
                // const Text('棋譜だまり'),
                if (_currentMode != AppMode.normal) ...[
                  // const SizedBox(width: 8),
                  _buildModeBadge(), // モードバッジを生成するメソッド
                ],
              ],
            ),
            actions: [
              if (_currentMode != AppMode.normal)
                IconButton(
                  icon: const Icon(Icons.check, size: 30),
                  onPressed: () => _updateMode(AppMode.normal),
                )
              else ...[
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add),
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
                  onPressed: () => _updateMode(AppMode.edit),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _updateMode(AppMode.delete),
                ),
              ]
            ],
            bottom: tabs.isEmpty
                ? null
                : PreferredSize(
                  // TabBarの標準的な高さ（48.0）を指定
                  preferredSize: const Size.fromHeight(48.0),
                  child: ColoredBox(
                    color: const Color(0XFFFFFFFF), // ここにTabBar専用の背景色を指定
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      
                      // indicatorColor: const Color(0xFF1E88E5), 
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
                    return KifListWidget(
                      key: ValueKey('kif_list_${t.id}'),
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
    final isDelete = _currentMode == AppMode.delete;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        // 削除モードなら赤、編集モードなら緑（お好みで）
        color: isDelete ? Colors.red[600] : Colors.green[600],
        borderRadius: BorderRadius.circular(4), // 少し角を丸めた四角形
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isDelete ? '削除モード' : '編集モード',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
