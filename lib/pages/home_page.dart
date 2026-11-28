import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/logic/backup_service.dart';
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
  /// テストから差し替えられるタブ DAO。
  final TabDao? tabDao;

  /// テストから差し替えられる棋譜 DAO。
  final KifDao? kifDao;

  /// テストでフォント取得を避けるためのフラグ。
  final bool useGoogleFonts;

  const HomePage({
    super.key,
    this.tabDao,
    this.kifDao,
    this.useGoogleFonts = true,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  TabDao get _tabDao => widget.tabDao ?? TabDao();
  KifDao get _kifDao => widget.kifDao ?? KifDao();

  late Future<List<TabEntity>> _tabsFuture;
  AppMode _currentMode = AppMode.normal;
  TabController? _tabController; 
  int _currentTabIndex = 0;

  final Map<int, GlobalKey<KifListWidgetState>> _listKeys = {};
  final GlobalKey _listAreaKey = GlobalKey();

  static const double _edgeZoneWidth = 56.0;
  static const Duration _edgeInitialDelay = Duration(milliseconds: 500);
  static const Duration _edgeRepeatInterval = Duration(milliseconds: 700);

  bool _isSortDragging = false;
  bool _sortTabSwitched = false;
  int _edgeDirection = 0;
  Timer? _edgeSwitchTimer;

  /// ドラッグ元のタブ ID（端ゾーンで切り替えた後も保持する）。
  int? _sortSourceTabId;

  /// 現在表示しているタブ ID（外部ドラッグの挿入表示先の判定に使う）。
  int? _activeTabId;

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
    BackupService.restoreRevision.addListener(_onRestoreCompleted);
  }

  /// バックアップからの復元でDBが置き換わった際に、画面を丸ごと読み直す。
  void _onRestoreCompleted() {
    if (!mounted) return;
    final oldController = _tabController;
    _tabController = null;
    _listKeys.clear();
    _isSortDragging = false;
    _sortTabSwitched = false;
    _sortSourceTabId = null;
    _activeTabId = null;
    _cancelEdgeTimer();
    setState(() {
      _currentTabIndex = 0;
      _loadTabs();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldController?.dispose();
    });
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
      final tabs = await _tabDao.getAllTabs();
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
    _tabsFuture = _tabDao.getAllTabs();
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

  Widget _buildKifList(TabEntity tab, List<TabEntity> tabs) {
    final key = _listKeys.putIfAbsent(
      tab.id!,
      () => GlobalKey<KifListWidgetState>(),
    );
    return KifListWidget(
      key: key,
      tabId: tab.id!,
      mode: _currentMode,
      onRefresh: _refresh,
      onAddKifPressed: () => _onAddKifPressed(context, tab.id!),
      kifDao: widget.kifDao,
      onSelectionChanged: () {
        setState(() {});
      },
      onSortDragStart: _handleSortDragStart,
      onSortDragUpdate: _handleSortDragUpdate,
      onSortDragEnd: (kif, globalPosition) =>
          _handleSortDragEnd(kif, globalPosition, tabs),
    );
  }

  // 現在のタブにおける選択件数を取得
  int _getSelectedCount(List<TabEntity> tabs) {
    if (tabs.isEmpty || _currentMode != AppMode.delete) return 0;
    if (_currentTabIndex >= tabs.length) return 0;
    final currentTabId = tabs[_currentTabIndex].id;
    final state = _listKeys[currentTabId]?.currentState;
    return state?.selectedCount ?? 0;
  }

  void _cancelEdgeTimer() {
    _edgeSwitchTimer?.cancel();
    _edgeSwitchTimer = null;
  }

  void _handleSortDragStart(int tabId) {
    if (_currentMode != AppMode.sort || _isSortDragging) return;
    _cancelEdgeTimer();
    _edgeDirection = 0;
    _sortTabSwitched = false;
    _sortSourceTabId = tabId;
    _clearExternalSortInsertion();
    setState(() {
      _isSortDragging = true;
    });
  }

  /// 現在のタブ以外の一覧に残っている、外部ドラッグの挿入表示を消す。
  void _clearExternalSortInsertion() {
    for (final key in _listKeys.values) {
      key.currentState?.clearExternalInsertion();
    }
  }

  /// 別タブへ切り替えた後のドラッグ位置を、表示中の一覧へ伝えて
  /// 挿入位置の隙間を出させる。ドラッグ元の一覧では通常の
  /// Reorderable のフィードバックに任せる。
  void _updateExternalSortInsertion(Offset globalPosition) {
    final sourceTabId = _sortSourceTabId;
    final activeTabId = _activeTabId;
    if (sourceTabId == null ||
        activeTabId == null ||
        activeTabId == sourceTabId) {
      _clearExternalSortInsertion();
      return;
    }
    for (final entry in _listKeys.entries) {
      final state = entry.value.currentState;
      if (state == null) continue;
      if (entry.key == activeTabId) {
        state.updateExternalInsertion(globalPosition);
      } else {
        state.clearExternalInsertion();
      }
    }
  }

  /// ドラッグ中のポインタ位置から、一覧の左右端ゾーンに留まっているかを
  /// 判定し、タブ切り替えのタイマーを制御する。
  void _handleSortDragUpdate(Offset globalPosition) {
    if (_currentMode != AppMode.sort || !_isSortDragging) return;

    final renderObject = _listAreaKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;

    int direction = 0;
    if (globalPosition.dy >= rect.top && globalPosition.dy <= rect.bottom) {
      if (globalPosition.dx <= rect.left + _edgeZoneWidth) {
        direction = -1;
      } else if (globalPosition.dx >= rect.right - _edgeZoneWidth) {
        direction = 1;
      }
    }

    if (direction == 0) {
      _cancelEdgeTimer();
      _edgeDirection = 0;
      // 端ゾーンを離れたら、切り替え先のタブで挿入位置を表示する。
      _updateExternalSortInsertion(globalPosition);
      return;
    }

    // 端ゾーンではタブ切り替えを優先し、挿入表示は出さない。
    _clearExternalSortInsertion();

    // 同じ方向の端ゾーンに留まっている間は、進行中のタイマーを継続する。
    if (direction == _edgeDirection && _edgeSwitchTimer != null) return;

    _edgeDirection = direction;
    _scheduleEdgeSwitch(_edgeInitialDelay, direction);
  }

  /// [delay] 後に隣のタブへ切り替え、端ゾーンに留まり続ける限り
  /// 約0.7秒間隔で次のタブへ送る。
  void _scheduleEdgeSwitch(Duration delay, int direction) {
    _cancelEdgeTimer();
    _edgeSwitchTimer = Timer(delay, () {
      _edgeSwitchTimer = null;
      if (!mounted || !_isSortDragging || _edgeDirection != direction) return;
      final didSwitch = _switchTabInDirection(direction);
      if (didSwitch) {
        _scheduleEdgeSwitch(_edgeRepeatInterval, direction);
      } else {
        // 先頭／末尾のタブに達したらそれ以上進めない。
        _edgeDirection = 0;
      }
    });
  }

  bool _switchTabInDirection(int direction) {
    final controller = _tabController;
    if (controller == null) return false;
    final nextIndex = controller.index + direction;
    if (nextIndex < 0 || nextIndex >= controller.length) return false;
    controller.animateTo(nextIndex);
    _sortTabSwitched = true;
    if (mounted) {
      setState(() {
        _currentTabIndex = nextIndex;
      });
    }
    return true;
  }

  /// 並び替えモードのドラッグ終了を処理する。
  ///
  /// 戻り値が true の場合は、呼び出し元の一覧側の並び替え処理を抑止する。
  bool _handleSortDragEnd(
    KifEntity kif,
    Offset? globalPosition,
    List<TabEntity> tabs,
  ) {
    _cancelEdgeTimer();
    _edgeDirection = 0;
    final hadSwitched = _sortTabSwitched;
    _sortTabSwitched = false;

    final wasDragging = _isSortDragging;
    if (_isSortDragging) {
      setState(() {
        _isSortDragging = false;
      });
    }
    if (!wasDragging || _currentMode != AppMode.sort) {
      _clearExternalSortInsertion();
      _sortSourceTabId = null;
      return false;
    }

    // キャンセル時はタブ移動しない（切り替え済みなら内部並び替えのみ抑止）。
    if (globalPosition == null) {
      _clearExternalSortInsertion();
      _sortSourceTabId = null;
      return hadSwitched;
    }

    final controller = _tabController;
    if (controller == null) {
      _clearExternalSortInsertion();
      _sortSourceTabId = null;
      return false;
    }
    final index = controller.index;
    if (index < 0 || index >= tabs.length) {
      _clearExternalSortInsertion();
      _sortSourceTabId = null;
      return false;
    }

    final targetTab = tabs[index];
    final targetTabId = targetTab.id;
    if (targetTabId == null || targetTabId == kif.tabId) {
      // 同じタブ内での並び替えは従来どおり一覧側に任せる。
      _clearExternalSortInsertion();
      _sortSourceTabId = null;
      return hadSwitched;
    }

    final targetState = _listKeys[targetTabId]?.currentState;
    // 切り替え先で表示した位置（隙間）を優先し、無ければ座標から求める。
    final insertionIndex = targetState?.externalInsertionIndex ??
        targetState?.insertionIndexAtGlobal(globalPosition);
    _clearExternalSortInsertion();
    _sortSourceTabId = null;
    _moveKifToTab(kif, targetTabId, tabs, insertionIndex);
    return true;
  }

  /// 並び替えモードで別タブへ移動された棋譜を、指定位置へ挿入する。
  Future<void> _moveKifToTab(
    KifEntity kif,
    int targetTabId,
    List<TabEntity> tabs, [
    int? targetIndex,
  ]) async {
    final targetTabs = tabs.where((t) => t.id == targetTabId).toList();
    if (targetTabs.isEmpty) return;
    final fromTabId = kif.tabId;
    try {
      // 未保存の同一タブ内並び替えを先に確定させ、残りの順序を保つ。
      final fromState = _listKeys[fromTabId]?.currentState;
      await fromState?.persistOrder();
      // 挿入位置の基準になる移動先の並び順も確定させる。
      final targetState = _listKeys[targetTabId]?.currentState;
      if (targetIndex != null) {
        await targetState?.persistOrder();
      }
      await _kifDao.moveKifToTab(
        kif,
        targetTabId,
        targetIndex: targetIndex,
      );
      if (!mounted) return;
      _listKeys[fromTabId]?.currentState?.refreshFromParent();
      _listKeys[targetTabId]?.currentState?.refreshFromParent();
    } catch (e) {
      debugPrint('棋譜のタブ移動に失敗しました: $e');
      if (mounted) ShowErrorSnackbar.show(context, '棋譜を移動できませんでした');
    }
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
    final dao = _kifDao;
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
    BackupService.restoreRevision.removeListener(_onRestoreCompleted);
    _cancelEdgeTimer();
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

        final activeIndex = _tabController!.index;
        _activeTabId = tabs.isNotEmpty &&
                activeIndex >= 0 &&
                activeIndex < tabs.length
            ? tabs[activeIndex].id
            : null;

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
                if (_currentMode != AppMode.normal) ...[
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
              ] else ...[
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
                        labelStyle: widget.useGoogleFonts
                            ? GoogleFonts.notoSansJp(fontWeight: FontWeight.bold)
                            : const TextStyle(fontWeight: FontWeight.bold),
                        unselectedLabelStyle: widget.useGoogleFonts
                            ? GoogleFonts.notoSansJp(fontWeight: FontWeight.normal)
                            : const TextStyle(fontWeight: FontWeight.normal),
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
                          style: widget.useGoogleFonts
                              ? GoogleFonts.notoSansJp(
                                  color: Colors.red.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                )
                              : TextStyle(
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
              key: _listAreaKey,
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
                                backgroundColor: Colors.white, // 背景色を白に設定（地グレーとの境界を出す）
                                foregroundColor: Colors.black87, // 文字・アイコン色を濃いグレー/黒系に設定
                                side: BorderSide.none, // 枠線なし
                                elevation: 0, // 影なし（フラットな見た目）
                                shape: const StadiumBorder(), // カプセル型の丸み
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        )
                      : _currentMode == AppMode.sort
                          // 並び替え中は全タブをレイアウトしたまま切り替える。
                          // ドラッグ元が画面外でもジオメトリを保てるため、
                          // カードを掴んだままタブをまたげる。
                          ? IndexedStack(
                              index: _tabController!.index,
                              sizing: StackFit.expand,
                              children: tabs
                                  .map((t) => _buildKifList(t, tabs))
                                  .toList(),
                            )
                          : TabBarView(
                              controller: _tabController,
                              physics: hasSelection
                                  ? const NeverScrollableScrollPhysics()
                                  : const BouncingScrollPhysics(),
                              children: tabs
                                  .map((t) => _buildKifList(t, tabs))
                                  .toList(),
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
