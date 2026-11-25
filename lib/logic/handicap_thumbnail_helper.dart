/// 保存時に開始局面のサムネイルを自動生成するかどうかの判定。
class HandicapThumbnailHelper {
  const HandicapThumbnailHelper._();

  /// 0手かつ手合割が平手以外の棋譜なら true。
  /// 平手・1手以上ある棋譜は従来通りサムネイルを変更しない。
  static bool shouldGenerateForStartPosition({
    required int totalMoveCount,
    required String? handicapLabel,
  }) {
    if (totalMoveCount != 0) return false;
    final label = handicapLabel?.trim();
    return label != null && label.isNotEmpty && label != '平手';
  }
}
