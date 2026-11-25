import 'package:flutter/material.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/logic/kif_search.dart';
import 'package:kifdamari/pages/home_page.dart';
import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/kif_list_item.dart';

/// ホームの棋譜検索結果（Issue #162）。
///
/// 全タブの棋譜を読み込み、[query] でタイトル・詳細を絞り込んで表示する。
/// 表示形式はホーム設定（グリッド / 詳細リスト）に従う。
class KifSearchView extends StatefulWidget {
  final String query;

  const KifSearchView({super.key, required this.query});

  @override
  State<KifSearchView> createState() => _KifSearchViewState();
}

class _KifSearchViewState extends State<KifSearchView> {
  List<KifEntity>? _kifs;

  @override
  void initState() {
    super.initState();
    _loadKifs();
  }

  Future<void> _loadKifs() async {
    try {
      final kifs = await KifDao().getAllKifs();
      if (!mounted) return;
      setState(() {
        _kifs = kifs;
      });
    } catch (e) {
      debugPrint('棋譜検索の読み込みエラー: $e');
      if (!mounted) return;
      setState(() {
        _kifs = _kifs ?? [];
      });
    }
  }

  bool get _isGridView {
    final viewMode = AppSettings().get<String>('homeViewMode');
    return viewMode != 'list';
  }

  @override
  Widget build(BuildContext context) {
    final kifs = _kifs;
    if (kifs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.query.trim().isEmpty) {
      return const Center(
        child: Text(
          'タイトルや詳細から棋譜を検索できます',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final results = KifSearch.filter(kifs, widget.query);
    if (results.isEmpty) {
      return const Center(
        child: Text(
          '該当する棋譜がありません',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ValueListenableBuilder(
      valueListenable: AppSettings().listenable,
      builder: (context, _, __) {
        return _isGridView ? _buildGrid(results) : _buildList(results);
      },
    );
  }

  Widget _buildList(List<KifEntity> kifs) {
    return ListView.builder(
      itemCount: kifs.length,
      itemBuilder: (context, index) {
        final kif = kifs[index];
        return KifListItem(
          key: ValueKey('search_list_${kif.id}'),
          kif: kif,
          mode: AppMode.normal,
          onRefresh: _loadKifs,
        );
      },
    );
  }

  Widget _buildGrid(List<KifEntity> kifs) {
    return GridView.builder(
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
        return KifGridItem(
          key: ValueKey('search_grid_${kif.id}'),
          kif: kif,
          mode: AppMode.normal,
          onRefresh: _loadKifs,
        );
      },
    );
  }
}
