import 'package:kifdamari/logic/sfen_generator.dart';

/// 局面検索（Issue #37）の照合ロジック。
/// 盤面キー（position_key）の盤部分と、検索画面で組んだ駒配置パターンを照合する。
/// 手番・持駒・手数は照合対象外。
enum PositionSearchMode {
  /// 場所も一致: 指定したマスにその駒がある局面のみヒット
  exact,

  /// 場所はどこでも: 駒同士の相対配置が一致すればどこでもヒット。
  /// 後手向き（180°回転＋先後入替）の配置も自動で対象にする。
  anywhere,
}

/// 1件のヒット。position_key と、その局面でマッチしたマスの集合（[筋, 段]）を持つ。
/// マッチしたマスは②の結果画面でのハイライト表示に使う。
class PositionSearchHit {
  final String positionKey;
  final List<List<int>> matchedSquares;

  const PositionSearchHit({
    required this.positionKey,
    required this.matchedSquares,
  });
}

class PositionSearcher {
  /// 盤面キー一覧をパターンで照合する。
  /// pattern は BoardState.grid と同じ 9x9（grid[y][x]）で、
  /// 駒コードは 'bfu' 'wgy' など b/w + 駒種。空マスは null（不問）。
  /// 空のパターン（駒が1つも無い）は何もヒットしない。
  static List<PositionSearchHit> search(
    List<String> positionKeys,
    List<List<String?>> pattern,
    PositionSearchMode mode,
  ) {
    final hits = <PositionSearchHit>[];
    if (!_hasPiece(pattern)) return hits;

    // パターンの駒を筋の昇順（grid の x 降順、同 x なら y 昇順）に並べたセル列。
    // matchedSquares はこの順序に対応して返す。回転マッチも同じ順序を保つ。
    final cells = _orderedCells(pattern);
    final rotatedCells = mode == PositionSearchMode.anywhere ? _rotateCells(cells) : null;

    for (final key in positionKeys) {
      final grid = _boardGridFromKey(key);
      if (grid == null) continue;

      List<List<int>>? squares;
      if (mode == PositionSearchMode.exact) {
        squares = _matchExact(grid, cells);
      } else {
        squares = _matchRelative(grid, cells) ?? _matchRelative(grid, rotatedCells!);
      }
      if (squares != null) {
        hits.add(PositionSearchHit(positionKey: key, matchedSquares: squares));
      }
    }
    return hits;
  }

  static bool _hasPiece(List<List<String?>> pattern) {
    for (final row in pattern) {
      for (final cell in row) {
        if (cell != null) return true;
      }
    }
    return false;
  }

  /// 盤面キーを BoardState に復元して盤グリッドだけ取り出す。
  /// 手番・持駒は照合に使わない。不正なキーは null。
  static List<List<String?>>? _boardGridFromKey(String key) {
    try {
      return SfenGenerator.stateFromKey(key).grid;
    } catch (_) {
      return null;
    }
  }

  /// パターンの駒セルを筋の昇順（x 降順、同 x なら y 昇順）に並べた列を作る。
  static List<(int, int, String)> _orderedCells(List<List<String?>> pattern) {
    final cells = <(int, int, String)>[];
    for (int y = 0; y < 9; y++) {
      for (int x = 0; x < 9; x++) {
        final piece = pattern[y][x];
        if (piece != null) cells.add((x, y, piece));
      }
    }
    cells.sort((a, b) {
      final byX = b.$1.compareTo(a.$1);
      if (byX != 0) return byX;
      return a.$2.compareTo(b.$2);
    });
    return cells;
  }

  /// セル列を 180°回転＋先後入替する（＝後手向きに見た同じ配置）。
  /// セルの順序は変えず、座標変換と駒の先後入替だけを行う。
  static List<(int, int, String)> _rotateCells(List<(int, int, String)> cells) {
    return [
      for (final (x, y, piece) in cells)
        (
          8 - x,
          8 - y,
          piece.startsWith('b') ? 'w${piece.substring(1)}' : 'b${piece.substring(1)}',
        ),
    ];
  }

  /// 場所も一致: パターンの駒があるマスだけを比較する。
  static List<List<int>>? _matchExact(
    List<List<String?>> grid,
    List<(int, int, String)> cells,
  ) {
    final squares = <List<int>>[];
    for (final (x, y, piece) in cells) {
      if (grid[y][x] != piece) return null;
      squares.add(_square(x, y));
    }
    return squares;
  }

  /// 場所はどこでも: パターンを平行移動して全部が盤内に収まる置き方を全通り試す。
  static List<List<int>>? _matchRelative(
    List<List<String?>> grid,
    List<(int, int, String)> cells,
  ) {
    int minY = 9, maxY = -1, minX = 9, maxX = -1;
    for (final (x, y, _) in cells) {
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    if (cells.isEmpty) return null;

    for (int dy = -minY; dy <= 8 - maxY; dy++) {
      for (int dx = -minX; dx <= 8 - maxX; dx++) {
        final squares = <List<int>>[];
        var ok = true;
        for (final (x, y, piece) in cells) {
          final tx = x + dx;
          final ty = y + dy;
          if (grid[ty][tx] != piece) {
            ok = false;
            break;
          }
          squares.add(_square(tx, ty));
        }
        if (ok) return squares;
      }
    }
    return null;
  }

  /// grid 座標 → [筋, 段]（1〜9）
  static List<int> _square(int x, int y) => [9 - x, y + 1];
}
