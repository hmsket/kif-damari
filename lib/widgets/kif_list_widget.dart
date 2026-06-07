import 'package:flutter/material.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/pages/home_page.dart';
import 'kif_list_item.dart';

class KifListWidget extends StatefulWidget {
  final int tabId;
  final AppMode mode;
  final VoidCallback onRefresh;

  const KifListWidget({
    super.key,
    required this.tabId,
    required this.mode,
    required this.onRefresh,
  });

  @override
  State<KifListWidget> createState() => KifListWidgetState();
}

class KifListWidgetState extends State<KifListWidget> {
  Future<List<KifEntity>>? _kifuFuture;
  List<KifEntity>? _tempKifs;
  
  int _lastKifCount = 0;
  bool _isFirstLoadDone = false;

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

        if (kifs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40.0),
              child: Text(
                '棋譜がありません\n＋ボタンから追加してください',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (widget.mode == AppMode.sort) {
          return ReorderableListView.builder(
            itemCount: kifs.length,
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
              );
            },
          );
        }

        return ListView.builder(
          itemCount: kifs.length,
          itemBuilder: (context, index) {
            final kif = kifs[index];
            return KifListItem(
              key: ValueKey('list_${kif.id}'),
              kif: kif,
              mode: widget.mode,
              onRefresh: _loadKifu,
            );
          },
        );
      },
    );
  }
}
