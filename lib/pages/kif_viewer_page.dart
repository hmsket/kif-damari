import 'dart:io';
import 'dart:ui' as ui; // 追加
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:charset_converter/charset_converter.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/models/kif_tree.dart';
import 'package:kifdamari/widgets/kif_board.dart';
import 'package:kifdamari/database/entity/kif_entity.dart'; // 追加
import 'package:kifdamari/logic/diagram_generator.dart'; // 追加
import 'package:kifdamari/logic/thumbnail_manager.dart';
import 'package:path_provider/path_provider.dart'; // 追加

import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class KifViewerPage extends StatefulWidget {
  final KifEntity kifEntity; // String? kifPath から変更

  const KifViewerPage({super.key, required this.kifEntity});

  @override
  State<KifViewerPage> createState() => _KifViewerPageState();
}

class _KifViewerPageState extends State<KifViewerPage> {
  KifTree? kifTree;
  bool _isLoading = true;
  bool _isSeeking = false; 
  double _dragStartX = 0.0; 
  int _dragStartMoveNumber = 0; 

  @override
  void initState() {
    super.initState();
    _initKifData();
  }

  Future<void> _initKifData() async {
    final String? path = widget.kifEntity.kifPath; // 変更
    if (path == null) {
      setState(() {
        kifTree = KifTree.initial();
        _isLoading = false;
      });
      return;
    }

    try {
      final file = File(path); // 変更
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

  // サムネイル生成とDB更新の実体メソッド
  Future<void> _handleMakeThumbnail() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('サムネイル画像を生成中...'), duration: Duration(seconds: 1)),
    );

    try {
      // 1. Canvasで画像を生成
      // lib/pages/kif_viewer_page.dart 内の _handleMakeThumbnail
      final uiImage = await DiagramGenerator.generate(
        kifTree!.currentNode.state,
      );

      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        
        // 2. ThumbnailManagerを使用して物理ファイルを保存
        final savedPath = await ThumbnailManager.saveThumbnail(
          widget.kifEntity.tabId, 
          widget.kifEntity.kifId, 
          pngBytes
        );

        // 3. KifEntityのimgPathを更新した新しいインスタンスを作成
        // KifEntityにcopyWithがない場合は、全ての引数を渡して再生成します
        final updatedKif = KifEntity(
          id: widget.kifEntity.id,
          tabId: widget.kifEntity.tabId,
          kifId: widget.kifEntity.kifId,
          title: widget.kifEntity.title,
          detail: widget.kifEntity.detail,
          kifOrder: widget.kifEntity.kifOrder,
          kifPath: widget.kifEntity.kifPath,
          imgPath: savedPath, // ここに新しいパスをセット
          color: widget.kifEntity.color,
        );

        // 4. KifDaoを使用してデータベースを更新
        await KifDao().updateKif(updatedKif);

        debugPrint("DB更新完了: $savedPath");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('サムネイルを更新しました')),
        );
      }
    } catch (e) {
      debugPrint("図面生成エラー: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像の生成に失敗しました')),
      );
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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPressStart: (details) {
          HapticFeedback.mediumImpact(); 
          setState(() {
            _isSeeking = true;
            _dragStartX = details.localPosition.dx;
            _dragStartMoveNumber = kifTree!.currentNode.moveNumber;
          });
        },
        onLongPressMoveUpdate: (details) {
          if (!_isSeeking) return;
          double deltaX = details.localPosition.dx - _dragStartX;
          int sensitivity = 3; 
          int moveOffset = (deltaX / sensitivity).toInt();
          
          setState(() {
            kifTree!.jumpTo(_dragStartMoveNumber + moveOffset);
          });
        },
        onLongPressEnd: (_) => setState(() => _isSeeking = false),
        child: SafeArea(
          child: Column(
            children: [
              _buildPlayerAndKomaDai(playerName: "後手", isSente: false),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AspectRatio(
                  aspectRatio: 0.93,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      GestureDetector(
                        onTapUp: (details) {
                          if (_isSeeking) return;
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
                      if (_isSeeking) _buildFloatingSeekBar(),
                    ],
                  ),
                ),
              ),
              _buildPlayerAndKomaDai(playerName: "先手", isSente: true),
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
              _buildControlPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingSeekBar() {
    final int total = kifTree!.totalMoveCount;
    final int current = kifTree!.currentNode.moveNumber;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      width: MediaQuery.of(context).size.width * 0.85,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Row(
        children: [
          Text(
            "$current",
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Slider(
              value: current.toDouble().clamp(0, total.toDouble()),
              min: 0,
              max: total.toDouble(),
              activeColor: Colors.orange[700],
              inactiveColor: Colors.black12,
              onChanged: (_) {},
            ),
          ),
          Text(
            "$total",
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }

Widget _buildControlPanel() {
    // テーマ色の取得
    final colorScheme = Theme.of(context).colorScheme;
    double _dragDistance = 0;

    return Container(
      color: const Color(0XFFF1F1F5),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), // 全体の余白調整
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
          GestureDetector(
            // ドラッグ中の処理
            onVerticalDragUpdate: (details) {
              // dyは移動量（上ならマイナス、下ならプラス）
              _dragDistance += details.delta.dy;

              // しきい値（10ピクセル移動するごとに1手動かす例）
              const double threshold = 10.0;

              if (_dragDistance <= -threshold) {
                // 上に20px分ドラッグされたら一手進む
                setState(() {
                  kifTree!.stepNext();
                  _dragDistance = 0; // 蓄積をリセット
                });
              } else if (_dragDistance >= threshold) {
                // 下に20px分ドラッグされたら一手戻る
                setState(() {
                  kifTree!.stepBack();
                  _dragDistance = 0; // 蓄積をリセット
                });
              }
            },
            // 指を離した時に蓄積をクリア（これをしないと、次に触れた瞬間に動くことがある）
            onVerticalDragEnd: (_) => _dragDistance = 0,
            
            child: SizedBox(
              width: 90,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black45, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${kifTree!.currentNode.moveNumber}手目\n${kifTree!.currentNode.moveLabel!.replaceAll(RegExp(r'\(.*\)'), '')}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black,
                    height: 1.2,
                  ),
                ),
              ),
            ),
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
          // --- メニューボタンなどの既存ボタン群 ---
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            offset: const Offset(0, -220),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 8,
            onSelected: (String value) {
              switch (value) {
                case 'make_thumbnail': _handleMakeThumbnail(); break;
                case 'share_thumbnail': _shareThumbnail(); break;
                // 他のケースも必要に応じて追加
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem( // 追加
                value: 'make_thumbnail',
                child: ListTile(
                  leading: Icon(Icons.collections, size: 20),
                  title: Text('サムネイルにする'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),              
              const PopupMenuItem( // 追加
                value: 'share_thumbnail',
                child: ListTile(
                  leading: Icon(Icons.share, size: 20),
                  title: Text('共有する'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
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
          ),
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

  Future<void> _shareThumbnail() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      // パスは前回のものと同じ
      final path = '${appDir.path}/thumbnails/thumb_${widget.kifEntity.tabId}_${widget.kifEntity.kifId}.png';
      final file = File(path);

      if (await file.exists()) {
        await Share.shareXFiles([XFile(path)], text: '\n#棋譜だまり');
      } else {
        debugPrint("ファイルが見つかりません: $path");
      }
    } catch (e) {
      debugPrint("共有失敗: $e");
    }
  }
}
