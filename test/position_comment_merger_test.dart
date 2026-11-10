import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/position_comment_merger.dart';

void main() {
  group('PositionCommentMerger.merge', () {
    test('既存が空なら追加の内容になる', () {
      expect(PositionCommentMerger.merge('', 'メモA'), 'メモA');
    });

    test('追加が空なら既存のまま', () {
      expect(PositionCommentMerger.merge('メモA', ''), 'メモA');
    });

    test('衝突時は既存→改行→追加の順で1本に連結される', () {
      expect(PositionCommentMerger.merge('メモA', 'メモB'), 'メモA\nメモB');
    });

    test('同一文は重複させない', () {
      expect(PositionCommentMerger.merge('メモA', 'メモA'), 'メモA');
      expect(PositionCommentMerger.merge('メモA\nメモB', 'メモA'), 'メモA\nメモB');
      expect(PositionCommentMerger.merge('メモA\nメモB', 'メモA\nメモB'), 'メモA\nメモB');
    });
  });
}
