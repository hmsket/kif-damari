import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/board_state.dart'; // パスはプロジェクトに合わせて調整してください

class DiagramGenerator {
  /// 9x9の盤面のみを白黒PNG画像として生成する
 static Future<ui.Image> generate(BoardState state) async {
    const double boardSize = 900.0; // 盤面自体のサイズ
    const double margin = 20.0;     // ★追加：外側の余白サイズ
    const double totalSize = boardSize + (margin * 2); // ★全体のサイズ
    
    const double cellSize = boardSize / 9;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 1. 背景を白で塗りつぶす (全体のサイズで)
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, totalSize, totalSize), bgPaint);

    // ★重要：これ以降の描画をすべて余白分だけ右下にずらす
    canvas.translate(margin, margin);

    // 1. 直近の着手マスをハイライト (BoardState内の情報を直接使用)
    if (state.lastMoveToX != null && state.lastMoveToY != null) {
      final highlightPaint = Paint()
        ..color = Colors.red.withOpacity(0.25)
        ..style = PaintingStyle.fill;

      // 盤面のインデックス計算 (BoardStateの movePiece 内のロジックと合わせる)
      // BoardState では toY-1, 9-toX を使っているので、それに準拠します
      double hX = (9 - state.lastMoveToX!) * cellSize;
      double hY = (state.lastMoveToY! - 1) * cellSize;

      canvas.drawRect(
        Rect.fromLTWH(hX, hY, cellSize, cellSize),
        highlightPaint,
      );
    }

    // 2. 枠線を描く (ここは 0,0 から boardSize でOK。translate されているので)
    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 6.0 // ★外枠をさらに太く（3.0 -> 6.0）
      ..style = PaintingStyle.stroke;

    // 外枠の描画
    canvas.drawRect(const Rect.fromLTWH(0, 0, boardSize, boardSize), linePaint);

    // 内側の格子線
    linePaint.strokeWidth = 2.5; // ★内側の線も少し太く（1.0 -> 2.5）
    for (int i = 1; i < 9; i++) {
      // 縦線
      canvas.drawLine(Offset(cellSize * i, 0), Offset(cellSize * i, boardSize), linePaint);
      // 横線
      canvas.drawLine(Offset(0, cellSize * i), Offset(boardSize, cellSize * i), linePaint);
    }

    final starPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // 3・6・9の交点（インデックス的には3マス目と6マス目）
    final List<double> starPositions = [cellSize * 3, cellSize * 6];
    for (var py in starPositions) {
      for (var px in starPositions) {
        canvas.drawCircle(Offset(px, py), 12.0, starPaint); // 半径8.0くらいの円
      }
    }

    // 3. 駒を描画する
    for (int y = 0; y < 9; y++) {
      for (int x = 0; x < 9; x++) {
        final String? pieceName = state.grid[y][x];
        if (pieceName != null && pieceName.trim().isNotEmpty) {
          final isSente = pieceName.startsWith('b');
          final pieceText = _convertPieceToKanji(pieceName);
          _drawPiece(canvas, pieceText, x, y, cellSize, isSente);
        }
      }
    }

    final picture = recorder.endRecording();
    // ★画像として切り出すサイズを totalSize に変更
    return await picture.toImage(totalSize.toInt(), totalSize.toInt());
  }

  static void _drawPiece(Canvas canvas, String text, int x, int y, double cellSize, bool isSente) {
    String visualText = text.isEmpty ? "?" : text;

    final centerX = x * cellSize + cellSize / 2;
    final centerY = y * cellSize + cellSize / 2;

    final textPainter = TextPainter(
      text: TextSpan(
        text: visualText,
        style: GoogleFonts.notoSansJp(
          color: Colors.black,
          fontSize: cellSize * 0.8,
          fontWeight: FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout(minWidth: 0, maxWidth: cellSize);

    canvas.save();
    canvas.translate(centerX, centerY);

    if (!isSente) {
      canvas.rotate(3.14159); // 後手回転
    }

    // textPainter.width と height を使って、
    // 描画開始点を「中心から半分戻った位置」に正確に指定します。
    double verticalAdjustment = cellSize * 0.05; // 0.05〜0.08 くらいで微調整
    
    final offset = Offset(
      -textPainter.width / 2, 
      (-textPainter.height / 2) - verticalAdjustment // マイナスすることで上に移動
    );
    
    textPainter.paint(canvas, offset);

    canvas.restore();
  }

  static String _convertPieceToKanji(String pieceId) {
    if (pieceId.isEmpty) return '';
    
    // 先頭の 'b' や 'w' を除いた「駒種」の部分だけを抽出
    // pieceId が 'bFU' なら 'FU' に、'FU' ならそのまま 'FU' になります
    final id = pieceId.length > 1 && (pieceId.startsWith('b') || pieceId.startsWith('w'))
        ? pieceId.substring(1).toUpperCase().trim() 
        : pieceId.toUpperCase().trim();

    switch (id) {
      case 'FU': return '歩'; case 'TO': return 'と';
      case 'YA': return '香'; case 'NY': return '杏';
      case 'KE': return '桂'; case 'NK': return '圭';
      case 'GI': return '銀'; case 'NG': return '全';
      case 'KI': return '金';
      case 'KA': return '角'; case 'UM': return '馬';
      case 'HI': return '飛'; case 'RY': return '龍';
      case 'OU': case 'GY': return '玉';
      default: 
        // 変換できなかった場合は、IDの先頭1文字を出す（空文字にしない）
        return id.isNotEmpty ? id[0] : '?';
    }
  }
}
