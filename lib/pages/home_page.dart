import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/logic/incoming_kif_service.dart';
import 'package:kifdamari/logic/kif_import_service.dart';
import 'package:kifdamari/logic/pending_kif_sender.dart';
import 'package:kifdamari/pages/kif_editor_page.dart';
import 'package:kifdamari/pages/kif_viewer_page.dart';
import 'package:kifdamari/settings/kif_reward_setting.dart';
import 'package:kifdamari/snackbars/show_error_snackbar.dart';
import 'package:kifdamari/widgets/app_popup_menu_style.dart';
import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/circular_icon_background.dart';
import 'package:kifdamari/widgets/constants.dart';
import 'package:kifdamari/widgets/home_drawer.dart';
import 'package:kifdamari/widgets/kif_colors.dart';
import 'package:kifdamari/widgets/mode_badge.dart';
import 'package:kifdamari/database/dao/tab_dao.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
import 'package:kifdamari/dialogs/add_tab_dialog.dart';
import 'package:kifdamari/dialogs/delete_tab_dialog.dart';
import 'package:kifdamari/dialogs/edit_tab_dialog.dart';
import 'package:kifdamari/dialogs/sort_tab_dialog.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';
import 'package:kifdamari/widgets/kif_list_widget.dart';
import 'package:kifdamari/widgets/kif_search_view.dart';

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

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _incomingKifUris = [];
  bool _isProcessingIncomingKif = false;

  @override
  void initState() {
    super.initState();
    _loadTabs();
    _sendPendingKifs();
    IncomingKifService.listen(_enqueueIncomingKifUri);
  }

  void _enqueueIncomingKifUri(String uri) {
    _incomingKifUris.add(uri);
    _processIncomingKifUris();
  }

  Future<void> _processIncomingKifUris() async {
    if (_isProcessingIncomingKif) return;
    _isProcessingIncomingKif = true;
    try {
      while (_incomingKifUris.isNotEmpty) {
        final uri = _incomingKifUris.removeAt(0);
        await _openIncomingKif(uri);
      }
    } finally {
      _isProcessingIncomingKif = false;
    }
  }

  /// 他のアプリから受け取った棋譜を現在のタブへ登録し、再生画面で開く。
  Future<void> _openIncomingKif(String uri) async {
    try {
      final tabs = await TabDao().getAllTabs();
      if (tabs.isEmpty) {
        if (mounted) ShowErrorSnackbar.show(context, '棋譜を登録するタブがありません');
        return;
      }

      final currentIndex = _tabController?.index ?? _currentTabIndex;
      final tabIndex =
          currentIndex >= 0 && currentIndex < tabs.length ? currentIndex : 0;

      final kif = await const KifImportService().importFromUri(
        uri: uri,
        tabId: tabs[tabIndex].id!,
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KifViewerPage(kifEntity: kif),
        ),
      );
      if (mounted) _refresh();
    } catch (e) {
      debugPrint('受信した棋譜ファイルの読み込みエラー: $e');
      if (mounted) ShowErrorSnackbar.show(context, '棋譜ファイルを開けませんでした');
    }
  }

  /// アプリ起動時に、オフラインで退避した「送信待ち」棋譜の自動送信を試みる。
  Future<void> _sendPendingKifs() async {
    try {
      final int sentCount = await PendingKifSender.instance.sendPendingKifs();
      if (sentCount > 0 && mounted) {
        _refresh();
      }
    } catch (e) {
      debugPrint('送信待ち棋譜の自動送信に失敗しました: $e');
    }
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

  void _openSearch() {
    _syncTabIndex();
    setState(() {
      _isSearching = true;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _clearSearch() {
    _closeSearch();
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
    final String titleTemplate = settings.get<String>('kifTitle');
    final String detailTemplate = settings.get<String>('kifDetail');

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
      color: KifColors.resolveDefaultColor(settings),
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
    ).then((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
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
        final sortCurrentTabId = tabs.isNotEmpty && _currentTabIndex < tabs.length
            ? tabs[_currentTabIndex].id
            : null;
        final sortCurrentState = _listKeys[sortCurrentTabId]?.currentState;
        final bool hasKif = sortCurrentState != null && !sortCurrentState.isKifEmpty;

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
            leading: _isSearching
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: '検索を閉じる',
                    onPressed: _closeSearch,
                  )
                : null,
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'タイトル・詳細を検索',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  )
                : Row(
                    children: [
                      if (_currentMode != AppMode.normal) ...[
                        ModeBadge(mode: _currentMode),
                      ],
                    ],
                  ),
            actions: _isSearching
                ? <Widget>[
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'クリア',
                      onPressed: _clearSearch,
                    ),
                  ]
                : <Widget>[
                if (_currentMode != AppMode.normal)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 削除モードのときはキャンセルボタンを表示
                    if (_currentMode == AppMode.delete)
                      IconButton(
                        icon: const Icon(Icons.close),
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
                          icon: Icon(
                            _currentMode == AppMode.delete
                                ? Icons.delete
                                : Icons.check,
                          ),
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
                              if (mounted) ShowSuccessSnackbar.show(context, "棋譜の並び順を更新しました");
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
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: '検索',
                  onPressed: _openSearch,
                ),
                MenuAnchor(
                  style: AppPopupMenuStyle.menuStyle,
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
                      style: AppPopupMenuStyle.itemStyle,
                      onPressed: () => showAddTabDialog(context, _refresh),
                      child: const Text('タブを追加'),
                    ),
                    if (tabs.isNotEmpty)
                      MenuItemButton(
                        style: AppPopupMenuStyle.itemStyle,
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
                MenuAnchor(
                  style: AppPopupMenuStyle.menuStyle,
                  builder: (BuildContext context, MenuController controller, Widget? child) {
                    return IconButton(
                      icon: const Icon(Icons.swap_vert),
                      tooltip: '並び替え',
                      onPressed: tabs.isNotEmpty
                          ? () {
                              if (controller.isOpen) {
                                controller.close();
                              } else {
                                controller.open();
                              }
                            }
                          : null,
                    );
                  },
                  menuChildren: [
                    MenuItemButton(
                      style: AppPopupMenuStyle.itemStyle,
                      onPressed: () => showSortTabsDialog(context, tabs, _refresh),
                      child: const Text('タブを並び替え'),
                    ),
                    if (hasKif)
                      MenuItemButton(
                        style: AppPopupMenuStyle.itemStyle,
                        onPressed: () {
                          final currentTabId = tabs[_currentTabIndex].id;
                          final state = _listKeys[currentTabId]?.currentState;
                          if (state == null || state.isKifEmpty) return;
                          _updateMode(AppMode.sort);
                        },
                        child: const Text('棋譜を並び替え'),
                      ),
                  ],
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
            bottom: (_isSearching || tabs.isEmpty)
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
                                      child: CircularIconBackground(
                                        size: 28,
                                        child: Icon(Icons.cancel, size: 20, color: Colors.red),
                                      ),
                                    ),
                                  ),
                                if (_currentMode == AppMode.edit)
                                  GestureDetector(
                                    onTap: () => showEditTabDialog(context, t, _refresh),
                                    child: const Padding(
                                      padding: EdgeInsets.fromLTRB(0, 4, 8, 4),
                                      child: CircularIconBackground(
                                        size: 28,
                                        child: Icon(Icons.edit, size: 20, color: Colors.green),
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
                  ),
          ),
          bottomNavigationBar: hasSelection && !_isSearching
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
            child: Stack(
              children: [
                // 検索中もタブ表示を保持して、閉じたときに
                // 元のタブ・スクロール位置へ戻れるようにする。
                Offstage(
                  offstage: _isSearching,
                  child: tabs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 40.0),
                            child: OutlinedButton.icon(
                              onPressed: () => showAddTabDialog(context, _refresh),
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text(
                                'タブを追加する',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                side: BorderSide(
                                  color: Colors.grey.shade400,
                                ),
                                elevation: 0,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
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
                if (_isSearching)
                  Positioned.fill(
                    child: KifSearchView(query: _searchQuery),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
