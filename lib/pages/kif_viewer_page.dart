import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/logic/saf_helper.dart';
import 'package:kifdamari/models/kif_tree.dart';
import 'package:kifdamari/pages/diagram_preview_page.dart';
import 'package:kifdamari/pages/kif_editor_page.dart';
import 'package:kifdamari/snackbars/show_error_snackbar.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';
import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/kif_tree_view.dart';
import 'package:kifdamari/widgets/kif_board.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/logic/diagram_generator.dart';
import 'package:kifdamari/logic/thumbnail_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kifdamari/models/game_node.dart';

class KifViewerPage extends StatefulWidget {
  final KifEntity kifEntity;

  const KifViewerPage({super.key, required this.kifEntity});

  @override
  State<KifViewerPage> createState() => _KifViewerPageState();
}

class _KifViewerPageState extends State<KifViewerPage> with TickerProviderStateMixin {
  KifTree? kifTree;
  bool _isLoading = true;
  bool _isSeeking = false;
  bool _isReversed = false;
  double _dragStartX = 0.0;
  int _dragStartMoveNumber = 0;
  String? _rawKifContent;

  // 💡 ダイヤル操作用の変数
  double _dialRotation = 0.0;
  double _dialAccumulator = 0.0;
  bool _isOverlayDialActive = false; // コメント欄オーバーレイ表示フラグ
  final GlobalKey _overlayDialKey = GlobalKey();

  late KifEntity _currentKifEntity;

  bool _isSidebarOpen = false;

  final ScrollController _commentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentKifEntity = widget.kifEntity;
    _initKifData();
  }

  @override
  void dispose() {
    _commentScrollController.dispose();
    super.dispose();
  }

  Future<void> _initKifData() async {
    final String? path = _currentKifEntity.kifPath;
    if (path == null || path.isEmpty) {
      setState(() {
        kifTree = KifTree.initial();
        _isLoading = false;
      });
      return;
    }

    try {
      Uint8List? bytes;
      if (path.startsWith('content://')) {
        bytes = await SafHelper.readFileBytes(path);
      } else {
        final file = File(path);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }

      if (bytes != null) {
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
          _rawKifContent = content;
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
    try {
      final uiImage = await DiagramGenerator.generate(
        kifTree!.currentNode.state,
      );

      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();

        final savedPath = await ThumbnailManager.saveThumbnail(
          _currentKifEntity.tabId,
          _currentKifEntity.kifId,
          pngBytes,
        );

        final updatedKif = KifEntity(
          id: _currentKifEntity.id,
          tabId: _currentKifEntity.tabId,
          kifId: _currentKifEntity.kifId,
          title: _currentKifEntity.title,
          detail: _currentKifEntity.detail,
          kifOrder: _currentKifEntity.kifOrder,
          kifPath: _currentKifEntity.kifPath,
          imgPath: savedPath,
          color: _currentKifEntity.color,
        );

        await KifDao().updateKif(updatedKif);
        _currentKifEntity = updatedKif;

        ShowSuccessSnackbar.show(context, "サムネイルを更新しました");
      }
    } catch (e) {
      ShowErrorSnackbar.show(context, "サムネイルの更新に失敗しました");
    }
  }

  Future<void> _shareKifData() async {
    if (kifTree == null) return;

    try {
      final String kifContent = KifParser.encode(kifTree!);
      final List<int> bytes = await CharsetConverter.encode("Shift_JIS", kifContent);

      final tempDir = await getTemporaryDirectory();
      final String fileName = "${_currentKifEntity.title.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : _currentKifEntity.title}.kif";
      final tempFile = File(p.join(tempDir.path, fileName));
      await tempFile.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: _currentKifEntity.title.isEmpty ? fileName : _currentKifEntity.title,
      );
    } catch (e) {
      debugPrint("KIF共有エラー: $e");
      if (mounted) {
        ShowErrorSnackbar.show(context, "棋譜の共有に失敗しました");
      }
    }
  }

  Future<void> _shareCurrentDiagramWithHand() async {
    try {
      final uiImage = await DiagramGenerator.generateForShare(
        state: kifTree!.currentNode.state,
        info: Map<String, String>.from(kifTree!.info),
        isReversed: _isReversed,
      );

      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("画像の変換に失敗しました");
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final file = File('${tempDir.path}/kif_share_$timestamp.png');
      await file.writeAsBytes(pngBytes);

      final moveNumber = kifTree!.currentNode.moveNumber;
      final shareText = "棋譜だまりから局面を共有しています（${moveNumber}手目）\n#将棋 #棋譜だまり";

      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: shareText,
        );
      }
    } catch (e) {
      debugPrint("共有失敗: $e");
      if (mounted) {
        ShowErrorSnackbar.show(context, "画像の共有に失敗しました");
      }
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

  // ダイヤルの回転操作（ドラッグ計算）ロジック
  void _processDialPanUpdate(DragUpdateDetails details) {
    final renderBox = _overlayDialKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final center = renderBox.size.center(Offset.zero);
    final localPos = renderBox.globalToLocal(details.globalPosition);

    final x = localPos.dx - center.dx;
    final y = localPos.dy - center.dy;
    final dx = details.delta.dx;
    final dy = details.delta.dy;

    final dist = math.sqrt(x * x + y * y);
    final effectiveDist = math.max(dist, 10.0);

    final rotationDelta = (-y * dx + x * dy) / (effectiveDist * 35.0);

    setState(() {
      _dialRotation += rotationDelta;
      _dialAccumulator += rotationDelta;
    });

    const double threshold = 0.22;

    while (_dialAccumulator >= threshold) {
      if (kifTree != null && kifTree!.currentNode.nextNodes.isNotEmpty) {
        setState(() {
          kifTree!.stepNext();
        });
        HapticFeedback.selectionClick();
      }
      _dialAccumulator -= threshold;
    }

    while (_dialAccumulator <= -threshold) {
      if (kifTree != null && kifTree!.currentNode.parent != null) {
        setState(() {
          kifTree!.stepBack();
        });
        HapticFeedback.selectionClick();
      }
      _dialAccumulator += threshold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings();

    if (_isLoading || kifTree == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final double sidebarWidth = MediaQuery.of(context).size.width * 0.85;

    return Scaffold(
      body: Stack(
        children: [
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
                  _buildPlayerAndKomaDai(
                    playerName: _isReversed ? (kifTree!.info['先手'] ?? '先手') : (kifTree!.info['後手'] ?? '後手'),
                    isSente: _isReversed,
                    isUpper: true,
                  ),
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
                  _buildPlayerAndKomaDai(
                    playerName: _isReversed ? (kifTree!.info['後手'] ?? '後手') : (kifTree!.info['先手'] ?? '先手'),
                    isSente: !_isReversed,
                    isUpper: false,
                  ),
                  // コメント欄＆ダイヤルオーバーレイ領域
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Stack(
                        children: [
                          // 通常時のコメント欄
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: () {},
                              child: Scrollbar(
                                controller: _commentScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _commentScrollController,
                                  child: SelectableLinkify(
                                    text: "${kifTree!.currentNode.joinedComment}",
                                    style: TextStyle(
                                      fontSize: settings.get<double>('fontSize'),
                                    ),
                                    strutStyle: StrutStyle(
                                      fontSize: settings.get<double>('fontSize'),
                                      height: 1.5,
                                      forceStrutHeight: true,
                                    ),
                                    linkStyle: const TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.none,
                                    ),
                                    contextMenuBuilder: (context, editableTextState) {
                                      return AdaptiveTextSelectionToolbar.editableText(
                                        editableTextState: editableTextState,
                                      );
                                    },
                                    onOpen: (link) async {
                                      final url = Uri.parse(link.url);
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(
                                          url,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      } else {
                                        ShowErrorSnackbar.show(context, 'リンクを開けませんでした');
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 💡 ドラッグ時にコメント欄の上に浮かび上がる文字なしシンプル大型ダイヤル
                          if (_isOverlayDialActive)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _buildLargeOverlayDial(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _buildControlPanel(),
                ],
              ),
            ),
          ),
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
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            right: _isSidebarOpen ? 0 : -sidebarWidth,
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

                            GameNode? temp = selectedNode;
                            while (temp != null && temp.parent != null) {
                              final parent = temp.parent!;
                              parent.selectedBranchIndex = parent.nextNodes.indexOf(temp);
                              temp = parent;
                            }

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

  // 💡 文字なし仕様の大型ダイヤルウィジェット
  Widget _buildLargeOverlayDial() {
    final bool hasBranch = kifTree!.currentNode.nextNodes.length > 1;

    return Container(
      key: _overlayDialKey,
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasBranch ? Colors.orange[50] : Colors.blue[50],
        border: Border.all(
          color: hasBranch ? Colors.orange[600]! : Colors.blue[400]!,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Transform.rotate(
        angle: _dialRotation,
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 回転ポインター（ツマミ）
              Positioned(
                top: 8,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasBranch ? Colors.orange[700] : Colors.blue[600],
                  ),
                ),
              ),
              // 周囲の目盛りドット
              Positioned(bottom: 8, child: _buildDialDot()),
              Positioned(left: 8, child: _buildDialDot()),
              Positioned(right: 8, child: _buildDialDot()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialDot() {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[400],
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
    return Container(
      color: const Color(0XFFF1F1F5),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          // 1. 最初の手へ移動ボタン
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.first_page),
                onPressed: () => setState(() => kifTree!.jumpTo(0)),
              ),
            ),
          ),

          // 2. 1手戻るボタン
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_left),
                iconSize: 36,
                onPressed: () => setState(() => kifTree!.stepBack()),
              ),
            ),
          ),

          // 3. 中央の手数表示枠（ドラッグでコメント欄に大型ダイヤル表示）
          Expanded(
            flex: 3,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 90),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!_isOverlayDialActive) {
                    setState(() {
                      _isSidebarOpen = true;
                    });
                  }
                },
                onPanStart: (_) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isOverlayDialActive = true;
                  });
                },
                onPanUpdate: _processDialPanUpdate,
                onPanEnd: (_) {
                  setState(() {
                    _isOverlayDialActive = false;
                    _dialAccumulator = 0.0;
                  });
                },
                onPanCancel: () {
                  setState(() {
                    _isOverlayDialActive = false;
                    _dialAccumulator = 0.0;
                  });
                },
                child: Builder(
                  builder: (context) {
                    final bool hasBranch = kifTree!.currentNode.nextNodes.length > 1;
                    final int currentMove = kifTree!.currentNode.moveNumber;
                    final String moveLabel = kifTree!.currentNode.moveLabel?.replaceAll(RegExp(r'\(.*\)'), '') ?? '';

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                      decoration: BoxDecoration(
                        color: hasBranch
                            ? Colors.orange[100]
                            : (_isOverlayDialActive ? Colors.blue[50] : Colors.white),
                        border: Border.all(
                          color: hasBranch
                              ? Colors.orange[700]!
                              : (_isOverlayDialActive ? Colors.blue[500]! : Colors.black45),
                          width: (hasBranch || _isOverlayDialActive) ? 2.0 : 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${currentMove}手目',
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.normal,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              moveLabel,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 4. 1手進むボタン
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_right),
                iconSize: 36,
                onPressed: () => setState(() => kifTree!.stepNext()),
              ),
            ),
          ),

          // 5. 最後の手に移動ボタン
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.last_page),
                onPressed: () => setState(() => kifTree!.jumpTo(kifTree!.totalMoveCount)),
              ),
            ),
          ),

          // 6. メニュー（三点リーダー）
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: MenuAnchor(
                alignmentOffset: const Offset(0, 0),
                style: MenuStyle(
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  elevation: WidgetStateProperty.all(8),
                ),
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.edit, size: 20),
                    child: const Text('棋譜を編集する'),
                    onPressed: () async {
                      final currentMove = kifTree?.currentNode.moveNumber ?? 0;

                      final List<int> branchPath = [];
                      GameNode? temp = kifTree?.currentNode;
                      while (temp != null && temp.parent != null) {
                        final parent = temp.parent!;
                        final index = parent.nextNodes.indexOf(temp);
                        if (index != -1) {
                          branchPath.insert(0, index);
                        }
                        temp = parent;
                      }

                      final updatedEntity = await Navigator.push<KifEntity>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => KifEditorPage(
                            kifEntity: _currentKifEntity,
                            initialMoveNumber: currentMove,
                            initialBranchPath: branchPath,
                          ),
                        ),
                      );

                      if (mounted) {
                        setState(() {
                          _isLoading = true;
                          if (updatedEntity != null) {
                            _currentKifEntity = updatedEntity;
                          }
                        });
                        await _initKifData();

                        if (kifTree != null && branchPath.isNotEmpty) {
                          GameNode nodeTemp = kifTree!.root;
                          for (final idx in branchPath) {
                            if (idx >= 0 && idx < nodeTemp.nextNodes.length) {
                              nodeTemp.selectedBranchIndex = idx;
                              nodeTemp = nodeTemp.nextNodes[idx];
                            } else {
                              break;
                            }
                          }
                          kifTree!.currentNode = nodeTemp;
                        } else {
                          kifTree?.jumpTo(currentMove);
                        }
                      }
                    },
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.share, size: 20),
                    child: const Text('棋譜ファイルを共有'),
                    onPressed: _shareKifData,
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.collections, size: 20),
                    child: const Text('この局面でサムネイルを生成'),
                    onPressed: () => _handleMakeThumbnail(),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.copy, size: 20),
                    child: const Text('棋譜ファイルをコピー'),
                    onPressed: () {
                      final kifContent = _rawKifContent;
                      if (kifContent == null || kifContent.isEmpty) {
                        ShowErrorSnackbar.show(context, 'コピーできる棋譜ファイルがありません');
                        return;
                      }
                      Clipboard.setData(ClipboardData(text: kifContent));
                      ShowSuccessSnackbar.show(context, '棋譜ファイルをコピーしました');
                    },
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.account_tree, size: 20),
                    child: const Text('棋譜ツリーを表示'),
                    onPressed: () {
                      setState(() {
                        _isSidebarOpen = true;
                      });
                    },
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
                ],
                builder: (BuildContext context, MenuController controller, Widget? child) {
                  return IconButton(
                    padding: EdgeInsets.zero,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerAndKomaDai({
    required String playerName,
    required bool isSente,
    required bool isUpper,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Row(
        children: [
          if (isSente) ...[
            Expanded(
              flex: 2,
              child: _buildPieceStand7Slots(isSente, isUpper),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 1,
              child: _buildNameLabel(playerName, isSente, Alignment.centerRight),
            ),
          ] else ...[
            Expanded(
              flex: 1,
              child: _buildNameLabel(playerName, isSente, Alignment.centerLeft),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 2,
              child: _buildPieceStand7Slots(isSente, isUpper),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPieceStand7Slots(bool isSente, bool isUpper) {
    final hand = isSente
        ? kifTree!.currentNode.state.senteHand
        : kifTree!.currentNode.state.goteHand;
    final assetPrefix = isUpper ? "w" : "b";

    const priorityOrder = ['fu', 'ya', 'ke', 'gi', 'ki', 'ka', 'hi'];

    final activeEntries = priorityOrder
        .where((key) => hand.containsKey(key) && (hand[key] ?? 0) > 0)
        .map((key) => MapEntry(key, hand[key]!))
        .toList();

    final List<MapEntry<String, int>?> slots = List.filled(7, null);

    if (isSente) {
      for (int i = 0; i < activeEntries.length; i++) {
        slots[i] = activeEntries[i];
      }
    } else {
      final reversedEntries = activeEntries.reversed.toList();
      for (int i = 0; i < reversedEntries.length; i++) {
        slots[6 - i] = reversedEntries[i];
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: slots.map((entry) {
        return Expanded(
          flex: 1,
          child: entry != null
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final double size = constraints.maxWidth.clamp(16.0, 32.0);

                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Image.asset(
                            'assets/images/pieces/$assetPrefix${entry.key}.png',
                            width: size,
                            height: size,
                            fit: BoxFit.contain,
                          ),
                          if (entry.value > 1)
                            Positioned(
                              right: -1,
                              bottom: -1,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${entry.value}',
                                  style: TextStyle(
                                    fontSize: (size * 0.45).clamp(9.0, 12.0),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                )
              : const SizedBox.shrink(),
        );
      }).toList(),
    );
  }

  Widget _buildNameLabel(String name, bool isSente, Alignment alignment) {
    return Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          "${isSente ? '▲' : '△'}$name",
          maxLines: 1,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _navigateToPreviewPage() async {
    try {
      final String initialSente = kifTree!.info['先手'] ?? '先手';
      final String initialGote = kifTree!.info['後手'] ?? '後手';

      Future<Uint8List> generateBytes({
        required bool highlightLastMove,
        required String senteName,
        required String goteName,
      }) async {
        final Map<String, String> updatedInfo = Map<String, String>.from(kifTree!.info);
        updatedInfo['先手'] = senteName;
        updatedInfo['後手'] = goteName;
        updatedInfo['sente'] = senteName;
        updatedInfo['gote'] = goteName;

        final uiImage = await DiagramGenerator.generateForShare(
          state: kifTree!.currentNode.state,
          info: updatedInfo,
          isReversed: _isReversed,
          highlightLastMove: highlightLastMove,
        );

        final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) throw Exception("画像の変換に失敗しました");
        return byteData.buffer.asUint8List();
      }

      final initialPngBytes = await generateBytes(
        highlightLastMove: true,
        senteName: initialSente,
        goteName: initialGote,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DiagramPreviewPage(
            initialPngBytes: initialPngBytes,
            moveNumber: kifTree!.currentNode.moveNumber,
            initialSenteName: initialSente,
            initialGoteName: initialGote,
            onUpdateDiagram: ({
              required bool highlightLastMove,
              required String senteName,
              required String goteName,
            }) async {
              return await generateBytes(
                highlightLastMove: highlightLastMove,
                senteName: senteName,
                goteName: goteName,
              );
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint("画像生成失敗: $e");
      if (mounted) {
        ShowErrorSnackbar.show(context, "画像の生成に失敗しました");
      }
    }
  }
}
