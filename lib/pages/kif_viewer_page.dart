import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 触覚フィードバック用
import 'package:charset_converter/charset_converter.dart';
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/models/kif_tree.dart';
import 'package:kifdamari/widgets/kif_board.dart';

class KifViewerPage extends StatefulWidget {
  final String? kifPath;

  const KifViewerPage({super.key, required this.kifPath});

  @override
  State<KifViewerPage> createState() => _KifViewerPageState();
}

class _KifViewerPageState extends State<KifViewerPage> {
  KifTree? kifTree;
  bool _isLoading = true;
  bool _isSeeking = false; // 長押しシーク中フラグ
  double _dragStartX = 0.0; // ドラッグ開始時の指の位置
  int _dragStartMoveNumber = 0; // ドラッグ開始時の手数

  @override
  void initState() {
    super.initState();
    _initKifData();
  }

  /// ファイルの読み込みと解析
  Future<void> _initKifData() async {
    if (widget.kifPath == null) {
      setState(() {
        kifTree = KifTree.initial();
        _isLoading = false;
      });
      return;
    }

    try {
      final file = File(widget.kifPath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final content = await CharsetConverter.decode("Shift_JIS", bytes);
        final tree = KifParser.decode(content);

        setState(() {
          kifTree = tree;
          _isLoading = false;
        });
      } else {
        throw Exception("ファイルが見つかりません");
      }
    } catch (e) {
      debugPrint("KIF解析エラー: $e");
      setState(() {
        kifTree = KifTree.initial();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || kifTree == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.orange[50],
      body: SafeArea(
        child: Column(
          children: [
            // --- 後手エリア ---
            _buildPlayerAndKomaDai(playerName: "後手", isSente: false),

            // --- 将棋盤エリア（Stackでシークバーを重ねる） ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: AspectRatio(
                aspectRatio: 0.93,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    GestureDetector(
                      onLongPressStart: (details) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _isSeeking = true;
                          // 1. 開始時の指の位置と現在の手数を記録
                          _dragStartX = details.localPosition.dx;
                          _dragStartMoveNumber = kifTree!.currentNode.moveNumber;
                        });
                      },
                      onLongPressMoveUpdate: (details) {
                        // 2. 指がどれくらい動いたか（距離）を計算
                        double deltaX = details.localPosition.dx - _dragStartX;
                        
                        // 3. 感度の調整（例：10ピクセル動くごとに1手進む）
                        int sensitivity = 3; 
                        int moveOffset = (deltaX / sensitivity).toInt();
                        
                        // 4. 開始時の手数にオフセットを足してジャンプ
                        setState(() {
                          kifTree!.jumpTo(_dragStartMoveNumber + moveOffset);
                        });
                      },
                      // 指を離すと非表示
                      onLongPressEnd: (_) => setState(() => _isSeeking = false),
                      onTapUp: (details) {
                        if (_isSeeking) return; // シーク中はタップ無効

                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final halfWidth = box.size.width / 2;

                        setState(() {
                          if (details.localPosition.dx > halfWidth) {
                            kifTree!.stepNext();
                          } else {
                            kifTree!.stepBack();
                          }
                        });
                      },
                      child: KifBoard(state: kifTree!.currentNode.state),
                    ),

                    // 長押し中だけ表示されるフローティングシークバー
                    if (_isSeeking) _buildFloatingSeekBar(),
                  ],
                ),
              ),
            ),

            // --- 先手エリア ---
            _buildPlayerAndKomaDai(playerName: "先手", isSente: true),

            // --- 棋譜コメントエリア ---
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.brown[200]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    "【${kifTree!.currentNode.moveNumber}手目】 ${kifTree!.currentNode.moveLabel ?? '開始局面'}\n\n${kifTree!.currentNode.comment}",
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ),
            ),

            // --- 操作パネル ---
            _buildControlPanel(),
          ],
        ),
      ),
    );
  }

/// 長押し時に出現するシークバー（白透過デザイン）
  Widget _buildFloatingSeekBar() {
    final int total = kifTree!.totalMoveCount;
    final int current = kifTree!.currentNode.moveNumber;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      width: MediaQuery.of(context).size.width * 0.85,
      decoration: BoxDecoration(
        // ★ ここを白の透過に変更（0.3〜0.5くらいがお好み）
        color: Colors.white.withOpacity(0.4), 
        borderRadius: BorderRadius.circular(40),
        // 少し影をつけると、白い盤面の上でも境界がはっきりします
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
        // 枠線を少し入れるとさらに高級感が出ます
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          // ★ 文字色を黒系に
          Text(
            "$current", 
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)
          ),
          Expanded(
            child: Slider(
              value: current.toDouble().clamp(0, total.toDouble()),
              min: 0,
              max: total.toDouble(),
              activeColor: Colors.orange[700], // スライダーの色を少し濃いめに
              inactiveColor: Colors.black12,   // 背景スライダーは薄い黒
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() {
                  kifTree!.jumpTo(value.toInt());
                });
              },
            ),
          ),
          // ★ 文字色を黒系に
          Text(
            "$total", 
            style: const TextStyle(color: Colors.black54, fontSize: 12)
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      color: Colors.brown[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: () => setState(() => kifTree!.jumpTo(0)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            iconSize: 36,
            onPressed: () => setState(() => kifTree!.stepBack()),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            iconSize: 36,
            onPressed: () => setState(() => kifTree!.stepNext()),
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: () => setState(() => kifTree!.jumpTo(kifTree!.totalMoveCount)),
          ),
          IconButton(
            icon: const Icon(Icons.cached),
            onPressed: () {
              // 盤面反転フラグの実装箇所
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            offset: const Offset(0, -160),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 8,
            onSelected: (String value) {
              // 共有やコピーのロジックをここに書く
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'reverse',
                child: ListTile(
                  leading: Icon(Icons.cached, size: 20),
                  title: Text('盤面を反転'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: ListTile(
                  leading: Icon(Icons.copy, size: 20),
                  title: Text('棋譜をコピー'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share, size: 20),
                  title: Text('棋譜を共有'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPlayerAndKomaDai({required String playerName, required bool isSente}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Row(
        children: [
          if (!isSente) ...[
            _buildNameLabel(playerName, isSente),
            const SizedBox(width: 8),
          ],
          Expanded(child: _buildPieceStand(isSente)),
          if (isSente) ...[
            const SizedBox(width: 8),
            _buildNameLabel(playerName, isSente),
          ],
        ],
      ),
    );
  }

  Widget _buildPieceStand(bool isSente) {
    final hand = isSente ? kifTree!.currentNode.state.senteHand : kifTree!.currentNode.state.goteHand;
    final assetPrefix = isSente ? "b" : "w";

    if (hand.isEmpty || hand.values.every((count) => count == 0)) {
      return Align(
        alignment: isSente ? Alignment.centerLeft : Alignment.centerRight,
        child: Text("持駒なし", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
      );
    }

    return Wrap(
      alignment: isSente ? WrapAlignment.start : WrapAlignment.end,
      spacing: 1.0,
      runSpacing: 1.0,
      children: hand.entries.where((e) => e.value > 0).map((entry) {
        return Stack(
          alignment: Alignment.bottomRight,
          children: [
            Image.asset(
              'assets/images/pieces/$assetPrefix${entry.key}.png',
              width: 31,
              height: 31,
              fit: BoxFit.contain,
            ),
            if (entry.value > 1)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red, width: 0.5),
                  ),
                  child: Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildNameLabel(String name, bool isSente) {
    return Text("${isSente ? '▲' : '△'}$name",
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold));
  }
}
