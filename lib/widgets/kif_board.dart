import 'package:flutter/material.dart';
import 'package:kifdamari/models/board_state.dart';

class KifBoard extends StatelessWidget {
  final BoardState state;
  final bool isReversed;

  const KifBoard({
    super.key,
    required this.state,
    this.isReversed = false,
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

        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/board.png', fit: BoxFit.fill),
            ),

            if (state.lastMoveFromX != null && state.lastMoveFromY != null)
              _buildHighlight(
                x: isReversed ? (state.lastMoveFromX! - 1) : (9 - state.lastMoveFromX!),
                y: isReversed ? (9 - state.lastMoveFromY!) : (state.lastMoveFromY! - 1),
                color: Colors.red.withOpacity(0.2),
                cellSizeW: cellSizeW,
                cellSizeH: cellSizeH,
                offsetX: offsetX,
                offsetY: offsetY,
              ),
            if (state.lastMoveToX != null && state.lastMoveToY != null)
              _buildHighlight(
                x: isReversed ? (state.lastMoveToX! - 1) : (9 - state.lastMoveToX!),
                y: isReversed ? (9 - state.lastMoveToY!) : (state.lastMoveToY! - 1),
                color: Colors.red.withOpacity(0.4),
                cellSizeW: cellSizeW,
                cellSizeH: cellSizeH,
                offsetX: offsetX,
                offsetY: offsetY,
              ),

            ...pieces,
          ],
        );
      },
    );
  }

  Widget _buildHighlight({
    required int x,
    required int y,
    required Color color,
    required double cellSizeW,
    required double cellSizeH,
    required double offsetX,
    required double offsetY,
  }) {
    return Positioned(
      left: offsetX + x * cellSizeW,
      top: offsetY + y * cellSizeH,
      width: cellSizeW,
      height: cellSizeH,
      child: Container(
        margin: const EdgeInsets.all(1.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
