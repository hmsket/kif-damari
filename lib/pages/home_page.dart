import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/pages/kif_editor_page.dart';
import 'package:kifdamari/settings/kif_reward_setting.dart';
import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/constants.dart';
import 'package:kifdamari/widgets/home_drawer.dart';
import 'package:kifdamari/widgets/mode_badge.dart';
import 'package:kifdamari/database/dao/tab_dao.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
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

  // 現在のタブにおける選択件数を取得
  int _getSelectedCount(List<TabEntity> tabs) {
    if (tabs.isEmpty || _currentMode != AppMode.delete) return 0;
    if (_currentTabIndex >= tabs.length) return 0;
    final currentTabId = tabs[_currentTabIndex].id;
    final state = _listKeys[currentTabId]?.currentState;
    return state?.selectedCount ?? 0;
  }

  /// テンプレート文字列からタグ（{先手} 等）を置換するヘルパー関数
  String _applyTemplate(String template, Map<String, String> values) {
    String result = template;
    values.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }

  Future<void> _onAddKifPressed(BuildContext context, int tabId) async {
    final dao = KifDao();
    final settings = AppSettings();
    
    final currentKifCount = await dao.getTotalKifCount();
    final kifLimit = (settings.get('kifLimit') ?? defaultKifLimit) as int;
    if (currentKifCount >= kifLimit) {
      if (context.mounted) {
        Navigator.pop(context);
        KifRewardSetting(settings: settings).showConfirmationDialog(context);
      }
      return;
    }

    // 設定された自動フォーマットテンプレートの取得
    final String titleTemplate = settings.get<String>('kifTitle') ?? '{先手} vs {後手}';
    final String detailTemplate = settings.get<String>('kifDetail') ?? '{棋戦} / {戦型} / {対局日}';

    // 新規作成時の初期値マッピング（ファイル読み込み前のためプレースホルダー値を設定）
    final Map<String, String> defaultHeaderValues = {
      '先手': '先手',
      '後手': '後手',
      '棋戦': '棋戦未設定',
      '戦型': '戦型未設定',
      '対局日': '',
    };

    final initialTitle = _applyTemplate(titleTemplate, defaultHeaderValues);
    final initialDetail = _applyTemplate(detailTemplate, defaultHeaderValues);

    final maxKifId = await dao.getMaxKifId(tabId);
    final kif = KifEntity(
      tabId: tabId,
      kifId: maxKifId + 1,
      title: initialTitle,
      detail: initialDetail,
      kifOrder: maxKifId + 1,
      kifPath: '',
      color: colorWhite,
    );

    final insertedId = await dao.insertKif(kif);

    final createdKif = KifEntity(
      id: insertedId,
      tabId: kif.tabId,
      kifId: kif.kifId,
      title: kif.title,
      detail: kif.detail,
      kifOrder: kif.kifOrder,
      kifPath: kif.kifPath,
      color: kif.color,
    );

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KifEditorPage(
          kifEntity: createdKif,
        ),
      ),
    ).then((_) => _refresh());
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
        final selectedCount = _getSelectedCount(tabs);
        final hasSelection = selectedCount > 0;

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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 削除モードのときはキャンセルボタンを表示
                    if (_currentMode == AppMode.delete)
                      IconButton(
                        icon: const Icon(Icons.close, size: 30),
                        tooltip: 'キャンセル',
                        onPressed: () {
                          _updateMode(AppMode.normal);
                        },
                      ),
                    
                    // チェックボタン（非表示のときもレイアウト上のスペースを維持するために Opacity を利用）
                    Opacity(
                      opacity: (_currentMode != AppMode.delete || hasSelection) ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: _currentMode == AppMode.delete && !hasSelection,
                        child: IconButton(
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
                              _updateMode(AppMode.normal);
                            } else if (_currentMode == AppMode.delete) {
                              if (tabs.isNotEmpty) {
                                final currentTabId = tabs[_currentTabIndex].id;
                                final state = _listKeys[currentTabId]?.currentState;
                                if (state != null) {
                                  await state.deleteSelectedKifs();
                                }
                              }
                            } else if (_currentMode == AppMode.edit) {
                              _updateMode(AppMode.normal);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                MenuAnchor(
                  builder: (BuildContext context, MenuController controller, Widget? child) {
                    return IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: '追加',
                      onPressed: () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
                    );
                  },
                  menuChildren: [
                    MenuItemButton(
                      onPressed: () => showAddTabDialog(context, _refresh),
                      child: const Text('タブを追加'),
                    ),
                    if (tabs.isNotEmpty)
                      MenuItemButton(
                        onPressed: () => _onAddKifPressed(context, tabs[_currentTabIndex].id!),
                        child: const Text('棋譜を追加'),
                      ),
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
                        onTap: (index) {
                          if (hasSelection && index != _currentTabIndex) {
                            _tabController?.animateTo(_currentTabIndex);
                          }
                        },
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
          bottomNavigationBar: hasSelection
              ? SafeArea(
                  child: Container(
                    color: Colors.red.shade50,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '$selectedCount件選択中、他のタブには移動できません',
                          style: GoogleFonts.notoSansJp(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          body: SafeArea(
            child: tabs.isEmpty
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
                    physics: hasSelection
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    children: tabs.map((t) {
                      final key = _listKeys.putIfAbsent(t.id!, () => GlobalKey<KifListWidgetState>());
                      return KifListWidget(
                        key: key,
                        tabId: t.id!,
                        mode: _currentMode,
                        onRefresh: _refresh,
                        onAddKifPressed: () => _onAddKifPressed(context, t.id!),
                        onSelectionChanged: () {
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
          ),
        );
      },
    );
  }
}
