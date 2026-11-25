import 'package:flutter_test/flutter_test.dart';
import 'package:kifdamari/logic/handicap_thumbnail_helper.dart';

void main() {
  group('HandicapThumbnailHelper.shouldGenerateForStartPosition', () {
    test('0手かつ駒落ちなら開始局面のサムネイルを生成する', () {
      expect(
        HandicapThumbnailHelper.shouldGenerateForStartPosition(
          totalMoveCount: 0,
          handicapLabel: '二枚落ち',
        ),
        isTrue,
      );
    });

    test('0手でも平手なら生成しない', () {
      expect(
        HandicapThumbnailHelper.shouldGenerateForStartPosition(
          totalMoveCount: 0,
          handicapLabel: '平手',
        ),
        isFalse,
      );
      expect(
        HandicapThumbnailHelper.shouldGenerateForStartPosition(
          totalMoveCount: 0,
          handicapLabel: null,
        ),
        isFalse,
      );
    });

    test('1手以上ある駒落ちの棋譜は生成しない', () {
      expect(
        HandicapThumbnailHelper.shouldGenerateForStartPosition(
          totalMoveCount: 1,
          handicapLabel: '二枚落ち',
        ),
        isFalse,
      );
    });
  });
}
