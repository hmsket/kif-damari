import 'package:flutter/material.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/dao/tab_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/database/entity/tab_entity.dart';
import 'package:kifdamari/logic/kif_search.dart';
import 'package:kifdamari/pages/home_page.dart';
import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/kif_list_item.dart';

typedef KifSearchTabsLoader = Future<List<TabEntity>> Function();
typedef KifSearchKifsLoader = Future<List<KifEntity>> Function(int tabId);

/// ホームの棋譜検索結果（Issue #162, #177）。
///
/// 全タブの棋譜をタブごとに読み込んで合算し、[query] でタイトル・詳細を
/// 絞り込んで表示する。表示形式はホーム設定（グリッド / 詳細リスト）に従う。
class KifSearchView extends StatefulWidget {
  final String query;

  /// テスト用の読み込みフック。未指定なら [TabDao] / [KifDao] を使う。
  final KifSearchTabsLoader? loadTabs;
  final KifSearchKifsLoader? loadKifsByTab;

  const KifSearchView({
    super.key,
    required this.query,
    this.loadTabs,
    this.loadKifsByTab,
  });

  @override
  State<KifSearchView> createState() => _KifSearchViewState();
}

class _KifSearchViewState extends State<KifSearchView> {
  List<KifEntity>? _kifs;
  Object? _loadError;
  int _failedTabCount = 0;
  bool _isLoading = true;

  /// 古い読み込み結果で新しい状態を上書きしないための世代番号。
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadKifs();
  }

  Future<List<TabEntity>> _loadTabs() {
    final loader = widget.loadTabs;
    return loader != null ? loader() : TabDao().getAllTabs();
  }

  Future<List<KifEntity>> _loadKifsByTab(int tabId) {
    final loader = widget.loadKifsByTab;
    return loader != null ? loader(tabId) : KifDao().getKifsByTab(tabId);
  }

  Future<void> _loadKifs() async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _loadError = null;
      _failedTabCount = 0;
    });

    try {
      final tabs = await _loadTabs();
      final kifs = <KifEntity>[];
      var tabCount = 0;
      var failedTabCount = 0;
      Object? firstError;

      for (final tab in tabs) {
        final tabId = tab.id;
        if (tabId == null) continue;
        tabCount++;
        try {
          kifs.addAll(await _loadKifsByTab(tabId));
        } catch (e) {
          failedTabCount++;
          firstError ??= e;
          debugPrint('棋譜検索のタブ読み込みエラー (tabId=$tabId): $e');
        }
      }

      if (!mounted || generation != _loadGeneration) return;

      if (tabCount > 0 && failedTabCount == tabCount) {
        setState(() {
          _kifs = null;
          _loadError = firstError;
          _failedTabCount = failedTabCount;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _kifs = kifs;
        _loadError = null;
        _failedTabCount = failedTabCount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('棋譜検索のタブ取得エラー: $e');
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _kifs = null;
        _loadError = e;
        _failedTabCount = 0;
        _isLoading = false;
      });
    }
  }

  bool get _isGridView {
    final viewMode = AppSettings().get<String>('homeViewMode');
    return viewMode != 'list';
  }

  @override
  Widget build(BuildContext context) {
    final error = _loadError;
    if (error != null) {
      return _buildError(error);
    }

    final kifs = _kifs;
    if (kifs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final Widget content;
    if (widget.query.trim().isEmpty) {
      content = const Center(
        child: Text(
          'タイトルや詳細から棋譜を検索できます',
          style: TextStyle(color: Colors.grey),
        ),
      );
    } else {
      final results = KifSearch.filter(kifs, widget.query);
      if (results.isEmpty) {
        content = const Center(
          child: Text(
            '該当する棋譜がありません',
            style: TextStyle(color: Colors.grey),
          ),
        );
      } else {
        content = ValueListenableBuilder(
          valueListenable: AppSettings().listenable,
          builder: (context, _, __) {
            return _isGridView ? _buildGrid(results) : _buildList(results);
          },
        );
      }
    }

    return Column(
      children: [
        if (_failedTabCount > 0) _buildPartialFailureNotice(),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildPartialFailureNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '一部のタブを読み込めませんでした（$_failedTabCount件）',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              '棋譜を読み込めませんでした',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'エラー: ${error.runtimeType}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _isLoading ? null : _loadKifs,
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
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
