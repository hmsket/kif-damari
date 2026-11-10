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

  static const Map<String, String> _sfenToPiece = {
    'P': 'fu',
    'L': 'ya',
    'N': 'ke',
    'S': 'gi',
    'G': 'ki',
    'B': 'ka',
    'R': 'hi',
    'K': 'gy',
    '+P': 'to',
    '+L': 'ny',
    '+N': 'nk',
    '+S': 'ng',
    '+B': 'um',
    '+R': 'ry',
  };

  static const Map<String, String> _sfenToHand = {
    'R': 'hi',
    'B': 'ka',
    'G': 'ki',
    'S': 'gi',
    'N': 'ke',
    'L': 'ya',
    'P': 'fu',
  };

  /// 盤面キー（position_key）から BoardState を復元する。
  /// 復元した盤面は generateKey を通すと元のキーに一致する。
  static BoardState stateFromKey(String key) {
    final parts = key.split(' ');
    if (parts.length < 3) {
      throw ArgumentError('盤面キーの形式が不正です: $key');
    }

    final boardPart = parts[0];
    final turn = parts[1];
    final handPart = parts[2];

    final rows = boardPart.split('/');
    if (rows.length != 9) {
      throw ArgumentError('盤面キーの盤部分が不正です: $key');
    }

    final grid = List.generate(9, (_) => List<String?>.filled(9, null));
    for (int y = 0; y < 9; y++) {
      final row = rows[y];
      int x = 0;
      int i = 0;
      while (i < row.length) {
        final ch = row[i];
        if (ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39) {
          x += ch.codeUnitAt(0) - 0x30;
          i++;
          continue;
        }

        String sfenPiece;
        if (ch == '+') {
          if (i + 1 >= row.length) {
            throw ArgumentError('盤面キーの盤部分が不正です: $key');
          }
          sfenPiece = '+${row[i + 1]}';
          i += 2;
        } else {
          sfenPiece = ch;
          i++;
        }

        final type = _sfenToPiece[sfenPiece.toUpperCase()];
        if (type == null) {
          throw ArgumentError('不明な駒が盤面キーに含まれています: $key');
        }

        final letter = row[i - 1];
        final prefix = _isUpperCasePiece(letter) ? 'b' : 'w';
        if (x > 8) {
          throw ArgumentError('盤面キーの盤部分が不正です: $key');
        }
        grid[y][x] = prefix + type;
        x++;
      }
      if (x != 9) {
        throw ArgumentError('盤面キーの盤部分が不正です: $key');
      }
    }

    final senteHand = <String, int>{};
    final goteHand = <String, int>{};
    if (handPart != '-') {
      String digits = '';
      for (int i = 0; i < handPart.length; i++) {
        final ch = handPart[i];
        if (ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39) {
          digits += ch;
          continue;
        }
        final type = _sfenToHand[ch.toUpperCase()];
        if (type == null) {
          throw ArgumentError('持ち駒部分が不正です: $key');
        }
        final count = digits.isEmpty ? 1 : int.parse(digits);
        if (_isUpperCasePiece(ch)) {
          senteHand[type] = count;
        } else {
          goteHand[type] = count;
        }
        digits = '';
      }
    }

    return BoardState(
      grid: grid,
      senteHand: senteHand,
      goteHand: goteHand,
      nextPlayer: turn == 'b' ? Player.sente : Player.gote,
    );
  }

  /// 大文字（成駒の '+' は除く）かどうかで手番の所属を判定する
  static bool _isUpperCasePiece(String ch) {
    final code = ch.codeUnitAt(0);
    return code >= 0x41 && code <= 0x5A;
  }

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
