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

    final rotated = mode == PositionSearchMode.anywhere ? _rotate180(_swapColors(pattern)) : null;

    for (final key in positionKeys) {
      final grid = _boardGridFromKey(key);
      if (grid == null) continue;

      List<List<int>>? squares;
      if (mode == PositionSearchMode.exact) {
        squares = _matchExact(grid, pattern);
      } else {
        squares = _matchRelative(grid, pattern) ?? _matchRelative(grid, rotated!);
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

  /// 場所も一致: パターンの駒があるマスだけを比較する。
  static List<List<int>>? _matchExact(
    List<List<String?>> grid,
    List<List<String?>> pattern,
  ) {
    final squares = <List<int>>[];
    for (int y = 0; y < 9; y++) {
      for (int x = 0; x < 9; x++) {
        final piece = pattern[y][x];
        if (piece == null) continue;
        if (grid[y][x] != piece) return null;
        squares.add(_square(x, y));
      }
    }
    return squares;
  }

  /// 場所はどこでも: パターンを平行移動して全部が盤内に収まる置き方を全通り試す。
  static List<List<int>>? _matchRelative(
    List<List<String?>> grid,
    List<List<String?>> pattern,
  ) {
    final cells = <(int, int, String)>[];
    int minY = 9, maxY = -1, minX = 9, maxX = -1;
    for (int y = 0; y < 9; y++) {
      for (int x = 0; x < 9; x++) {
        final piece = pattern[y][x];
        if (piece == null) continue;
        cells.add((x, y, piece));
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
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

  /// 180°回転＋先後入替（＝後手向きに見た同じ配置）
  static List<List<String?>> _rotate180(List<List<String?>> pattern) {
    final rotated = List.generate(9, (_) => List<String?>.filled(9, null));
    for (int y = 0; y < 9; y++) {
      for (int x = 0; x < 9; x++) {
        rotated[8 - y][8 - x] = pattern[y][x];
      }
    }
    return rotated;
  }

  static List<List<String?>> _swapColors(List<List<String?>> pattern) {
    return [
      for (final row in pattern)
        [
          for (final cell in row)
            if (cell == null) null else (cell.startsWith('b') ? 'w${cell.substring(1)}' : 'b${cell.substring(1)}'),
        ],
    ];
  }

  /// grid 座標 → [筋, 段]（1〜9）
  static List<int> _square(int x, int y) => [9 - x, y + 1];
}
