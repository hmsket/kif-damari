import 'package:kifdamari/database/dao/position_appearance_dao.dart';
import 'package:kifdamari/database/dao/position_dao.dart';
import 'package:kifdamari/logic/position_search_result.dart';
import 'package:kifdamari/logic/position_searcher.dart';

/// 局面検索の実行（DB走査 + 照合ロジックの呼び出し）。
/// 検索ロジック本体は PositionSearcher（純粋関数・テスト対象）。
class PositionSearchService {
  /// 全局面の position_key を走査してパターンに一致する局面を返す。
  static Future<List<PositionSearchHit>> search(
    List<List<String?>> pattern,
    PositionSearchMode mode,
  ) async {
    try {
      final keys = await PositionDao().getAllKeys();
      return PositionSearcher.search(keys, pattern, mode);
    } catch (_) {
      return [];
    }
  }

  /// 結果一覧（②）の行データを作る。
  /// 各ヒットの局面について、出現情報から「出現する棋譜」の件数と局面コメントを取り、
  /// 件数が多い順に並べ替えて返す。
  static Future<List<PositionSearchResultRow>> loadResultRows(
    List<PositionSearchHit> hits,
  ) async {
    try {
      final rows = <PositionSearchResultRow>[];
      final positionDao = PositionDao();
      final appearanceDao = PositionAppearanceDao();

      for (final hit in hits) {
        var kifuCount = 0;
        var comment = '';
        final position = await positionDao.getByKey(hit.positionKey);
        final positionId = position?.id;
        if (positionId != null) {
          kifuCount =
              (await appearanceDao.getKifIdsForPosition(positionId)).length;
          comment = position!.comment;
        }
        rows.add(PositionSearchResultRow(
          hit: hit,
          kifuCount: kifuCount,
          comment: comment,
        ));
      }
      return sortRowsByKifuCount(rows);
    } catch (_) {
      return [];
    }
  }
}
