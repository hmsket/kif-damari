import 'package:flutter/material.dart';
import 'package:reorderable_grid/reorderable_grid.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/dialogs/delete_kif_dialog.dart';
import 'package:kifdamari/pages/home_page.dart';
import 'package:kifdamari/widgets/app_settings.dart';
import 'kif_list_item.dart';

class KifListWidget extends StatefulWidget {
  final int tabId;
  final AppMode mode;
  final VoidCallback onRefresh;
  final VoidCallback? onSelectionChanged;
  final VoidCallback? onAddKifPressed; // ★ コールバックを追加

  /// テストから差し替えられる棋譜 DAO。
  final KifDao? kifDao;

  /// 並び替えモードでカードのドラッグが始まったときに呼ばれる。
  final VoidCallback? onSortDragStart;

  /// ドラッグ中にポインタが移動したときに、グローバル座標で呼ばれる。
  final void Function(Offset globalPosition)? onSortDragUpdate;

  /// ドラッグ終了時に呼ばれる。ドロップ位置（キャンセル時は null）が渡る。
  ///
  /// 戻り値が true の場合、この一覧側の並び替え処理は行わない
  /// （タブをまたぐ移動として親が処理する）。
  final bool Function(KifEntity kif, Offset? globalPosition)? onSortDragEnd;

  const KifListWidget({
    super.key,
    required this.tabId,
    required this.mode,
    required this.onRefresh,
    this.onSelectionChanged,
    this.onAddKifPressed, // ★ コールバックを追加
    this.kifDao,
    this.onSortDragStart,
    this.onSortDragUpdate,
    this.onSortDragEnd,
  });

  @override
  State<KifListWidget> createState() => KifListWidgetState();
}

class KifListWidgetState extends State<KifListWidget>
    with AutomaticKeepAliveClientMixin {
  Future<List<KifEntity>>? _kifuFuture;
  List<KifEntity>? _tempKifs;
  Future<List<KifEntity>>? _appliedFuture;

  int _lastKifCount = 0;
  bool _isFirstLoadDone = false;

  final Set<int> _selectedKifIds = {};

  KifEntity? _draggingKif;
  bool _suppressNextReorder = false;

  final ScrollController _scrollController = ScrollController();
  double _savedScrollOffset = 0.0;
  double _savedScrollProgress = 0.0;
  bool _restoreByProgress = false;
  bool _restorePending = false;
  bool _restoreScheduled = false;
  bool? _lastIsGridView;

  @override
  bool get wantKeepAlive => true;

  KifDao get _kifDao => widget.kifDao ?? KifDao();

  int get selectedCount => _selectedKifIds.length;

  bool get isKifEmpty {
    if (_tempKifs != null) return _tempKifs!.isEmpty;
    if (!_isFirstLoadDone) return true;
    return _lastKifCount == 0;
  }

  int get kifCount => _tempKifs?.length ?? _lastKifCount;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_saveScrollPosition);
    _loadKifu();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_saveScrollPosition);
    _scrollController.dispose();
    super.dispose();
  }

  /// 現在のスクロール位置をピクセル値と全体に対する比率で覚える。
  void _saveScrollPosition() {
    final positions = _scrollController.positions;
    if (positions.isEmpty) return;
    final position = positions.first;
    // レイアウト前の値で、覚えている位置を上書きしない。
    if (!position.hasViewportDimension || !position.hasContentDimensions) {
      return;
    }
    _savedScrollOffset = position.pixels;
    final maxScrollExtent = position.maxScrollExtent;
    _savedScrollProgress = maxScrollExtent > 0
        ? (position.pixels / maxScrollExtent).clamp(0.0, 1.0)
        : 0.0;
  }

  void _scheduleScrollRestore() {
    if (_restoreScheduled) return;
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScheduled = false;
      _restoreScrollPosition();
    });
  }

  /// 再読み込み後に、覚えた位置を新しい maxScrollExtent にクランプして復元する。
  void _restoreScrollPosition() {
    if (!_restorePending || !mounted) return;
    final positions = _scrollController.positions;
    if (positions.isEmpty) return;

    final position = positions.first;
    // レイアウトが完了していない間は復元しない（保存位置を壊さない）。
    if (!position.hasViewportDimension || !position.hasContentDimensions) {
      return;
    }
    final maxScrollExtent = position.maxScrollExtent;
    final target = (_restoreByProgress
            ? _savedScrollProgress * maxScrollExtent
            : _savedScrollOffset)
        .clamp(0.0, maxScrollExtent)
        .toDouble();
    _restorePending = false;
    _restoreByProgress = false;
    if ((position.pixels - target).abs() > 1) {
      _scrollController.jumpTo(target);
    }
  }

  @override
  void didUpdateWidget(KifListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode && widget.mode != AppMode.delete) {
      _selectedKifIds.clear();
    }
    // 並び替えモードに入った直後の再読み込みはしない。
    // 表示中の一覧をそのまま使い続けることで、モード切替直後に長押しした
    // ドラッグのジェスチャ認識が一覧の差し替えで失われるのを防ぐ。
    final bool enteringSort =
        oldWidget.mode != widget.mode && widget.mode == AppMode.sort;
    if (oldWidget.tabId != widget.tabId ||
        (oldWidget.mode != widget.mode && !enteringSort)) {
      _loadKifu();
    }
  }

  void refreshFromParent() {
    _loadKifu();
  }

  void _loadKifu() {
    _saveScrollPosition();
    _restorePending = true;
    setState(() {
      // 再読み込み中も直前に表示していた一覧を保持する（点滅防止）。
      // 初回読み込み時のみ _tempKifs が null のためスピナーを表示する。
      _kifuFuture = _kifDao.getKifsByTab(widget.tabId);
    });
  }

  Future<void> saveOrder() async {
    if (_tempKifs != null) {
      await _kifDao.updateAllKifOrders(_tempKifs!);
      _loadKifu(); 
      widget.onRefresh();
    }
  }

  /// 表示中の並び順だけを DB に保存する（再読み込みはしない）。
  Future<void> persistOrder() async {
    if (_tempKifs != null) {
      await _kifDao.updateAllKifOrders(_tempKifs!);
    }
  }

  void _handleSortDragStart(List<KifEntity> kifs, int index) {
    if (index < 0 || index >= kifs.length) return;
    _suppressNextReorder = false;
    _draggingKif = kifs[index];
    widget.onSortDragStart?.call();
  }

  void _handleSortPointerMove(PointerMoveEvent event) {
    if (_draggingKif == null) return;
    widget.onSortDragUpdate?.call(event.position);
  }

  void _handleSortPointerUp(PointerUpEvent event) {
    _finishSortDrag(event.position);
  }

  void _handleSortPointerCancel(PointerCancelEvent event) {
    _finishSortDrag(null);
  }

  void _finishSortDrag(Offset? globalPosition) {
    final kif = _draggingKif;
    if (kif == null) return;
    _draggingKif = null;

    final suppressInternalReorder =
        widget.onSortDragEnd?.call(kif, globalPosition) ?? false;
    if (suppressInternalReorder) {
      // 別タブへの移動として親が処理するため、内部の並び替えは走らせない。
      _suppressNextReorder = true;
    }
  }

  /// グローバル座標 [globalPosition] にドロップしたときに、この一覧の
  /// 何番目の位置へ挿入するかを返す。
  ///
  /// 一覧がまだ読み込まれていない場合は null（移動先の末尾へ追加）を返す。
  int? insertionIndexAtGlobal(Offset globalPosition) {
    final kifs = _tempKifs;
    if (kifs == null) return null;
    if (kifs.isEmpty) return 0;

    final isGrid = _isGridView;
    final keys = kifs.map((kif) => _itemKey(kif.id!)).toSet();
    final renderBoxes = _collectItemRenderBoxes(keys);
    if (renderBoxes.isEmpty) return kifs.length;

    int count = 0;
    for (final kif in kifs) {
      final renderBox = renderBoxes[_itemKey(kif.id!)];
      if (renderBox == null) continue;
      final rect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
      if (isGrid) {
        if (globalPosition.dy > rect.bottom) {
          count++;
        } else if (globalPosition.dy >= rect.top &&
            globalPosition.dx > rect.center.dx) {
          count++;
        }
      } else if (globalPosition.dy > rect.center.dy) {
        count++;
      }
    }
    return count;
  }

  Key _itemKey(int kifId) =>
      ValueKey(_isGridView ? 'sort_grid_$kifId' : 'sort_$kifId');

  Map<Key, RenderBox> _collectItemRenderBoxes(Set<Key> keys) {
    final result = <Key, RenderBox>{};
    void visit(Element element) {
      final key = element.widget.key;
      if (key != null && keys.contains(key) && !result.containsKey(key)) {
        final renderObject = element.renderObject;
        if (renderObject is RenderBox &&
            renderObject.attached &&
            renderObject.hasSize) {
          result[key] = renderObject;
        }
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    return result;
  }

  Future<void> deleteSelectedKifs() async {
    if (_selectedKifIds.isEmpty) return;
    showDeleteSelectedKifsDialog(context, _selectedKifIds.length, () async {
      await _kifDao.deleteKifs(_selectedKifIds.toList());
      _selectedKifIds.clear();
      widget.onSelectionChanged?.call();
      _loadKifu();
      widget.onRefresh();
    });
  }

  /// ホームの表示形式がグリッドかどうか（設定「homeViewMode」、デフォルトはグリッド）
  bool get _isGridView {
    final viewMode = AppSettings().get<String>('homeViewMode');
    return viewMode != 'list';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 設定変更（表示形式の切替）にも追随できるよう ValueListenableBuilder で包む
    return ValueListenableBuilder(
      valueListenable: AppSettings().listenable,
      builder: (context, _, __) {
        final isGrid = _isGridView;
        if (_lastIsGridView != null && _lastIsGridView != isGrid) {
          _saveScrollPosition();
          _restoreByProgress = true;
          _restorePending = true;
        }
        _lastIsGridView = isGrid;
        return FutureBuilder<List<KifEntity>>(
          future: _kifuFuture,
          builder: (context, snapshot) {
          // 新しい Future の結果が届いたら、保持している一覧を差し替える。
          // 同じ Future の再ビルドでは差し替えない（並べ替え中の _tempKifs を尊重する）。
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData &&
              !identical(_kifuFuture, _appliedFuture)) {
            _tempKifs = snapshot.data;
            _appliedFuture = _kifuFuture;
          }

          // スピナーは一度も一覧を表示していない初回読み込み時のみ。
          if (_tempKifs == null &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final kifs = _tempKifs ?? snapshot.data ?? [];

          final bool countChanged = _lastKifCount != kifs.length;
          final bool shouldNotify = !_isFirstLoadDone || (countChanged && kifs.isEmpty);

          _lastKifCount = kifs.length;
          _isFirstLoadDone = true;

          if (shouldNotify && widget.mode == AppMode.normal) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                widget.onRefresh();
              }
            });
          }
          // 棋譜が空のときの表示
          if (kifs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: OutlinedButton.icon(
                  onPressed: widget.onAddKifPressed,
                  icon: const Icon(Icons.add, size: 20), // ＋アイコン
                  label: const Text(
                    '棋譜を追加する',
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
            );
          }
          // スクロール可能なウィジェットを組み立てた後のフレームで位置を復元する。
          // 新しい一覧が反映される前（前の一覧を表示中）には復元しない。
          if (_restorePending && identical(_kifuFuture, _appliedFuture)) {
            _scheduleScrollRestore();
          }
          if (widget.mode == AppMode.sort) {
            return _isGridView ? _buildSortGrid(kifs) : _buildSortList(kifs);
          }

          return _isGridView ? _buildGrid(kifs) : _buildList(kifs);
        },
        );
      },
    );
  }

  /// 並べ替えモード（詳細リスト表示）: カードの長押しドラッグで並べ替え
  Widget _buildSortList(List<KifEntity> kifs) {
    return Listener(
      onPointerMove: _handleSortPointerMove,
      onPointerUp: _handleSortPointerUp,
      onPointerCancel: _handleSortPointerCancel,
      child: ReorderableListView.builder(
        scrollController: _scrollController,
        itemCount: kifs.length,
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) {
          return Material(
            elevation: 80,
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: child,
          );
        },
        onReorderStart: (index) => _handleSortDragStart(kifs, index),
        onReorder: (oldIndex, newIndex) {
          if (_suppressNextReorder) {
            _suppressNextReorder = false;
            return;
          }
          setState(() {
            if (oldIndex < newIndex) newIndex -= 1;
            final item = kifs.removeAt(oldIndex);
            kifs.insert(newIndex, item);
            _tempKifs = List.from(kifs);
          });
        },
        itemBuilder: (context, index) {
          final kif = kifs[index];
          // カード全体を長押しドラッグの開始領域にする（ハンドルは表示しない）
          return ReorderableDelayedDragStartListener(
            key: ValueKey('sort_${kif.id}'),
            index: index,
            child: KifListItem(
              kif: kif,
              mode: widget.mode,
              onRefresh: _loadKifu,
              index: index,
            ),
          );
        },
      ),
    );
  }

  /// 詳細リスト表示（通常・編集・削除モード）
  Widget _buildList(List<KifEntity> kifs) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: kifs.length,
      itemBuilder: (context, index) {
        final kif = kifs[index];
        final isSelected = _selectedKifIds.contains(kif.id);

        return KifListItem(
          key: ValueKey('list_${kif.id}'),
          kif: kif,
          mode: widget.mode,
          onRefresh: _loadKifu,
          isSelected: isSelected,
          onChanged: widget.mode == AppMode.delete
              ? (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedKifIds.add(kif.id!);
                    } else {
                      _selectedKifIds.remove(kif.id!);
                    }
                  });
                  widget.onSelectionChanged?.call();
                }
              : null,
        );
      },
    );
  }

  /// グリッド表示（通常・編集・削除モード）: 列数は画面幅で自動
  Widget _buildGrid(List<KifEntity> kifs) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: kifs.length,
      itemBuilder: (context, index) {
        final kif = kifs[index];
        final isSelected = _selectedKifIds.contains(kif.id);

        return KifGridItem(
          key: ValueKey('grid_${kif.id}'),
          kif: kif,
          mode: widget.mode,
          onRefresh: _loadKifu,
          isSelected: isSelected,
          onChanged: widget.mode == AppMode.delete
              ? (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedKifIds.add(kif.id!);
                    } else {
                      _selectedKifIds.remove(kif.id!);
                    }
                  });
                  widget.onSelectionChanged?.call();
                }
              : null,
        );
      },
    );
  }

  /// 並べ替えモード（グリッド表示）: カードの長押しドラッグで並べ替え
  Widget _buildSortGrid(List<KifEntity> kifs) {
    return Listener(
      onPointerMove: _handleSortPointerMove,
      onPointerUp: _handleSortPointerUp,
      onPointerCancel: _handleSortPointerCancel,
      child: ReorderableGridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.95,
        ),
        itemCount: kifs.length,
        proxyDecorator: (child, index, animation) {
          return Material(
            elevation: 6,
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: child,
          );
        },
        onReorderStart: (index) => _handleSortDragStart(kifs, index),
        onReorder: (oldIndex, newIndex) {
          if (_suppressNextReorder) {
            _suppressNextReorder = false;
            return;
          }
          setState(() {
            final item = kifs.removeAt(oldIndex);
            kifs.insert(newIndex, item);
            _tempKifs = List.from(kifs);
          });
        },
        itemBuilder: (context, index) {
          final kif = kifs[index];
          return KifGridItem(
            key: ValueKey('sort_grid_${kif.id}'),
            kif: kif,
            mode: widget.mode,
            onRefresh: _loadKifu,
          );
        },
      ),
    );
  }
}
