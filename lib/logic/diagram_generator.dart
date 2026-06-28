import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kifdamari/models/board_state.dart';

class DiagramGenerator {
  static const double _boardSize = 900.0;
  static const double _margin = 20.0;
  static const double _totalSize = _boardSize + (_margin * 2);
  static const double _cellSize = _boardSize / 9;

  static Future<ui.Image> generate(BoardState state, {bool highlightLastMove = true}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 背景を白で塗りつぶす
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, _totalSize, _totalSize), bgPaint);

    // これ以降の描画をすべて余白分だけ右下にずらす
    canvas.translate(_margin, _margin);

    // 各要素を順番に描画
    _drawLastMoveHighlight(canvas, state, highlightLastMove: highlightLastMove);
    _drawBoardGrid(canvas);
    _drawStars(canvas);
    _drawPieces(canvas, state);

    final picture = recorder.endRecording();
    return await picture.toImage(_totalSize.toInt(), _totalSize.toInt());
  }

  // 直近の着手マスをハイライト
  static void _drawLastMoveHighlight(Canvas canvas, BoardState state, {required bool highlightLastMove}) {
    if (!highlightLastMove) return;

    if (state.lastMoveToX != null && state.lastMoveToY != null) {
      final highlightPaint = Paint()
        ..color = Colors.red.withOpacity(0.25)
        ..style = PaintingStyle.fill;

      double hX = (9 - state.lastMoveToX!) * _cellSize;
      double hY = (state.lastMoveToY! - 1) * _cellSize;

      canvas.drawRect(
        Rect.fromLTWH(hX, hY, _cellSize, _cellSize),
        highlightPaint,
      );
    }
  }

  // 枠線と内側の格子線を描く
  static void _drawBoardGrid(Canvas canvas) {
    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 6.0 // 外枠をさらに太くする
      ..style = PaintingStyle.stroke;

    // 外枠の描画
    canvas.drawRect(const Rect.fromLTWH(0, 0, _boardSize, _boardSize), linePaint);

    // 内側の格子線
    linePaint.strokeWidth = 2.5; // 内側の線も少し太くする
    for (int i = 1; i < 9; i++) {
      // 縦線
      canvas.drawLine(Offset(_cellSize * i, 0), Offset(_cellSize * i, _boardSize), linePaint);
      // 横線
      canvas.drawLine(Offset(0, _cellSize * i), Offset(_boardSize, _cellSize * i), linePaint);
    }
  }

  // 星を描く
  static void _drawStars(Canvas canvas) {
    final starPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final List<double> starPositions = [_cellSize * 3, _cellSize * 6];
    for (var py in starPositions) {
      for (var px in starPositions) {
        canvas.drawCircle(Offset(px, py), 12.0, starPaint);
      }
    }
  }

  // 全ての駒を描画する
  static void _drawPieces(Canvas canvas, BoardState state) {
    for (int y = 0; y < 9; y++) {
      for (int x = 0; x < 9; x++) {
        final String? pieceName = state.grid[y][x];
        if (pieceName != null && pieceName.trim().isNotEmpty) {
          final isSente = pieceName.startsWith('b');
          final pieceText = _convertPieceToKanji(pieceName);
          _drawPiece(canvas, pieceText, x, y, isSente);
        }
      }
    }
  }

  // 駒1つの描画処理
  static void _drawPiece(Canvas canvas, String text, int x, int y, bool isSente) {
    String visualText = text.isEmpty ? "?" : text;

    final centerX = x * _cellSize + _cellSize / 2;
    final centerY = y * _cellSize + _cellSize / 2;

    final textPainter = TextPainter(
      text: TextSpan(
        text: visualText,
        style: GoogleFonts.notoSansJp(
          color: Colors.black,
          fontSize: _cellSize * 0.8,
          fontWeight: FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout(minWidth: 0, maxWidth: _cellSize);

    canvas.save();
    canvas.translate(centerX, centerY);

    if (!isSente) {
      canvas.rotate(math.pi);
    }

    double verticalAdjustment = _cellSize * 0.05;
    
    final offset = Offset(
      -textPainter.width / 2, 
      (-textPainter.height / 2) - verticalAdjustment
    );
    
    textPainter.paint(canvas, offset);

    canvas.restore();
  }

  // 駒のIDを漢字1文字に変換
  static String _convertPieceToKanji(String pieceId) {
    if (pieceId.isEmpty) return '';
    
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
        return id.isNotEmpty ? id[0] : '?';
    }
  }

  static Future<ui.Image> generateForShare({
    required BoardState state,
    required Map<String, String> info,
    required bool isReversed,
    bool highlightLastMove = true,
  }) async {
    // 盤面を取得
    final ui.Image boardImage = await generate(state, highlightLastMove: highlightLastMove);

    // 画像の全体サイズ・余白の定義
    const double sideAreaWidth = 110.0;
    const double leftPadding = 15.0; 
    const double rightPadding = 15.0;
    
    final double shareWidth = leftPadding + (sideAreaWidth * 2) + _totalSize + rightPadding; 
    final double shareHeight = _totalSize;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 背景を白で塗りつぶす
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, shareWidth, shareHeight), bgPaint);

    // 盤面画像を中央に表示
    canvas.drawImage(boardImage, const Offset(leftPadding + sideAreaWidth, 0), Paint());

    // 対局者名・持駒
    final String originalSente = info['先手'] ?? '先手';
    final String originalGote = info['後手'] ?? '後手';

    final String rightName = isReversed ? originalGote : originalSente;
    final String leftName = isReversed ? originalSente : originalGote;

    final Map<String, int> rightHand = isReversed ? state.goteHand : state.senteHand;
    final Map<String, int> leftHand = isReversed ? state.senteHand : state.goteHand;

    // 先手の持ち駒を表示
    _drawVerticalPlayerInfo(
      canvas: canvas,
      rect: Rect.fromLTWH(leftPadding + sideAreaWidth + _totalSize, 0, sideAreaWidth, shareHeight),
      name: rightName,
      isSente: !isReversed, 
      hand: rightHand,
      rotate180: false, 
    );

    // 後手の持ち駒を表示
    _drawVerticalPlayerInfo(
      canvas: canvas,
      rect: Rect.fromLTWH(leftPadding, 0, sideAreaWidth, shareHeight),
      name: leftName,
      isSente: isReversed, 
      hand: leftHand,
      rotate180: true, 
    );

    final picture = recorder.endRecording();
    return await picture.toImage(shareWidth.toInt(), shareHeight.toInt());
  }
  
  static void _drawVerticalPlayerInfo({
    required Canvas canvas,
    required Rect rect,
    required String name,
    required bool isSente,
    required Map<String, int> hand,
    required bool rotate180,
  }) {
    const pieceLabels = {
      'fu': '歩', 'ya': '香', 'ke': '桂', 'gi': '銀', 
      'ki': '金', 'ka': '角', 'hi': '飛'
    };
    const priorityOrder = ['hi', 'ka', 'ki', 'gi', 'ke', 'ya', 'fu']; 

    final List<MapEntry<String, int>> verticalItems = [];

    verticalItems.add(MapEntry(isSente ? '☗' : '☖', 1));

    bool hasPieces = false;
    for (var key in priorityOrder) {
      final count = hand[key] ?? 0;
      if (count > 0) {
        hasPieces = true;
        verticalItems.add(MapEntry(pieceLabels[key] ?? '', count));
      }
    }
    if (!hasPieces) {
      verticalItems.add(const MapEntry('な', 1));
      verticalItems.add(const MapEntry('し', 1));
    }

    const double baseFontSize = 70.0;
    const double countFontSize = 40.0; 
    const double fontHeight = 1.15;
    const double cellHeight = baseFontSize * fontHeight;
    final double totalTextHeight = verticalItems.length * cellHeight;

    const double boardPullOffset = 20.0; // 盤面側へ引き寄せる距離
    const double textInnerPadding = 0.1;  // 文字セル内のわずかな左余白係数

    double x = rect.left + (rect.width - baseFontSize) / 2;
    double y = 0.0;

    if (rotate180) {
      y = rect.top + _margin;
    } else {
      y = (rect.bottom - _margin) - totalTextHeight;
    }

    canvas.save();
    
    if (rotate180) {
      final centerX = rect.left + rect.width / 2;
      final centerY = y + totalTextHeight / 2;
      canvas.translate(centerX, centerY);
      canvas.rotate(math.pi);
      
      x = -baseFontSize / 2;
      y = -totalTextHeight / 2;
    }

    for (int i = 0; i < verticalItems.length; i++) {
      final item = verticalItems[i];
      final String currentText = item.key;
      final int count = item.value;

      if (currentText.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: currentText,
            style: GoogleFonts.notoSansJp(
              color: Colors.black,
              fontSize: baseFontSize,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final double textX = x + (baseFontSize * textInnerPadding) - boardPullOffset; 
        final double textY = y + (cellHeight - textPainter.height) / 2;

        textPainter.paint(canvas, Offset(textX, textY));

        if (count > 1) {
          final countPainter = TextPainter(
            text: TextSpan(
              text: count.toString(),
              style: GoogleFonts.notoSansJp(
                color: Colors.black,
                fontSize: countFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          final double countX = textX + textPainter.width + 4.0; 
          final double countY = (textY + textPainter.height) - countPainter.height - 4.0;

          countPainter.paint(canvas, Offset(countX, countY));
        }
      }

      y += cellHeight;
    }

    canvas.restore();
  }
}
