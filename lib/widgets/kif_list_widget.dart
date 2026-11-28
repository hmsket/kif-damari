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

  /// 並び替えモードでカードのドラッグが始まったときに、
  /// ドラッグ元のタブ ID とともに呼ばれる。
  final void Function(int tabId)? onSortDragStart;

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

  /// ドラッグ開始時に掴んだ位置（カード左上からの相対座標）と
  /// ドラッグ中カードのサイズ。タブをまたぐドラッグでも、同一タブ内の
  /// Reorderable 標準と同じ「カードの実体」を基準に挿入位置を決めるために使う。
  Offset? _dragPointerOffset;
  Size? _dragItemSize;
  Offset? _pointerDownPosition;

  /// 別タブからドラッグされてきたカードを、この一覧の何番目に
  /// 挿入するかを示す。null のときは外部からの挿入表示なし。
  int? _externalInsertionIndex;
  double _sortListItemExtent = 0;

  int? get externalInsertionIndex => _externalInsertionIndex;

  double get _sortListGapExtent =>
      _sortListItemExtent > 0 ? _sortListItemExtent : 80.0;

  static const double _sortGridHorizontalPadding = 24.0;
  static const SliverGridDelegateWithMaxCrossAxisExtent _sortGridDelegate =
      SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 200,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 0.95,
  );

  final GlobalKey _sortGridKey = GlobalKey();
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
    // 並び替えモードの出入りでは再読み込みをしない。
    // 表示中の一覧をそのまま使い続けることで、モード切替直後に長押しした
    // ドラッグのジェスチャ認識が一覧の差し替えで失われるのを防ぎ、
    // 保存（確定）時に一覧が再構築されて点滅するのも防ぐ。
    final bool enteringSort =
        oldWidget.mode != widget.mode && widget.mode == AppMode.sort;
    final bool leavingSort =
        oldWidget.mode == AppMode.sort && widget.mode != AppMode.sort;
    if (oldWidget.tabId != widget.tabId ||
        (oldWidget.mode != widget.mode && !enteringSort && !leavingSort)) {
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
      _externalInsertionIndex = null;
    });
  }

  /// 表示中の並び順を DB に保存する。
  ///
  /// 保存は永続化だけを行い、一覧の再読み込みはしない。表示中の内容と
  /// スクロール位置をそのまま保つことで、確定時の点滅を防ぐ。
  Future<void> saveOrder() async {
    await persistOrder();
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
    final kif = kifs[index];
    _draggingKif = kif;

    // ドラッグ中カードの実体（サイズと掴んだ位置）を覚えておく。
    // タブをまたいだ後も、この矩形を基準に同一タブ内と同じ挿入判定を行う。
    Offset? pointerOffset;
    Size? itemSize;
    final key = _shiftKey(kif.id!);
    final renderBox = _collectItemRenderBoxes({key})[key];
    if (renderBox != null) {
      final rect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
      final grab = _pointerDownPosition == null
          ? rect.size.center(Offset.zero)
          : _pointerDownPosition! - rect.topLeft;
      pointerOffset = Offset(
        grab.dx.clamp(0.0, rect.width).toDouble(),
        grab.dy.clamp(0.0, rect.height).toDouble(),
      );
      itemSize = rect.size;
    }
    _dragPointerOffset = pointerOffset;
    _dragItemSize = itemSize;

    widget.onSortDragStart?.call(widget.tabId);
  }

  void _handleSortPointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.position;
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
    _dragPointerOffset = null;
    _dragItemSize = null;
    if (suppressInternalReorder) {
      // 別タブへの移動として親が処理するため、内部の並び替えは走らせない。
      _suppressNextReorder = true;
    }
  }

  /// ドラッグ中カードの現在の矩形を返す。ドラッグ開始前は null。
  ///
  /// ポインタ位置だけではなくカードの実体位置で挿入判定するために使う。
  Rect? dragRectAt(Offset globalPosition) {
    final size = _dragItemSize;
    final grab = _dragPointerOffset;
    if (size == null || grab == null) return null;
    return (globalPosition - grab) & size;
  }

  /// 別タブで進行中のドラッグ位置を受け取り、この一覧での挿入位置を
  /// 更新する。タブ切り替え後もカードがずれて隙間が空くフィードバックを
  /// 出すために使う。
  void updateExternalInsertion(Offset globalPosition, {Rect? draggedRect}) {
    final index = insertionIndexAtGlobal(
      globalPosition,
      draggedRect: draggedRect,
    );
    if (index == _externalInsertionIndex) return;
    setState(() {
      _externalInsertionIndex = index;
    });
  }

  /// 別タブからのドラッグに対する挿入表示を消す。
  void clearExternalInsertion() {
    if (_externalInsertionIndex == null) return;
    setState(() {
      _externalInsertionIndex = null;
    });
  }

  /// グローバル座標 [globalPosition] にドロップしたときに、この一覧の
  /// 何番目の位置へ挿入するかを返す。
  ///
  /// [draggedRect] が渡された場合は、ポインタ位置ではなくドラッグ中カードの
  /// 実体の中心を基準にする。同一タブ内の Reorderable 系はカードの実体同士の
  /// 重なりで挿入位置を決めているため、カードが既存棋譜と同じ位置にあるときは
  /// 既存棋譜を優先（挿入位置は既存棋譜の後ろ）する。
  ///
  /// 一覧がまだ読み込まれていない場合は null（移動先の末尾へ追加）を返す。
  int? insertionIndexAtGlobal(Offset globalPosition, {Rect? draggedRect}) {
    final kifs = _tempKifs;
    if (kifs == null) return null;
    if (kifs.isEmpty) return 0;

    final reference = draggedRect?.center ?? globalPosition;
    final isGrid = _isGridView;
    final keys = kifs.map((kif) => _shiftKey(kif.id!)).toSet();
    final renderBoxes = _collectItemRenderBoxes(keys);
    if (renderBoxes.isEmpty) return kifs.length;

    if (!isGrid) {
      // 外部ドラッグ用の隙間の高さを、実際のリスト項目に合わせる。
      for (final kif in kifs) {
        final renderBox = renderBoxes[_shiftKey(kif.id!)];
        if (renderBox != null) {
          _sortListItemExtent = renderBox.size.height;
          break;
        }
      }
    }

    int count = 0;
    for (final kif in kifs) {
      final renderBox = renderBoxes[_shiftKey(kif.id!)];
      if (renderBox == null) continue;
      final rect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
      if (isGrid) {
        if (reference.dy > rect.bottom) {
          count++;
        } else if (reference.dy >= rect.top &&
            reference.dx >= rect.center.dx) {
          count++;
        }
      } else if (reference.dy >= rect.center.dy) {
        count++;
      }
    }
    return count;
  }

  Key _shiftKey(int kifId) => ValueKey(
      _isGridView ? 'sort_grid_shift_$kifId' : 'sort_shift_$kifId');

  double get _sortGridContentWidth {
    final renderObject = _sortGridKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size.width - _sortGridHorizontalPadding;
    }
    return MediaQuery.sizeOf(context).width - _sortGridHorizontalPadding;
  }

  Offset _gridShiftExtent(int index) {
    final width = _sortGridContentWidth;
    if (width <= 0) return Offset.zero;

    final delegate = _sortGridDelegate;
    int crossAxisCount =
        (width / (delegate.maxCrossAxisExtent + delegate.crossAxisSpacing))
            .ceil();
    if (crossAxisCount < 1) crossAxisCount = 1;

    final usableCrossAxisExtent =
        width - delegate.crossAxisSpacing * (crossAxisCount - 1);
    final cellWidth = usableCrossAxisExtent / crossAxisCount;
    final cellHeight =
        delegate.mainAxisExtent ?? cellWidth / delegate.childAspectRatio;
    final crossAxisStride = cellWidth + delegate.crossAxisSpacing;
    final mainAxisStride = cellHeight + delegate.mainAxisSpacing;

    if (index % crossAxisCount < crossAxisCount - 1) {
      return Offset(crossAxisStride, 0);
    }
    return Offset(
      -crossAxisStride * (crossAxisCount - 1),
      mainAxisStride,
    );
  }

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
          // 棋譜が空のときの表示。
          // 並び替えモードでは空になっても並び替え用のウィジェットを
          // 作り直さない（_buildSortList / _buildSortGrid 側で表示する）。
          if (kifs.isEmpty && widget.mode != AppMode.sort) {
            return _buildEmptyKifState();
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

  /// 棋譜が1件もないときの「棋譜を追加する」表示。
  Widget _buildEmptyKifState() {
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

  /// 並べ替えモード（詳細リスト表示）: カードの長押しドラッグで並べ替え
  Widget _buildSortList(List<KifEntity> kifs) {
    // 並び替え用のウィジェットは、一覧が空になっても作り直さず同じ位置に
    // 置き続ける。ドロップ直後に元タブが空になると、ドラッグの終了処理が
    // 走る前にウィジェットが破棄され、浮遊表示（Overlay）が残ることがある。
    final gapIndex = _externalInsertionIndex;
    return Listener(
      onPointerDown: _handleSortPointerDown,
      onPointerMove: _handleSortPointerMove,
      onPointerUp: _handleSortPointerUp,
      onPointerCancel: _handleSortPointerCancel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ReorderableListView.builder(
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
              // 外部からの挿入表示中は、この一覧自身の並び替えは走らない。
              if (gapIndex != null) return;
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                final item = kifs.removeAt(oldIndex);
                kifs.insert(newIndex, item);
                _tempKifs = List.from(kifs);
              });
            },
            itemBuilder: (context, index) {
              final kif = kifs[index];
              final shift = gapIndex != null && index >= gapIndex
                  ? Offset(0, _sortListGapExtent)
                  : Offset.zero;
              // カード全体を長押しドラッグの開始領域にする（ハンドルは表示しない）
              return _AnimatedReorderShift(
                key: _shiftKey(kif.id!),
                shift: shift,
                child: ReorderableDelayedDragStartListener(
                  key: ValueKey('sort_${kif.id}'),
                  index: index,
                  child: KifListItem(
                    kif: kif,
                    mode: widget.mode,
                    onRefresh: _loadKifu,
                    index: index,
                  ),
                ),
              );
            },
          ),
          if (kifs.isEmpty) _buildEmptyKifState(),
        ],
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
    // 並び替え用のウィジェットは、一覧が空になっても作り直さず同じ位置に
    // 置き続ける。ドロップ直後に元タブが空になると、ドラッグの終了処理が
    // 走る前にウィジェットが破棄され、浮遊表示（Overlay）が残ることがある。
    final gapIndex = _externalInsertionIndex;
    return Listener(
      onPointerDown: _handleSortPointerDown,
      onPointerMove: _handleSortPointerMove,
      onPointerUp: _handleSortPointerUp,
      onPointerCancel: _handleSortPointerCancel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ReorderableGridView.builder(
            key: _sortGridKey,
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            gridDelegate: _sortGridDelegate,
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
              // 外部からの挿入表示中は、この一覧自身の並び替えは走らない。
              if (gapIndex != null) return;
              setState(() {
                final item = kifs.removeAt(oldIndex);
                kifs.insert(newIndex, item);
                _tempKifs = List.from(kifs);
              });
            },
            itemBuilder: (context, index) {
              final kif = kifs[index];
              final shift = gapIndex != null && index >= gapIndex
                  ? _gridShiftExtent(index)
                  : Offset.zero;
              return _AnimatedReorderShift(
                key: _shiftKey(kif.id!),
                shift: shift,
                child: KifGridItem(
                  key: ValueKey('sort_grid_${kif.id}'),
                  kif: kif,
                  mode: widget.mode,
                  onRefresh: _loadKifu,
                ),
              );
            },
          ),
          if (kifs.isEmpty) _buildEmptyKifState(),
        ],
      ),
    );
  }
}

class _AnimatedReorderShift extends StatefulWidget {
  const _AnimatedReorderShift({
    super.key,
    required this.shift,
    required this.child,
  });

  final Offset shift;
  final Widget child;

  @override
  State<_AnimatedReorderShift> createState() => _AnimatedReorderShiftState();
}

class _AnimatedReorderShiftState extends State<_AnimatedReorderShift>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 250);

  late final AnimationController _controller;
  late Offset _startOffset;
  late Offset _targetOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _startOffset = widget.shift;
    _targetOffset = widget.shift;
  }

  Offset get _currentOffset {
    if (!_controller.isAnimating) return _targetOffset;
    final double t = Curves.easeInOut.transform(_controller.value);
    return Offset.lerp(_startOffset, _targetOffset, t)!;
  }

  @override
  void didUpdateWidget(covariant _AnimatedReorderShift oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shift == _targetOffset) return;
    _startOffset = _currentOffset;
    _targetOffset = widget.shift;
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Transform.translate(offset: _currentOffset, child: child),
      child: widget.child,
    );
  }
}
