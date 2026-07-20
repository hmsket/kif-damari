import 'package:kifdamari/models/board_state.dart';

class ShogiRuleHelper {
  /// 指定した座標にある駒の移動可能マスを取得する
  static List<List<int>> getValidMoves({
    required BoardState boardState,
    required int fromFile,
    required int fromRank,
  }) {
    List<List<int>> validMoves = [];
    final String? piece = boardState.grid[fromRank - 1][9 - fromFile];
    if (piece == null) return validMoves;

    final isSente = piece.startsWith('b');
    final type = piece.substring(1);
    final dir = isSente ? -1 : 1;

    // 1. 飛び道具（香、角、飛、馬、龍）のループ処理
    if (type == 'hi' || type == 'ry' || type == 'ka' || type == 'um' || type == 'ya') {
      List<List<int>> directions = [];
      
      if (type == 'hi' || type == 'ry') {
        directions.addAll([[1, 0], [-1, 0], [0, 1], [0, -1]]);
      }
      if (type == 'ka' || type == 'um') {
        directions.addAll([[1, 1], [1, -1], [-1, 1], [-1, -1]]);
      }
      if (type == 'ya') {
        directions.add([dir, 0]);
      }

      for (var d in directions) {
        int step = 1;
        while (true) {
          int targetY = (fromRank - 1) + (d[0] * step);
          int targetX = (9 - fromFile) + (d[1] * step);

          if (targetX < 0 || targetX > 8 || targetY < 0 || targetY > 8) break;

          final String? targetPiece = boardState.grid[targetY][targetX];
          
          if (targetPiece == null) {
            validMoves.add([9 - targetX, targetY + 1]);
          } else {
            if ((isSente && targetPiece.startsWith('w')) || (!isSente && targetPiece.startsWith('b'))) {
              validMoves.add([9 - targetX, targetY + 1]);
            }
            break; // 駒に当たったらその方向はそれ以上進めない
          }
          step++;
        }
      }
    }

    // 2. 1マスのみ移動する駒の処理
    List<List<int>> shortMoves = [];
    const goldTypes = {'ki', 'to', 'ny', 'nk', 'ng'};

    if (goldTypes.contains(type)) {
      shortMoves.addAll([[dir, 0], [dir, -1], [dir, 1], [0, -1], [0, 1], [-dir, 0]]);
    } else if (type == 'fu') {
      shortMoves.add([dir, 0]);
    } else if (type == 'ke') {
      shortMoves.addAll([[dir * 2, -1], [dir * 2, 1]]);
    } else if (type == 'gi') {
      shortMoves.addAll([[dir, 0], [dir, -1], [dir, 1], [-dir, -1], [-dir, 1]]);
    } else if (type == 'gy') {
      shortMoves.addAll([[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]);
    } else if (type == 'um') {
      shortMoves.addAll([[1, 0], [-1, 0], [0, 1], [0, -1]]);
    } else if (type == 'ry') {
      shortMoves.addAll([[1, 1], [1, -1], [-1, 1], [-1, -1]]);
    }

    for (var move in shortMoves) {
      int targetY = (fromRank - 1) + move[0];
      int targetX = (9 - fromFile) + move[1];

      if (targetX < 0 || targetX > 8 || targetY < 0 || targetY > 8) continue;

      final String? targetPiece = boardState.grid[targetY][targetX];
      if (targetPiece != null) {
        if (isSente && targetPiece.startsWith('b')) continue;
        if (!isSente && targetPiece.startsWith('w')) continue;
      }

      validMoves.add([9 - targetX, targetY + 1]);
    }

    return validMoves;
  }

  /// 持駒を打てるマスを取得する（二歩・行き所のない駒の判定含む）
  static List<List<int>> getValidDropMoves({
    required BoardState boardState,
    required String pieceType,
  }) {
    List<List<int>> validDrops = [];
    final currentPlayer = boardState.nextPlayer;

    for (int file = 1; file <= 9; file++) {
      for (int rank = 1; rank <= 9; rank++) {
        final String? existingPiece = boardState.grid[rank - 1][9 - file];
        if (existingPiece != null) continue;

        // 行き所のない駒の禁止ルール
        if (pieceType == 'fu' || pieceType == 'ya') {
          if (currentPlayer == Player.sente && rank == 1) continue;
          if (currentPlayer == Player.gote && rank == 9) continue;
        }
        if (pieceType == 'ke') {
          if (currentPlayer == Player.sente && rank <= 2) continue;
          if (currentPlayer == Player.gote && rank >= 8) continue;
        }

        // 二歩の禁止ルール
        if (pieceType == 'fu') {
          bool hasNifu = false;
          for (int y = 0; y < 9; y++) {
            final pieceOnSrc = boardState.grid[y][9 - file];
            if (pieceOnSrc != null) {
              if (currentPlayer == Player.sente && pieceOnSrc == 'bfu') {
                hasNifu = true;
                break;
              }
              if (currentPlayer == Player.gote && pieceOnSrc == 'wfu') {
                hasNifu = true;
                break;
              }
            }
          }
          if (hasNifu) continue;
        }

        validDrops.add([file, rank]);
      }
    }

    return validDrops;
  }
}
