import 'package:flutter/material.dart';
import '../database/dao/kif_dao.dart';
import '../database/entity/kif_entity.dart';
import '../main.dart';
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
  Future<List<KifEntity>>? _kifuFuture; // null許容にして安全に
  List<KifEntity>? _tempKifs;

  @override
  void initState() {
    super.initState();
    _loadKifu();
  }

  // ★重要: タブが切り替わったときにFutureを再生成しないと、前のタブのデータを表示し続けてエラーになる
  @override
  void didUpdateWidget(KifListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabId != widget.tabId) {
      _tempKifs = null;
      _loadKifu();
    }
  }

  void _loadKifu() {
    setState(() {
      _kifuFuture = KifDao().getKifsByTab(widget.tabId);
    });
  }

  // HomePageのチェックボタンから呼び出す
  Future<void> saveOrder() async {
    if (_tempKifs != null) {
      await KifDao().updateAllKifOrders(_tempKifs!);
      _tempKifs = null;
      _loadKifu();
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_kifuFuture == null) return const SizedBox.shrink();

    return FutureBuilder<List<KifEntity>>(
      future: _kifuFuture,
      builder: (context, snapshot) {
        // 並べ替え中のsetStateでIndicatorが出ないように制御
        if (snapshot.connectionState == ConnectionState.waiting && _tempKifs == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }

        final kifs = _tempKifs ?? snapshot.data ?? [];
        if (kifs.isEmpty) return const Center(child: Text('棋譜がまだありません'));

        if (widget.mode == AppMode.sort) {
          return ReorderableListView.builder(
            itemCount: kifs.length,
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                // インデックスの範囲外エラーを防ぐ
                if (oldIndex >= 0 && oldIndex < kifs.length) {
                  final item = kifs.removeAt(oldIndex);
                  kifs.insert(newIndex, item);
                  _tempKifs = List.from(kifs);
                }
              });
            },
            itemBuilder: (context, index) {
              final kif = kifs[index];
              return KifListItem(
                key: ValueKey('sort_${kif.id}'), // Keyをより一意に
                kif: kif,
                mode: widget.mode,
                onRefresh: widget.onRefresh,
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
              onRefresh: widget.onRefresh,
            );
          },
        );
      },
    );
  }
}
