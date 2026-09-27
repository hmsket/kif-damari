import 'package:flutter/material.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/dialogs/delete_kif_dialog.dart';
import 'package:kifdamari/pages/home_page.dart';
import 'kif_list_item.dart';

class KifListWidget extends StatefulWidget {
  final int tabId;
  final AppMode mode;
  final VoidCallback onRefresh;
  final VoidCallback? onSelectionChanged;
  final VoidCallback? onAddKifPressed; // ★ コールバックを追加

  const KifListWidget({
    super.key,
    required this.tabId,
    required this.mode,
    required this.onRefresh,
    this.onSelectionChanged,
    this.onAddKifPressed, // ★ コールバックを追加
  });

  @override
  State<KifListWidget> createState() => KifListWidgetState();
}

class KifListWidgetState extends State<KifListWidget> {
  Future<List<KifEntity>>? _kifuFuture;
  List<KifEntity>? _tempKifs;
  
  int _lastKifCount = 0;
  bool _isFirstLoadDone = false;

  final Set<int> _selectedKifIds = {};

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
    _loadKifu();
  }

  @override
  void didUpdateWidget(KifListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode || oldWidget.tabId != widget.tabId) {
      if (widget.mode != AppMode.delete) {
        _selectedKifIds.clear();
      }
      _loadKifu();
    }
  }

  void refreshFromParent() {
    _loadKifu();
  }

  void _loadKifu() {
    setState(() {
      _tempKifs = null;
      _kifuFuture = KifDao().getKifsByTab(widget.tabId);
    });
  }

  Future<void> saveOrder() async {
    if (_tempKifs != null) {
      await KifDao().updateAllKifOrders(_tempKifs!);
      _loadKifu(); 
      widget.onRefresh();
    }
  }

  Future<void> deleteSelectedKifs() async {
    if (_selectedKifIds.isEmpty) return;
    showDeleteSelectedKifsDialog(context, _selectedKifIds.length, () async {
      await KifDao().deleteKifs(_selectedKifIds.toList());
      _selectedKifIds.clear();
      widget.onSelectionChanged?.call();
      _loadKifu();
      widget.onRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KifEntity>>(
      future: _kifuFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _tempKifs == null) {
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
                  backgroundColor: Colors.white, // 背景色を白に設定
                  foregroundColor: Colors.black87, // 文字・アイコン色を濃いグレー/黒系に設定
                  side: BorderSide(
                    color: Colors.grey.shade400, // 枠線の色
                    width: 1.5, // 枠線の太さ
                  ),
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
        if (widget.mode == AppMode.sort) {
          return ReorderableListView.builder(
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
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                final item = kifs.removeAt(oldIndex);
                kifs.insert(newIndex, item);
                _tempKifs = List.from(kifs);
              });
            },
            itemBuilder: (context, index) {
              final kif = kifs[index];
              return KifListItem(
                key: ValueKey('sort_${kif.id}'),
                kif: kif,
                mode: widget.mode,
                onRefresh: _loadKifu,
                index: index,
              );
            },
          );
        }

        return ListView.builder(
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
      },
    );
  }
}
