import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kifdamari/logic/position_search_service.dart';
import 'package:kifdamari/logic/position_searcher.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/pages/position_search_result_page.dart';
import 'package:kifdamari/widgets/kif_board.dart';

/// 局面検索画面（Issue #37 / #41）。
/// 空盤から駒を配置してパターンを組み、盤面のみで全局面を照合する。
/// 手番・持駒は不問。SFEN 入力は付けない。
/// 駒の配置は「パレットで駒を選んでマスにスタンプする」方式（Issue #41）。
class PositionSearchPage extends StatefulWidget {
  const PositionSearchPage({super.key});

  @override
  State<PositionSearchPage> createState() => _PositionSearchPageState();
}

/// パレットで選べる駒種（成り駒込みの全14種）
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

/// 盤画像のアスペクト比（幅 / 高さ）
const double _kBoardAspectRatio = 878 / 960;

/// パレットの1段に並べる駒の数
const int _kPiecesPerRow = 7;

/// パレット上部（先後切替 + 消しゴム）の高さ。
/// SegmentedButton のタップターゲット（48）に合わせて固定する。
const double _kPaletteBarHeight = 48;

/// パレットの駒1段分の高さ
const double _kPaletteRowHeight = 56;

class _PositionSearchPageState extends State<PositionSearchPage> {
  /// 検索パターンの盤（grid[y][x]）。駒コードは 'bfu' 'wgy' など。空マスは null。
  final List<List<String?>> _pattern =
      List.generate(9, (_) => List<String?>.filled(9, null));

  PositionSearchMode _mode = PositionSearchMode.exact;
  bool _isSearching = false;

  /// スタンプする駒（'bfu' など）。未選択は null。
  String? _selectedPiece;

  /// 消しゴム選択中かどうか
  bool _isEraser = false;

  /// パレットに表示する側。'b' = 先手, 'w' = 後手。
  String _side = 'b';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('局面検索'),
      ),
      body: SafeArea(
        // どんな画面サイズでも縦スクロールなしで1画面に収める（Issue #41）。
        // アプリバー / モード切替 / パレット / 下段バーは固定高、
        // 盤は残りの高さに合わせて縮む。
        child: Column(
          children: [
            // モード切替（固定高）
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
            // 盤（残りの高さに収まる最大サイズで表示）
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double width = math.min(
                        constraints.maxWidth,
                        constraints.maxHeight * _kBoardAspectRatio,
                      );
                      return SizedBox(
                        width: width,
                        height: width / _kBoardAspectRatio,
                        child: _buildPatternBoard(),
                      );
                    },
                  ),
                ),
              ),
            ),
            // 駒パレット（固定高）
            _buildPalette(),
            // 下段バー（固定高）
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

  /// 駒パレット。上部に先後切替トグルと消しゴム、
  /// 下に成り駒込みの全14種を2段で常駐させる。
  Widget _buildPalette() {
    final List<Widget> rows = [];
    for (var i = 0; i < _kPieceTypes.length; i += _kPiecesPerRow) {
      rows.add(
        SizedBox(
          height: _kPaletteRowHeight,
          child: Row(
            children: [
              for (final (type, name) in _kPieceTypes.skip(i).take(_kPiecesPerRow))
                Expanded(
                  child: _PaletteTile(
                    key: ValueKey('piece_tile_$_side$type'),
                    prefix: _side,
                    type: type,
                    name: name,
                    selected: _selectedPiece == '$_side$type',
                    onTap: () => _selectPiece('$_side$type'),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _kPaletteBarHeight,
            child: Row(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'b', label: Text('先手')),
                    ButtonSegment(value: 'w', label: Text('後手')),
                  ],
                  selected: {_side},
                  onSelectionChanged: (selection) =>
                      _switchSide(selection.first),
                ),
                const Spacer(),
                _EraserButton(
                  key: const ValueKey('palette_eraser'),
                  selected: _isEraser,
                  onTap: () => setState(() => _isEraser = !_isEraser),
                ),
              ],
            ),
          ),
          ...rows,
        ],
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
                          onTap: () => _placePiece(x, y),
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

  /// パレットで駒を選ぶ。消しゴムは解除される。
  void _selectPiece(String piece) {
    setState(() {
      _selectedPiece = piece;
      _isEraser = false;
    });
  }

  /// 先手 / 後手を切り替える。
  /// 駒を選択中なら、選択は保持したまま相手側の同種駒に切り替える。
  void _switchSide(String side) {
    if (side == _side) return;
    setState(() {
      _side = side;
      final piece = _selectedPiece;
      if (piece != null) {
        _selectedPiece = side + piece.substring(1);
      }
    });
  }

  /// マスをタップしたときの処理（スタンプ方式）。
  /// 消しゴム選択中ならそのマスの駒を消す。
  /// 駒選択中ならその駒を置く（置き済みのマスは上書き）。
  /// 選択は保持されるので、同じ駒を連続で置ける。
  void _placePiece(int x, int y) {
    if (_isEraser) {
      setState(() => _pattern[y][x] = null);
      return;
    }
    final piece = _selectedPiece;
    if (piece == null) return;
    setState(() => _pattern[y][x] = piece);
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

/// パレットの駒マス。選択中はハイライト表示する。
class _PaletteTile extends StatelessWidget {
  final String prefix;
  final String type;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteTile({
    super.key,
    required this.prefix,
    required this.type,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: selected ? Colors.orange.withOpacity(0.15) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: selected ? Colors.orange : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
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
        ),
      ),
    );
  }
}

/// 消しゴムボタン。選択中はハイライト表示する。
class _EraserButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _EraserButton({
    super.key,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.orange.withOpacity(0.15) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: selected ? Colors.orange : Colors.grey.shade400,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.backspace_outlined, size: 18),
              SizedBox(width: 4),
              Text('消しゴム', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
