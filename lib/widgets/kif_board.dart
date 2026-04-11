import 'package:flutter/material.dart';

const Map<String, String> initialPosition = {
  "9,1": "wya", "8,1": "wke", "7,1": "wgi", "6,1": "wki", "5,1": "wgy",
  "4,1": "wki", "3,1": "wgi", "2,1": "wke", "1,1": "wya",
  "8,2": "whi", "2,2": "wka",
  "9,3": "wfu", "8,3": "wfu", "7,3": "wfu", "6,3": "wfu", "5,3": "wfu",
  "4,3": "wfu", "3,3": "wfu", "2,3": "wfu", "1,3": "wfu",
  "9,7": "bfu", "8,7": "bfu", "7,7": "bfu", "6,7": "bfu", "5,7": "bfu",
  "4,7": "bfu", "3,7": "bfu", "2,7": "bfu", "1,7": "bfu",
  "8,8": "bka", "2,8": "bhi",
  "9,9": "bya", "8,9": "bke", "7,9": "bgi", "6,9": "bki", "5,9": "bgy",
  "4,9": "bki", "3,9": "bgi", "2,9": "bke", "1,9": "bya",
};

class KifBoard extends StatelessWidget {
  const KifBoard({super.key});

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

        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/board.png', fit: BoxFit.fill),
            ),
            ...initialPosition.entries.map((entry) {
              final coords = entry.key.split(',');
              final int x = int.parse(coords[0]);
              final int y = int.parse(coords[1]);
              return Positioned(
                left: offsetX + (9 - x) * cellSizeW,
                top: offsetY + (y - 1) * cellSizeH,
                width: cellSizeW,
                height: cellSizeH,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Image.asset('assets/images/pieces/${entry.value}.png', fit: BoxFit.contain),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildPiece(int x, int y, String name, double w, double h) {
    return Positioned(
      left: (9 - x) * w,
      top: (y - 1) * h,
      width: w,
      height: h,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Image.asset(
          'assets/images/pieces/$name.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
