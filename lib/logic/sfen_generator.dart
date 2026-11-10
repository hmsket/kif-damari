import 'package:kifdamari/models/board_state.dart';

class SfenGenerator {
  static const Map<String, String> _pieceToSfen = {
    'fu': 'P',
    'ya': 'L',
    'ke': 'N',
    'gi': 'S',
    'ki': 'G',
    'ka': 'B',
    'hi': 'R',
    'gy': 'K',
    'to': '+P',
    'ny': '+L',
    'nk': '+N',
    'ng': '+S',
    'um': '+B',
    'ry': '+R',
  };

  static const Map<String, String> _promotedFrom = {
    'to': 'fu',
    'ny': 'ya',
    'nk': 'ke',
    'ng': 'gi',
    'um': 'ka',
    'ry': 'hi',
  };

  static const List<String> _handOrder = ['hi', 'ka', 'ki', 'gi', 'ke', 'ya', 'fu'];
  static const Map<String, String> _handToSfen = {
    'hi': 'R',
    'ka': 'B',
    'ki': 'G',
    'gi': 'S',
    'ke': 'N',
    'ya': 'L',
    'fu': 'P',
  };

  static String generateKey(BoardState state) {
    final board = StringBuffer();
    for (int y = 0; y < 9; y++) {
      int emptyCount = 0;
      for (int x = 0; x < 9; x++) {
        final piece = state.grid[y][x];
        if (piece == null) {
          emptyCount++;
          continue;
        }
        if (emptyCount > 0) {
          board.write(emptyCount);
          emptyCount = 0;
        }
        final sfen = _pieceToSfen[piece.substring(1)];
        if (sfen == null) {
          throw ArgumentError('不明な駒コードです: $piece');
        }
        board.write(piece.startsWith('b') ? sfen : sfen.toLowerCase());
      }
      if (emptyCount > 0) {
        board.write(emptyCount);
      }
      if (y < 8) {
        board.write('/');
      }
    }

    final turn = state.nextPlayer == Player.sente ? 'b' : 'w';

    final senteHand = StringBuffer();
    final goteHand = StringBuffer();
    for (final type in _handOrder) {
      final senteCount = state.senteHand[type] ?? 0;
      final goteCount = state.goteHand[type] ?? 0;
      if (senteCount > 0) {
        senteHand.write('${senteCount > 1 ? senteCount : ''}${_handToSfen[type]!}');
      }
      if (goteCount > 0) {
        goteHand.write('${goteCount > 1 ? goteCount : ''}${_handToSfen[type]!.toLowerCase()}');
      }
    }
    final hands = (senteHand.isEmpty && goteHand.isEmpty) ? '-' : '$senteHand$goteHand';

    return '$board $turn $hands';
  }

  static String moveCode({
    required BoardState fromState,
    required BoardState toState,
    required String fallbackLabel,
  }) {
    final toX = toState.lastMoveToX;
    final toY = toState.lastMoveToY;
    if (toX == null || toY == null) return fallbackLabel;

    final destPiece = toState.grid[toY - 1][9 - toX];
    if (destPiece == null) return fallbackLabel;
    final destType = destPiece.substring(1);

    final fromX = toState.lastMoveFromX;
    final fromY = toState.lastMoveFromY;
    if (fromX == null || fromY == null) {
      return '+$toX$toY$destType';
    }

    final srcPiece = fromState.grid[fromY - 1][9 - fromX];
    if (srcPiece == null) return fallbackLabel;
    final srcType = srcPiece.substring(1);

    if (destType != srcType) {
      final baseType = _promotedFrom[destType];
      if (baseType == null || baseType != srcType) return fallbackLabel;
      return '$fromX$fromY$toX$toY$baseType+';
    }
    return '$fromX$fromY$toX$toY$destType';
  }
}
