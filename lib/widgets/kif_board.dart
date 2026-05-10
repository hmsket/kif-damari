import 'package:flutter/material.dart';
import '../models/board_state.dart';

class KifBoard extends StatelessWidget {
  final BoardState state;
  final bool isReversed; // ★ 追加

  const KifBoard({
    super.key,
    required this.state,
    this.isReversed = false, // ★ 追加（デフォルトは通常表示）
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

              // ★ 駒の画像名を決定するロジック
              String finalPieceName = pieceName;
              if (isReversed) {
                // bで始まるならwに、wで始まるならbに入れ替える
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
                    // ★ RotatedBox を削除し、finalPieceName を使用
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
            // 1. 盤面画像
            Positioned.fill(
              child: Image.asset('assets/images/board.png', fit: BoxFit.fill),
            ),

            // 2. ハイライトレイヤー（座標計算に isReversed を適用）
            if (state.lastMoveFromX != null && state.lastMoveFromY != null)
              _buildHighlight(
                // 内部座標系 x: 9-筋(1~9), y: 段(1~9) を 0~8 インデックスに変換
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

            // 3. 駒レイヤー
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
