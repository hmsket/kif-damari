import 'dart:io';
import 'package:flutter/material.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:kifdamari/logic/kif_parser.dart'; // パスを確認
import 'package:kifdamari/models/kif_tree.dart';
import 'package:kifdamari/widgets/kif_board.dart';

class KifViewerPage extends StatefulWidget {
  final String? kifPath;

  const KifViewerPage({super.key, required this.kifPath});

  @override
  State<KifViewerPage> createState() => _KifViewerPageState();
}

class _KifViewerPageState extends State<KifViewerPage> {
  KifTree? kifTree; // ロード完了までnullを許容
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initKifData();
  }

/// ファイルの読み込みと解析
  Future<void> _initKifData() async {
    // パスがない場合は初期盤面を表示
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
        // 1. バイナリとして読み込む
        final bytes = await file.readAsBytes();
        
        // 2. Shift_JIS(CP932)でデコード（charset_converterパッケージを使用）
        final content = await CharsetConverter.decode("Shift_JIS", bytes);

        // 3. パーサーで解析してツリーを生成
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
      // エラー時は初期盤面を表示してユーザーに知らせる
      setState(() {
        kifTree = KifTree.initial();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ロード中はインジケーターを表示（late初期化エラー防止）
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

            // --- 将棋盤エリア ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: AspectRatio(
                aspectRatio: 0.93,
                child: GestureDetector(
                  // 盤面がタップされた時の処理
                  onTapUp: (details) {
                    // RenderBoxを使って、将棋盤の中での相対的な位置を取得
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    
                    final localPos = details.localPosition;
                    final halfWidth = box.size.width / 2;

                    setState(() {
                      if (localPos.dx > halfWidth) {
                        kifTree!.stepNext(); // 右側なら進む
                      } else {
                        kifTree!.stepBack(); // 左側なら戻る
                      }
                    });
                  },
                  child: KifBoard(state: kifTree!.currentNode.state),
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

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      color: Colors.brown[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: () => setState(() {
              while (kifTree!.currentNode.parent != null) {
                kifTree!.stepBack();
              }
            }),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            iconSize: 36,
            onPressed: () => setState(() {
              kifTree!.stepBack();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            iconSize: 36,
            onPressed: () => setState(() {
              kifTree!.stepNext();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: () => setState(() {
              while (kifTree!.currentNode.nextNodes.isNotEmpty) {
                kifTree!.stepNext();
              }
            }),
          ),
          IconButton(
            icon: const Icon(Icons.cached),
            onPressed: () {
              // 盤面反転フラグなどの管理をここでする予定
            },
          ),
          PopupMenuButton<String>(
            // 1. アイコンの設定
            icon: const Icon(Icons.more_vert),
            
            // 2. 表示位置の調整（ボタンの「上」に出るようにマイナスの値を指定）
            // 項目数に合わせて数値を調整してください（例: 3項目なら -160 くらい）
            offset: const Offset(0, -160), 
            
            // 3. メニューの外観（プルダウンらしい装飾）
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 8,
            
            onSelected: (String value) {
              // タップされた時の処理
              switch (value) {
                case 'reverse': /* 反転処理 */ break;
                case 'copy':    /* コピー処理 */ break;
                case 'share':   /* 共有処理 */ break;
              }
            },
            
            // 4. リストの中身（ずらっと並べる項目）
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
      // 駒が大きくなるので、高さを少し広げる（例: 50〜60px程度）
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Row(
        children: [
          if (!isSente) ...[
            _buildNameLabel(playerName, isSente),
            const SizedBox(width: 8),
          ],
          // 駒台を Expanded で広げる
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
            // 駒の画像（22 * 1.4 ≒ 31）
            Image.asset(
              'assets/images/pieces/$assetPrefix${entry.key}.png',
              width: 31,
              height: 31,
              fit: BoxFit.contain,
            ),
            // 枚数バッジ
            if (entry.value > 1)
              Positioned(
                right: -2, // 少し外側に出すと駒が見えやすくなります
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
