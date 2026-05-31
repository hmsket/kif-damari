import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:charset_converter/charset_converter.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/models/kif_tree.dart';
import 'package:kifdamari/widgets/kif_tree_view.dart';
import 'package:kifdamari/widgets/kif_board.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/logic/diagram_generator.dart';
import 'package:kifdamari/logic/thumbnail_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'package:share_plus/share_plus.dart';
import 'package:kifdamari/models/game_node.dart';

class KifViewerPage extends StatefulWidget {
  final KifEntity kifEntity;

  const KifViewerPage({super.key, required this.kifEntity});

  @override
  State<KifViewerPage> createState() => _KifViewerPageState();
}

class _KifViewerPageState extends State<KifViewerPage> {
  KifTree? kifTree;
  bool _isLoading = true;
  bool _isSeeking = false; 
  bool _isReversed = false;
  double _dragStartX = 0.0; 
  int _dragStartMoveNumber = 0; 

  // 🌟 追加：カスタムサイドバーの開閉を管理する状態変数
  bool _isSidebarOpen = false;

  @override
  void initState() {
    super.initState();
    _initKifData();
  }

  Future<void> _initKifData() async {
    final String? path = widget.kifEntity.kifPath;
    if (path == null) {
      setState(() {
        kifTree = KifTree.initial();
        _isLoading = false;
      });
      return;
    }

    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        String content;

        try {
          content = utf8.decode(bytes, allowMalformed: false);
          debugPrint("UTF-8 で読み込みました");
        } catch (_) {
          content = await CharsetConverter.decode("Shift_JIS", bytes);
          debugPrint("Shift-JIS で読み込みました");
        }

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

  Future<void> _handleMakeThumbnail() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('サムネイル画像を生成中...'), duration: Duration(seconds: 1)),
    );

    try {
      final uiImage = await DiagramGenerator.generate(
        kifTree!.currentNode.state,
      );

      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        
        final savedPath = await ThumbnailManager.saveThumbnail(
          widget.kifEntity.tabId, 
          widget.kifEntity.kifId, 
          pngBytes
        );

        final updatedKif = KifEntity(
          id: widget.kifEntity.id,
          tabId: widget.kifEntity.tabId,
          kifId: widget.kifEntity.kifId,
          title: widget.kifEntity.title,
          detail: widget.kifEntity.detail,
          kifOrder: widget.kifEntity.kifOrder,
          kifPath: widget.kifEntity.kifPath,
          imgPath: savedPath,
          color: widget.kifEntity.color,
        );

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

  void _showBranchSelector(List<GameNode> nextNodes) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '次の手を選択してください',
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.brown,
                  ),
                ),
              ),
              const Divider(height: 1),
              ...nextNodes.map((node) {
                final cleanLabel = node.moveLabel!.replaceAll(RegExp(r'\(.*\)'), '');
                return ListTile(
                  leading: const Icon(Icons.navigation_rounded, color: Colors.orange),
                  title: Text(
                    "${node.moveNumber}手目: $cleanLabel",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      kifTree!.stepNext(chosenNode: node);
                    });
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading || kifTree == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 🌟 サイドバーの横幅（画面全体の85%）
    final double sidebarWidth = MediaQuery.of(context).size.width * 0.85;
    // このメソッド、または build メソッド内の上部でコントローラーを宣言してください。
    final ScrollController _commentScrollController = ScrollController();

    return Scaffold(
      // backgroundColor: Colors.orange[50],
      // 🌟 endDrawer は競合を避けるために完全に削除し、Stackによるカスタムドロワーに移行します。
      body: Stack(
        children: [
          // 1. 【メインコンテンツ】将棋盤やコントロールパネル一式
          GestureDetector(
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
                  // --- 上側のエリア ---
                  _buildPlayerAndKomaDai(
                    playerName: _isReversed ? (kifTree!.info['先手'] ?? '先手') : (kifTree!.info['後手'] ?? '後手'),
                    isSente: _isReversed, 
                    isUpper: true,
                  ),
                  // --- 盤面エリア ---
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
                            child: KifBoard(
                              state: kifTree!.currentNode.state,
                              isReversed: _isReversed,
                            ),
                          ),
                          if (_isSeeking) _buildFloatingSeekBar(),
                        ],
                      ),
                    ),
                  ),
                  // --- 下側のエリア ---
                  _buildPlayerAndKomaDai(
                    playerName: _isReversed ? (kifTree!.info['後手'] ?? '後手') : (kifTree!.info['先手'] ?? '先手'),
                    isSente: !_isReversed,
                    isUpper: false,
                  ),
                 // 【重要】もしクラスの上部（Stateの中など）に定義していない場合は、
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                        // border: Border.all(color: Colors.brown[200]!),
                      ),
                      // ★ Container の child の直下を Scrollbar にします
                      child: Scrollbar(
                        controller: _commentScrollController, // コントローラーを紐付け
                        thumbVisibility: true,               // 常にバーを表示（お好みで false でもOK）
                        child: SingleChildScrollView(
                          controller: _commentScrollController, // スクロールビュー側にも同じものを渡す
                          child: Text(
                            "${kifTree!.currentNode.joinedComment}",
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildControlPanel(),
                ],
              ),
            ),
          ),

          // 2. 【暗幕レイヤー】サイドバーが開いている時にメイン画面をじんわり暗くし、タップで閉じる機能
          if (_isSidebarOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isSidebarOpen = false;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
            ),

          // 3. 【カスタムサイドバー本体】アニメーションスライドイン
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            right: _isSidebarOpen ? 0 : -sidebarWidth, // 画面外か、画面の右端ぴったりか
            top: 0,
            bottom: 0,
            width: sidebarWidth,
            child: Material(
              elevation: 16,
              color: Colors.white,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '棋譜ツリー',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown[800]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _isSidebarOpen = false;
                              });
                            },
                          )
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: KifTreeView(
                        rootNode: kifTree!.root,
                        currentNode: kifTree!.currentNode,
                        onNodeSelected: (selectedNode) {
                          setState(() {
                            kifTree!.currentNode = selectedNode;

                            // タップしたノードからルートまで遡り、選択分岐インデックスを同期
                            GameNode? temp = selectedNode;
                            while (temp != null && temp.parent != null) {
                              final parent = temp.parent!;
                              parent.selectedBranchIndex = parent.nextNodes.indexOf(temp);
                              temp = parent;
                            }
                            
                            // 🌟 追加：ノードがタップされて局面移動したら、スッとサイドバーを閉じる
                            _isSidebarOpen = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    final colorScheme = Theme.of(context).colorScheme;
    double dragDistance = 0;

    return Container(
      color: const Color(0XFFF1F1F5),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
            onVerticalDragUpdate: (details) {
              dragDistance += details.delta.dy;
              const double threshold = 10.0;
              if (dragDistance <= -threshold) {
                setState(() {
                  kifTree!.stepNext();
                  dragDistance = 0;
                });
              } else if (dragDistance >= threshold) {
                setState(() {
                  kifTree!.stepBack();
                  dragDistance = 0;
                });
              }
            },
            onVerticalDragEnd: (_) => dragDistance = 0,
            onTap: () {
              final nextNodes = kifTree!.currentNode.nextNodes;
              if (nextNodes.length > 1) {
                _showBranchSelector(nextNodes);
              }
            },
            child: SizedBox(
              width: 90,
              child: Builder(
                builder: (context) {
                  final bool hasBranch = kifTree!.currentNode.nextNodes.length > 1;
                  final bool isInsideBranch = kifTree!.currentNode.parent != null && 
                                              kifTree!.currentNode.parent!.nextNodes.first != kifTree!.currentNode;

                  return GestureDetector(
                    onTap: () {
                      // 🌟 修正：Scaffoldのエンドドロワーではなく、setStateで自作サイドバーのフラグをONにする
                      setState(() {
                        _isSidebarOpen = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      decoration: BoxDecoration(
                        color: hasBranch ? Colors.orange[100] : Colors.white,
                        border: Border.all(
                          color: hasBranch ? Colors.orange[700]! : Colors.black45, 
                          width: hasBranch ? 2.0 : 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${kifTree!.currentNode.moveNumber}手目',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                kifTree!.currentNode.moveLabel!.replaceAll(RegExp(r'\(.*\)'), ''),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                          if (hasBranch)
                            const Positioned(
                              top: -2,
                              right: 0,
                              child: Icon(Icons.alt_route, size: 12, color: Colors.orange),
                            ),
                        ],
                      ),
                    ),
                  );
                }
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
          MenuAnchor(
            alignmentOffset: const Offset(0, 0), 
            style: MenuStyle(
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              elevation: WidgetStateProperty.all(8),
            ),
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.collections, size: 20),
                child: const Text('サムネイルにする'),
                onPressed: () => _handleMakeThumbnail(),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.share, size: 20),
                child: const Text('共有する'),
                onPressed: () => _shareThumbnail(),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.cached, size: 20),
                child: const Text('盤面を反転'),
                onPressed: () {
                  setState(() {
                    _isReversed = !_isReversed;
                  });
                },
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.copy, size: 20),
                child: const Text('棋譜をコピー'),
                onPressed: () {
                  // コピーの処理
                },
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.share, size: 20),
                child: const Text('棋譜を共有'),
                onPressed: () {
                  // 共有の処理
                },
              ),
            ],
            // 💡 三点リーダーのアイコンボタン（トリガー）をここに定義します
            builder: (BuildContext context, MenuController controller, Widget? child) {
              return IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerAndKomaDai({required String playerName, required bool isSente, required bool isUpper}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Row(
        children: [
          if (isUpper) ...[
            _buildNameLabel(playerName, isSente),
            const SizedBox(width: 8),
          ],
          Expanded(child: _buildPieceStand(isSente, isUpper)),
          if (!isUpper) ...[
            const SizedBox(width: 8),
            _buildNameLabel(playerName, isSente),
          ],
        ],
      ),
    );
  }

  Widget _buildPieceStand(bool isSente, bool isUpper) {
    final hand = isSente ? kifTree!.currentNode.state.senteHand : kifTree!.currentNode.state.goteHand;
    final assetPrefix = isUpper ? "w" : "b";

    if (hand.isEmpty || hand.values.every((count) => count == 0)) {
      return Align(
        alignment: isUpper ? Alignment.centerRight : Alignment.centerLeft,
        child: Text("持駒なし", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
      );
    }

    const priorityOrder = ['fu', 'ya', 'ke', 'gi', 'ki', 'ka', 'hi']; 

    var sortedEntries = priorityOrder
        .where((key) => hand.containsKey(key) && (hand[key] ?? 0) > 0)
        .map((key) => MapEntry(key, hand[key]!))
        .toList();

    if (!isSente) {
      sortedEntries = sortedEntries.reversed.toList();
    }

    return Wrap(
      alignment: isUpper ? WrapAlignment.end : WrapAlignment.start,
      spacing: 1.0,
      runSpacing: 1.0,
      children: sortedEntries.map((entry) {
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
