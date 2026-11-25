import 'package:kifdamari/database/entity/kif_entity.dart';

/// 棋譜検索の絞り込みロジック（Issue #162）。
///
/// タイトルと詳細テキストに検索文字列が含まれる棋譜だけを返す。
/// 大文字・小文字は区別しない。
class KifSearch {
  static List<KifEntity> filter(List<KifEntity> kifs, String query) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return const [];

    return kifs.where((kif) {
      final title = kif.title.toLowerCase();
      final detail = (kif.detail ?? '').toLowerCase();
      return title.contains(keyword) || detail.contains(keyword);
    }).toList();
  }
}
