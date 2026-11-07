import 'package:flutter/material.dart';
import 'package:kifdamari/models/board_state.dart';

class KifBoard extends StatelessWidget {
  final BoardState state;
  final bool isReversed;
  final int? selectedX;
  final int? selectedY;
  final List<List<int>>? validMoves;

  /// ドラッグ中の駒の位置（筋・段）。指定されたマスの駒は盤面に描画しない。
  final int? draggingX;
  final int? draggingY;

  const KifBoard({
    super.key,
    required this.state,
    this.isReversed = false,
    this.selectedX,
    this.selectedY,
    this.validMoves,
    this.draggingX,
    this.draggingY,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double paddingRate = 0.0125;
        final double boardWidth = constraints.maxWidth * (1 - paddingRate * 2);
        final double boardHeight = constraints.maxHeight * (1 - paddingRate * 2);
        final double cellSizeW = boardWidth / 9;
        final double cellSizeH = boardHeight / 9;
        final double offsetX = constraints.maxWidth * paddingRate;
        final double offsetY = constraints.maxHeight * paddingRate;

        List<Widget> pieces = [];

        for (int y = 0; y < 9; y++)  {
          for (int x = 0; x < 9; x++) {
            final String? pieceName = state.grid[y][x];
            if (pieceName != null) {
              final bool isDraggingPiece = draggingX != null &&
                  draggingY != null &&
                  x == 9 - draggingX &&
                  y == draggingY - 1;
              if (isDraggingPiece) continue;

              final displayX = isReversed ? (8 - x) : x;
              final displayY = isReversed ? (8 - y) : y;

              String finalPieceName = pieceName;
              if (isReversed) {
                if (pieceName.startsWith('b')) {
                  finalPieceName = pieceName.replaceFirst('b', 'w');
                } else if (pieceName.startsWith('w')) {
                  finalPieceName = pieceName.replaceFirst('w', 'b');
                }
              }

              pieces.add(
                Positioned(
                  key: ValueKey('piece_$x$y$finalPieceName'),
                  left: offsetX + displayX * cellSizeW,
                  top: offsetY + displayY * cellSizeH,
                  width: cellSizeW,
                  height: cellSizeH,
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Image.asset(
                      'assets/images/pieces/$finalPieceName.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            }
          }
        }

        bool isCoordInValidMoves(int x, int y) {
          if (validMoves == null) return false;
          return validMoves!.any((move) => move[0] == x && move[1] == y);
        }

        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/board.png', fit: BoxFit.fill),
            ),

            if (state.lastMoveFromX != null && 
                state.lastMoveFromY != null &&
                !isCoordInValidMoves(state.lastMoveFromX!, state.lastMoveFromY!))
              _buildHighlight(
                key: ValueKey('highlight_red_from'),
                x: isReversed ? (state.lastMoveFromX! - 1) : (9 - state.lastMoveFromX!),
                y: isReversed ? (9 - state.lastMoveFromY!) : (state.lastMoveFromY! - 1),
                color: Colors.red.withOpacity(0.2),
                cellSizeW: cellSizeW,
                cellSizeH: cellSizeH,
                offsetX: offsetX,
                offsetY: offsetY,
              ),
            if (state.lastMoveToX != null && 
                state.lastMoveToY != null &&
                !isCoordInValidMoves(state.lastMoveToX!, state.lastMoveToY!))
              _buildHighlight(
                key: ValueKey('highlight_red_to'),
                x: isReversed ? (state.lastMoveToX! - 1) : (9 - state.lastMoveToX!),
                y: isReversed ? (9 - state.lastMoveToY!) : (state.lastMoveToY! - 1),
                color: Colors.red.withOpacity(0.4),
                cellSizeW: cellSizeW,
                cellSizeH: cellSizeH,
                offsetX: offsetX,
                offsetY: offsetY,
              ),

            if (selectedX != null && selectedY != null)
              _buildHighlight(
                key: ValueKey('highlight_orange_sel'),
                x: isReversed ? (selectedX! - 1) : (9 - selectedX!),
                y: isReversed ? (9 - selectedY!) : (selectedY! - 1),
                color: Colors.orange.withOpacity(0.4),
                cellSizeW: cellSizeW,
                cellSizeH: cellSizeH,
                offsetX: offsetX,
                offsetY: offsetY,
              ),

            if (validMoves != null)
              ...validMoves!.map((move) {
                final int mvX = move[0];
                final int mvY = move[1];
                return _buildHighlight(
                  key: ValueKey('highlight_blue_$mvX$mvY'),
                  x: isReversed ? (mvX - 1) : (9 - mvX),
                  y: isReversed ? (9 - mvY) : (mvY - 1),
                  color: Colors.blue.withOpacity(0.3),
                  cellSizeW: cellSizeW,
                  cellSizeH: cellSizeH,
                  offsetX: offsetX,
                  offsetY: offsetY,
                );
              }),
            ...pieces,
          ],
        );
      },
    );
  }

  Widget _buildHighlight({
    Key? key,
    required int x,
    required int y,
    required Color color,
    required double cellSizeW,
    required double cellSizeH,
    required double offsetX,
    required double offsetY,
  }) {
    return Positioned(
      key: key,
      left: offsetX + x * cellSizeW,
      top: offsetY + y * cellSizeH,
      width: cellSizeW,
      height: cellSizeH,
      child: Container(
        decoration: BoxDecoration(
          color: color,
        ),
      ),
    );
  }
}
