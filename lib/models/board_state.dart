enum Player { sente, gote }

class BoardState {
  final List<List<String?>> grid;
  final Map<String, int> senteHand;
  final Map<String, int> goteHand;
  final Player nextPlayer;

  final int? lastMoveToX;
  final int? lastMoveToY;

  BoardState({
    required this.grid,
    required this.senteHand,
    required this.goteHand,
    required this.nextPlayer,
    this.lastMoveToX,
    this.lastMoveToY,
  });

  factory BoardState.initial() {
    List<List<String?>> initialGrid = List.generate(
      9,
      (_) => List<String?>.filled(9, null),
    );

    initialGrid[0][0] = 'wya'; initialGrid[0][1] = 'wke'; initialGrid[0][2] = 'wgi';
    initialGrid[0][3] = 'wki'; initialGrid[0][4] = 'wgy'; initialGrid[0][5] = 'wki';
    initialGrid[0][6] = 'wgi'; initialGrid[0][7] = 'wke'; initialGrid[0][8] = 'wya';
    initialGrid[1][1] = 'whi'; initialGrid[1][7] = 'wka';
    for (int i = 0; i < 9; i++) {
      initialGrid[2][i] = 'wfu';
    }

    // 先手 (Black) 
    initialGrid[8][0] = 'bya'; initialGrid[8][1] = 'bke'; initialGrid[8][2] = 'bgi';
    initialGrid[8][3] = 'bki'; initialGrid[8][4] = 'bgy'; initialGrid[8][5] = 'bki';
    initialGrid[8][6] = 'bgi'; initialGrid[8][7] = 'bke'; initialGrid[8][8] = 'bya';
    initialGrid[7][1] = 'bka'; initialGrid[7][7] = 'bhi';
    for (int i = 0; i < 9; i++) {
      initialGrid[6][i] = 'bfu';
    }

    return BoardState(
      grid: initialGrid,
      senteHand: {},
      goteHand: {},
      nextPlayer: Player.sente,
      lastMoveToX: null,
      lastMoveToY: null,
    );
  }

  BoardState movePiece({
    int? fromX,
    int? fromY,
    required int toX,
    required int toY,
    required String pieceName,
  }) {
    // 現在の盤面をディープコピー
    List<List<String?>> newGrid = grid.map((row) => List<String?>.from(row)).toList();
    
    // 持ち駒もコピーしておく
    Map<String, int> newSenteHand = Map<String, int>.from(senteHand);
    Map<String, int> newGoteHand = Map<String, int>.from(goteHand);

    // --- 駒を取る処理 ---
    final targetPiece = newGrid[toY - 1][9 - toX]; // 移動先にある駒
    if (targetPiece != null) {
      // 駒の頭文字（b/w）を除去して、純粋な駒種（fu, kiなど）を取得
      // また、成駒（to, ny等）を取った場合は、元の駒（fu, ky等）に戻す必要がある
      String capturedTypeCode = _getRawPieceType(targetPiece.substring(1));
      
      if (nextPlayer == Player.sente) {
        // 先手が取った場合：senteHandを増やす
        newSenteHand[capturedTypeCode] = (newSenteHand[capturedTypeCode] ?? 0) + 1;
      } else {
        // 後手が取った場合：goteHandを増やす
        newGoteHand[capturedTypeCode] = (newGoteHand[capturedTypeCode] ?? 0) + 1;
      }
    }

    // --- 駒の移動処理 ---
    if (fromX != null && fromY != null) {
      // 盤上からの移動：元いた場所を空にする
      newGrid[fromY - 1][9 - fromX] = null;
    } else {
      // 持ち駒を打つ場合：持ち駒を1つ減らす
      String rawType = _convertToAssetCode(pieceName);
      if (nextPlayer == Player.sente) {
        newSenteHand[rawType] = (newSenteHand[rawType] ?? 1) - 1;
      } else {
        newGoteHand[rawType] = (newGoteHand[rawType] ?? 1) - 1;
      }
    }

    // 移動先に自分の駒を置く
    String assetPrefix = (nextPlayer == Player.sente ? "b" : "w");
    String assetCode = _convertToAssetCode(pieceName);
    newGrid[toY - 1][9 - toX] = assetPrefix + assetCode;

    return BoardState(
      grid: newGrid,
      senteHand: newSenteHand,
      goteHand: newGoteHand,
      nextPlayer: nextPlayer == Player.sente ? Player.gote : Player.sente,
      lastMoveToX: toX,
      lastMoveToY: toY,
    );
  }

  // 成駒を取った時に元の駒に戻すためのヘルパー
  String _getRawPieceType(String code) {
    switch (code) {
      case 'to': return 'fu';
      case 'ny': return 'ky';
      case 'nk': return 'ke';
      case 'ng': return 'gi';
      case 'um': return 'ka';
      case 'ry': return 'hi';
      default: return code; // 成っていない駒はそのままでOK
    }
  }

  String _convertToAssetCode(String kanji) {
    // 1. まず「成」が含まれているかチェック（飛成、銀成など）
    if (kanji.contains("成")) {
      if (kanji.contains("飛")) return "ry";
      if (kanji.contains("角")) return "um";
      if (kanji.contains("銀")) return "ng";
      if (kanji.contains("桂")) return "nk";
      if (kanji.contains("香")) return "ny";
      if (kanji.contains("歩")) return "to";
    }

    // 2. 「成」という文字はないが、成駒の漢字単体の場合（竜、馬、と、全...）
    if (kanji.contains("龍") || kanji.contains("竜")) return "ry";
    if (kanji.contains("馬")) return "um";
    if (kanji.contains("全")) return "ng";
    if (kanji.contains("圭")) return "nk";
    if (kanji.contains("杏")) return "ny";
    if (kanji.contains("と")) return "to";

    // 3. 通常の駒
    if (kanji.contains("飛")) return "hi";
    if (kanji.contains("角")) return "ka";
    if (kanji.contains("銀")) return "gi";
    if (kanji.contains("桂")) return "ke";
    if (kanji.contains("香")) return "ya";
    if (kanji.contains("歩")) return "fu";
    if (kanji.contains("金")) return "ki";
    if (kanji.contains("王") || kanji.contains("玉")) return "gy";

    return "fu";
  }
}
