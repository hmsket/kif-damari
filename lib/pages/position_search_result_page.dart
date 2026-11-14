import 'package:flutter/material.dart';
import 'package:kifdamari/logic/integrated_tree_service.dart';
import 'package:kifdamari/logic/position_search_result.dart';
import 'package:kifdamari/logic/position_searcher.dart';
import 'package:kifdamari/logic/sfen_generator.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/pages/integrated_tree_page.dart';
import 'package:kifdamari/snackbars/show_error_snackbar.dart';
import 'package:kifdamari/widgets/kif_board.dart';

/// 局面検索の結果一覧画面（Issue #38）。
/// 上部にパターンの概要（小盤＋モードの説明）、その下にヒットした局面の行を並べる。
/// 行の並び順は「出現する棋譜」の件数が多い順（rows は並べ替え済みで受け取る）。
class PositionSearchResultPage extends StatelessWidget {
  final List<List<String?>> pattern;
  final PositionSearchMode mode;
  final List<PositionSearchResultRow> rows;

  const PositionSearchResultPage({
    super.key,
    required this.pattern,
    required this.mode,
    required this.rows,
  });

  String get _modeDescription => mode == PositionSearchMode.exact
      ? '場所も一致：指定したマスにその駒がある局面を探します'
      : '場所はどこでも：駒の並びが同じならどこでもヒットします（後手向きに回転した配置も対象）';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFFF1F1F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('検索結果'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverview(),
            const Divider(height: 1),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('見つかりませんでした'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: rows.length,
                      itemBuilder: (context, index) =>
                          _buildResultRow(context, rows[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// パターンの概要: パターンの小盤＋モードの説明
  Widget _buildOverview() {
    final patternState = BoardState(
      grid: pattern,
      senteHand: const {},
      goteHand: const {},
      nextPlayer: Player.sente,
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 75,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: KifBoard(state: patternState),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _modeDescription,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(BuildContext context, PositionSearchResultRow row) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openIntegratedTree(context, row.hit.positionKey),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _HitMiniBoard(
                positionKey: row.hit.positionKey,
                matchedSquares: row.hit.matchedSquares,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '出現する棋譜 ${row.kifuCount}件',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (row.comment.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // 個別棋譜ツリーのコメント印と同じ青い吹き出し
                          const Icon(
                            Icons.chat_bubble,
                            size: 14,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              row.comment.split('\n').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  /// 行タップで統合ツリー画面をその局面で開く
  Future<void> _openIntegratedTree(
    BuildContext context,
    String positionKey,
  ) async {
    final root = await IntegratedTreeService.findRootOf(positionKey);
    if (!context.mounted) return;
    if (root == null) {
      ShowErrorSnackbar.show(context, 'この局面は統合ツリーに登録されていません');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IntegratedTreePage(
          rootPosition: root,
          initialPositionKey: positionKey,
        ),
      ),
    );
  }
}

/// ヒットした局面のミニ盤。
/// パターンがマッチしたマスを、最終手ハイライトと同じ赤半透明でハイライトする。
class _HitMiniBoard extends StatelessWidget {
  final String positionKey;
  final List<List<int>> matchedSquares;

  const _HitMiniBoard({
    required this.positionKey,
    required this.matchedSquares,
  });

  @override
  Widget build(BuildContext context) {
    BoardState? state;
    try {
      state = SfenGenerator.stateFromKey(positionKey);
    } catch (_) {
      // 復元できない局面は盤面なしで表示する
    }

    return SizedBox(
      width: 92,
      height: 96,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            Positioned.fill(
              child: state != null
                  ? KifBoard(state: state)
                  : const SizedBox.shrink(),
            ),
            Positioned.fill(child: _buildHighlightLayer()),
          ],
        ),
      ),
    );
  }

  /// マッチしたマス（[筋, 段]）を盤上に重ねて塗る
  Widget _buildHighlightLayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double paddingRate = 0.0125;
        final double cellW = constraints.maxWidth * (1 - paddingRate * 2) / 9;
        final double cellH = constraints.maxHeight * (1 - paddingRate * 2) / 9;
        final double offsetX = constraints.maxWidth * paddingRate;
        final double offsetY = constraints.maxHeight * paddingRate;

        return Stack(
          children: [
            for (final square in matchedSquares)
              Positioned(
                key: ValueKey('result_highlight_${square[0]}_${square[1]}'),
                left: offsetX + (9 - square[0]) * cellW,
                top: offsetY + (square[1] - 1) * cellH,
                width: cellW,
                height: cellH,
                child: ColoredBox(
                  color: Colors.red.withOpacity(0.4),
                ),
              ),
          ],
        );
      },
    );
  }
}
