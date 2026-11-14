import 'package:flutter/material.dart';
import 'package:kifdamari/logic/position_search_service.dart';
import 'package:kifdamari/logic/position_searcher.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/pages/position_search_result_page.dart';
import 'package:kifdamari/widgets/kif_board.dart';

/// 局面検索画面（Issue #37）。
/// 空盤から駒を配置してパターンを組み、盤面のみで全局面を照合する。
/// 手番・持駒は不問。SFEN 入力は付けない。
class PositionSearchPage extends StatefulWidget {
  const PositionSearchPage({super.key});

  @override
  State<PositionSearchPage> createState() => _PositionSearchPageState();
}

/// ピッカーで選べる駒（盤に置ける全種）
const List<(String, String)> _kPieceTypes = [
  ('fu', '歩'),
  ('ya', '香'),
  ('ke', '桂'),
  ('gi', '銀'),
  ('ki', '金'),
  ('ka', '角'),
  ('hi', '飛'),
  ('gy', '玉'),
  ('to', 'と'),
  ('ny', '成香'),
  ('nk', '成桂'),
  ('ng', '成銀'),
  ('um', '馬'),
  ('ry', '龍'),
];

class _PositionSearchPageState extends State<PositionSearchPage> {
  /// 検索パターンの盤（grid[y][x]）。駒コードは 'bfu' 'wgy' など。空マスは null。
  final List<List<String?>> _pattern =
      List.generate(9, (_) => List<String?>.filled(9, null));

  PositionSearchMode _mode = PositionSearchMode.exact;
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('局面検索'),
      ),
      body: SafeArea(
        // スクロール無しで1画面に収める（盤＋モード切替＋操作部）
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 878 / 960,
                    child: _buildPatternBoard(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SegmentedButton<PositionSearchMode>(
                segments: const [
                  ButtonSegment(
                    value: PositionSearchMode.exact,
                    label: Text('場所も一致'),
                    icon: Icon(Icons.push_pin_outlined),
                  ),
                  ButtonSegment(
                    value: PositionSearchMode.anywhere,
                    label: Text('場所はどこでも'),
                    icon: Icon(Icons.open_with),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() => _mode = selection.first);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearPattern,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('全消し'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _isSearching ? null : _search,
                      icon: const Icon(Icons.search),
                      label: _isSearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('検索'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// パターン盤。KifBoard の描画＋同じジオメトリのタップ受付レイヤー。
  Widget _buildPatternBoard() {
    return Stack(
      children: [
        Positioned.fill(
          child: KifBoard(state: _patternState()),
        ),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double paddingRate = 0.0125;
              final double cellW = constraints.maxWidth * (1 - paddingRate * 2) / 9;
              final double cellH = constraints.maxHeight * (1 - paddingRate * 2) / 9;
              final double offsetX = constraints.maxWidth * paddingRate;
              final double offsetY = constraints.maxHeight * paddingRate;

              return Stack(
                children: [
                  for (int y = 0; y < 9; y++)
                    for (int x = 0; x < 9; x++)
                      Positioned(
                        left: offsetX + x * cellW,
                        top: offsetY + y * cellH,
                        width: cellW,
                        height: cellH,
                        child: GestureDetector(
                          key: ValueKey('square_${x}_$y'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openPiecePicker(x, y),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  BoardState _patternState() {
    return BoardState(
      grid: _pattern,
      senteHand: const {},
      goteHand: const {},
      nextPlayer: Player.sente,
    );
  }

  Future<void> _openPiecePicker(int x, int y) async {
    final current = _pattern[y][x];
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _PiecePickerSheet(
        currentPiece: current,
      ),
    );
    if (selected == null || !mounted) return;

    setState(() {
      _pattern[y][x] = selected == '' ? null : selected;
    });
  }

  void _clearPattern() {
    setState(() {
      for (int y = 0; y < 9; y++) {
        for (int x = 0; x < 9; x++) {
          _pattern[y][x] = null;
        }
      }
    });
  }

  Future<void> _search() async {
    setState(() => _isSearching = true);
    final hits = await PositionSearchService.search(_pattern, _mode);
    final rows = await PositionSearchService.loadResultRows(hits);
    if (!mounted) return;
    setState(() => _isSearching = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PositionSearchResultPage(
          pattern: _copiedPattern(),
          mode: _mode,
          rows: rows,
        ),
      ),
    );
  }

  /// 結果画面に渡すパターンのコピー（遷移後に検索画面で編集しても影響しないようにする）
  List<List<String?>> _copiedPattern() =>
      _pattern.map((row) => List<String?>.of(row)).toList();
}

/// 駒ピッカー（シート状の一覧）。先手・後手の全種の駒から選ぶ。
/// 駒のあるマスでは「駒を消す」も選べる。
class _PiecePickerSheet extends StatelessWidget {
  final String? currentPiece;

  const _PiecePickerSheet({required this.currentPiece});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'マスに置く駒を選んでください',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (currentPiece != null)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, ''),
                    icon: const Icon(Icons.backspace_outlined, size: 18),
                    label: const Text('駒を消す'),
                  ),
              ],
            ),
            _buildSection(context, '先手', 'b'),
            _buildSection(context, '後手', 'w'),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String label, String prefix) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 140 / 148,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (final (type, name) in _kPieceTypes)
              _PieceTile(
                key: ValueKey('piece_tile_${prefix}_$type'),
                prefix: prefix,
                type: type,
                name: name,
              ),
          ],
        ),
      ],
    );
  }
}

class _PieceTile extends StatelessWidget {
  final String prefix;
  final String type;
  final String name;

  const _PieceTile({
    super.key,
    required this.prefix,
    required this.type,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => Navigator.pop(context, '$prefix$type'),
      child: Column(
        children: [
          // 実物の縦横比（140x148）を保って表示する
          Expanded(
            child: AspectRatio(
              aspectRatio: 140 / 148,
              child: Image.asset(
                'assets/images/pieces/$prefix$type.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Text(name, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

