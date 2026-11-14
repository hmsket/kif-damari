import 'package:kifdamari/logic/position_searcher.dart';

/// 局面検索の結果一覧（Issue #38）の1行分。
/// ①のヒットに、データ層の出現情報から集計した「出現する棋譜」の件数と局面コメントを付けたもの。
class PositionSearchResultRow {
  final PositionSearchHit hit;
  final int kifuCount;
  final String comment;

  const PositionSearchResultRow({
    required this.hit,
    required this.kifuCount,
    this.comment = '',
  });
}

/// 結果一覧を「出現する棋譜」の件数が多い順に並べ替えたリストを返す。
/// 件数が同じ行は入力の順序（安定）を保つ。
List<PositionSearchResultRow> sortRowsByKifuCount(
  List<PositionSearchResultRow> rows,
) {
  final indexed = <(int, PositionSearchResultRow)>[
    for (var i = 0; i < rows.length; i++) (i, rows[i]),
  ];
  indexed.sort((a, b) {
    final byCount = b.$2.kifuCount.compareTo(a.$2.kifuCount);
    if (byCount != 0) return byCount;
    return a.$1.compareTo(b.$1);
  });
  return [for (final (_, row) in indexed) row];
}
