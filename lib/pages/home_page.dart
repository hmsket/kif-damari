import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kifdamari/widgets/home_drawer.dart';
import 'package:kifdamari/widgets/mode_badge.dart';
import 'package:kifdamari/database/dao/tab_dao.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
import 'package:kifdamari/dialogs/add_kif_dialog.dart';
import 'package:kifdamari/dialogs/add_tab_dialog.dart';
import 'package:kifdamari/dialogs/delete_tab_dialog.dart';
import 'package:kifdamari/dialogs/edit_tab_dialog.dart';
import 'package:kifdamari/dialogs/sort_tab_dialog.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';
import 'package:kifdamari/widgets/kif_list_widget.dart';

enum AppMode { normal, edit, sort, delete }

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

    _tabsFuture.then((tabs) {
      if (tabs.isNotEmpty && _currentTabIndex < tabs.length) {
        final currentTabId = tabs[_currentTabIndex].id;
        final currentState = _listKeys[currentTabId]?.currentState;
        if (currentState != null) {
          currentState.refreshFromParent();
        }
      }
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
              setState(() {
                _currentTabIndex = _tabController!.index;
              });
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0XFFF1F1F5),
          drawer: const HomeDrawer(),
          appBar: AppBar(
            backgroundColor: const Color(0XFFFFFFFF),
            title: Row(
              children: [
                if (_currentMode != AppMode.normal) ...[
                  ModeBadge(mode: _currentMode),
                ],
              ],
            ),
            actions: [
              if (_currentMode != AppMode.normal)
                IconButton(
                  icon: const Icon(Icons.check, size: 30),
                  onPressed: () async {
                    if (_currentMode == AppMode.sort) {
                      if (tabs.isEmpty) {
                        _updateMode(AppMode.normal);
                        return;
                      }
                      final currentTabId = tabs[_currentTabIndex].id;
                      final state = _listKeys[currentTabId]?.currentState;
                      
                      if (state == null || state.isKifEmpty) {
                        _updateMode(AppMode.normal);
                        return;
                      }
                      
                      await state.saveOrder();
                      ShowSuccessSnackbar.show(context, "棋譜の並び順を更新しました");
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
                  onPressed: tabs.isNotEmpty 
                      ? () => _updateMode(AppMode.edit) 
                      : null,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.swap_vert),
                  tooltip: '並び替え',
                  enabled: tabs.isNotEmpty,
                  onSelected: (value) {
                    if (value == 'sort_tabs') {
                      showSortTabsDialog(context, tabs, _refresh); 
                    } else if (value == 'sort_kifs') {
                      final currentTabId = tabs[_currentTabIndex].id;
                      final state = _listKeys[currentTabId]?.currentState;
                      if (state == null || state.isKifEmpty) return;
                      _updateMode(AppMode.sort);
                    }
                  },
                  itemBuilder: (context) {
                    final currentTabId = tabs.isNotEmpty ? tabs[_currentTabIndex].id : null;
                    final state = _listKeys[currentTabId]?.currentState;
                    final bool hasKif = state != null && !state.isKifEmpty;
                    return [
                      const PopupMenuItem(value: 'sort_tabs', child: Text('タブを並び替え')),                      
                      if (hasKif)
                        const PopupMenuItem(value: 'sort_kifs', child: Text('棋譜を並び替え')),
                    ];
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: '削除',
                  onPressed: tabs.isNotEmpty 
                      ? () => _updateMode(AppMode.delete) 
                      : null,
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
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 40.0), 
                    child: Text(
                      "タブがありません\n＋ボタンから追加してください",
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: tabs.map((t) {
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
}
