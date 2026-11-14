import 'package:kifdamari/database/dao/position_dao.dart';
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
}
