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
  Future<List<KifEntity>>? _kifuFuture;
  List<KifEntity>? _tempKifs;

  @override
  void initState() {
    super.initState();
    _loadKifu();
  }

  // ★重要: モードが切り替わった時や、タブが変わった時にデータを再取得
  @override
  void didUpdateWidget(KifListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // モードが normal に戻った時、またはタブが変わった時にリフレッシュ
    if (oldWidget.mode != widget.mode || oldWidget.tabId != widget.tabId) {
      _loadKifu();
    }
  }

  void refreshFromParent() {
    _loadKifu(); // キャッシュされているFutureを最新データで上書きして再描画
  }

  void _loadKifu() {
    setState(() {
      _tempKifs = null; // 一時リストをクリア
      _kifuFuture = KifDao().getKifsByTab(widget.tabId);
    });
  }

  // HomePageのチェックボタンから呼び出し
  Future<void> saveOrder() async {
    if (_tempKifs != null) {
      await KifDao().updateAllKifOrders(_tempKifs!);
      // 保存が終わったら、Futureを更新して画面を最新にする
      _loadKifu(); 
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KifEntity>>(
      future: _kifuFuture,
      builder: (context, snapshot) {
        // 並べ替え中のドラッグ操作でのsetStateではIndicatorを出さない
        if (snapshot.connectionState == ConnectionState.waiting && _tempKifs == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final kifs = _tempKifs ?? snapshot.data ?? [];
        if (kifs.isEmpty) return const Center(child: Text('棋譜がまだありません'));

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
              // ここでは _loadKifu は呼ばない（ドラッグ中のチラつき防止）
            },
            itemBuilder: (context, index) {
              final kif = kifs[index];
              return KifListItem(
                key: ValueKey('sort_${kif.id}'),
                kif: kif,
                mode: widget.mode,
                onRefresh: _loadKifu, // ListItem側で何かあってもこのWidgetをリフレッシュ
              );
            },
          );
        }

        // 通常モード
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
