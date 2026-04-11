import 'package:flutter/material.dart';
import '../models/board_state.dart'; // パスは環境に合わせて調整してください

class KifBoard extends StatelessWidget {
  // 外部（Page）から現在の局面を受け取る
  final BoardState state;

  const KifBoard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ... パディングやサイズ計算のロジックはそのまま ...
        final double paddingRate = 0.0125; 
        final double boardWidth = constraints.maxWidth * (1 - paddingRate * 2);
        final double boardHeight = constraints.maxHeight * (1 - paddingRate * 2);
        final double cellSizeW = boardWidth / 9;
        final double cellSizeH = boardHeight / 9;
        final double offsetX = constraints.maxWidth * paddingRate;
        final double offsetY = constraints.maxHeight * paddingRate;

        List<Widget> pieces = [];

        // state.grid (9x9の二次元配列) を走査して駒を配置
        for (int y = 0; y < 9; y++) {
          for (int x = 0; x < 9; x++) {
            final String? pieceName = state.grid[y][x];
            if (pieceName != null) {
              // 将棋の座標系（右上が1,1）に合わせて描画位置を計算
              // 配列のインデックス y(0-8) は 1段目〜9段目に対応
              // 配列のインデックス x(0-8) は 9筋〜1筋に対応
              pieces.add(
                Positioned(
                  // x=0(9筋)なら一番左, x=8(1筋)なら一番右
                  left: offsetX + x * cellSizeW, 
                  top: offsetY + y * cellSizeH,
                  width: cellSizeW,
                  height: cellSizeH,
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Image.asset(
                      'assets/images/pieces/$pieceName.png', 
                      fit: BoxFit.contain
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
            ...pieces,
          ],
        );
      },
    );
  }
}
