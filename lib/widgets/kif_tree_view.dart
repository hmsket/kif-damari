import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:kifdamari/models/game_node.dart';

class KifTreeView extends StatefulWidget {
  final GameNode rootNode;
  final GameNode currentNode;
  final Function(GameNode) onNodeSelected;

  const KifTreeView({
    super.key,
    required this.rootNode,
    required this.currentNode,
    required this.onNodeSelected,
  });

  @override
  State<KifTreeView> createState() => _KifTreeViewState();
}

class _KifTreeViewState extends State<KifTreeView> {
  // グリッド配置のサイズ定義
  static const double rowHeight = 70.0;   // 手数（縦方向）の間隔
  static const double columnWidth = 95.0; // 分岐（横方向）の間隔
  static const double nodeWidth = 75.0;   // ノード（ボタン）の幅
  static const double nodeHeight = 50.0;  // ノード（ボタン）の高さ

  late GameNode rootNode;
  late TransformationController _transformationController;

  Map<GameNode, Point<double>> nodePositions = HashMap<GameNode, Point<double>>.identity();
  double maxColumn = 0;
  double maxRow = 0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _buildTreeLayout();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentNode();
    });
  }

  @override
  void didUpdateWidget(KifTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _buildTreeLayout();

    if (oldWidget.currentNode != widget.currentNode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentNode();
      });
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  // 現在の手(currentNode)の位置が画面の上方中央に来るようにスクロール(並行移動)させる
  void _scrollToCurrentNode() {
    final currentPos = nodePositions[widget.currentNode];
    if (currentPos == null) return;

    // 現在のノードのピクセル座標を計算（paddingの30pxを考慮）
    final double nodeX = currentPos.x * columnWidth + 30.0;
    final double nodeY = currentPos.y * rowHeight + 30.0;

    // 画面（View）自体のサイズを取得
    final Size viewSize = context.size ?? const Size(0, 0);
    if (viewSize.width == 0 || viewSize.height == 0) return;

    // 【計算】ターゲットが画面上部に見えるようなスクロール量を算出
    // X座標: 画面の横中央にノードが来るようにする
    final double targetX = (viewSize.width / 2) - nodeX - (nodeWidth / 2);
    // Y座標: 画面の上部（例えば上から80pxの位置）にノードが来るようにする
    final double targetY = 80.0 - nodeY;

    // InteractiveViewerのMatrix4を更新（4x4行列の要素として平行移動をセット）
    final Matrix4 newMatrix = Matrix4.identity()
      ..translate(targetX, targetY);

    setState(() {
      _transformationController.value = newMatrix;
    });
  }

  // 外部から渡されたルートノードを基に、各ノードの2次元グリッド座標 (X: 分岐列, Y: 手数) を計算します
  void _buildTreeLayout() {
    rootNode = widget.rootNode;

    nodePositions = HashMap<GameNode, Point<double>>.identity();
    maxColumn = 0;
    maxRow = 0;

    final Map<GameNode, double> subtreeWidths = HashMap<GameNode, double>.identity();
    _calculateSubtreeWidths(rootNode, subtreeWidths);

    final Map<int, int> nextColumnForRow = {};
    _assignPositions(rootNode, 0, subtreeWidths, nextColumnForRow);
  }

  void _assignPositions(
    GameNode node,
    int currentLeftColumn,
    Map<GameNode, double> subtreeWidths,
    Map<int, int> nextColumnForRow,
  ) {
    final int row = node.moveNumber;

    int assignedColumn = currentLeftColumn;
    final int currentNextAvail = nextColumnForRow[row] ?? 0;
    if (assignedColumn < currentNextAvail) {
      assignedColumn = currentNextAvail;
    }

    nodePositions[node] = Point(assignedColumn.toDouble(), row.toDouble());
    nextColumnForRow[row] = assignedColumn + 1;

    if (assignedColumn > maxColumn) maxColumn = assignedColumn.toDouble();
    if (row > maxRow) maxRow = row.toDouble();

    int childLeftPointer = assignedColumn;

    for (int i = 0; i < node.nextNodes.length; i++) {
      final child = node.nextNodes[i];
      final int childWidth = (subtreeWidths[child] ?? 1.0).ceil();
      _assignPositions(child, childLeftPointer, subtreeWidths, nextColumnForRow);
      childLeftPointer += childWidth;
    }
  }

  double _calculateSubtreeWidths(GameNode node, Map<GameNode, double> subtreeWidths) {
    if (node.nextNodes.isEmpty) {
      subtreeWidths[node] = 1.0;
      return 1.0;
    }

    double totalWidth = 0.0;
    for (final child in node.nextNodes) {
      totalWidth += _calculateSubtreeWidths(child, subtreeWidths);
    }

    subtreeWidths[node] = max(1.0, totalWidth);
    return subtreeWidths[node]!;
  }

  @override
  Widget build(BuildContext context) {
    if (nodePositions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final double contentWidth = (maxColumn + 1) * columnWidth + 120;
    final double contentHeight = (maxRow + 1) * rowHeight + 120;

    return InteractiveViewer(
      transformationController: _transformationController, // コントローラーを紐付け
      boundaryMargin: const EdgeInsets.all(100.0), 
      minScale: 0.1, 
      maxScale: 2.0,
      constrained: false, 
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, 
        child: Container(
          width: contentWidth,
          height: contentHeight,
          padding: const EdgeInsets.all(30.0),
          color: Colors.transparent, 
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: KifTreePainter(
                    nodePositions: nodePositions,
                    rowHeight: rowHeight,
                    columnWidth: columnWidth,
                    nodeWidth: nodeWidth,
                    nodeHeight: nodeHeight,
                    currentNode: widget.currentNode,
                  ),
                ),
              ),
              ...nodePositions.entries.map((entry) {
                final node = entry.key;
                final pos = entry.value;

                final double left = pos.x * columnWidth;
                final double top = pos.y * rowHeight;

                final bool isCurrent = node == widget.currentNode;
                final bool hasBranch = node.nextNodes.length > 1;
                final String label = (node.moveLabel ?? '').replaceAll(RegExp(r'\(.*\)'), '');

                return Positioned(
                  left: left,
                  top: top,
                  width: nodeWidth,
                  height: nodeHeight,
                  child: GestureDetector(
                    onTap: () => widget.onNodeSelected(node),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isCurrent ? Colors.orange[300] : Colors.white,
                        border: Border.all(
                          color: isCurrent ? Colors.orange[800]! : Colors.grey[400]!,
                          width: isCurrent ? 2.5 : 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                )
                              ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                node.moveNumber == 0 ? '開始局' : '${node.moveNumber}手目',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isCurrent ? Colors.brown[900] : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                node.moveNumber == 0 ? '初期配置' : label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrent ? Colors.black : Colors.brown[900],
                                ),
                              ),
                            ],
                          ),
                          if (hasBranch && !isCurrent)
                            const Positioned(
                              top: 2,
                              right: 2,
                              child: Icon(
                                Icons.alt_route,
                                size: 10,
                                color: Colors.orange,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// ノード同士を直角の折れ線で接続するペインター
class KifTreePainter extends CustomPainter {
  final Map<GameNode, Point<double>> nodePositions;
  final double rowHeight;
  final double columnWidth;
  final double nodeWidth;
  final double nodeHeight;
  final GameNode currentNode;

  KifTreePainter({
    required this.nodePositions,
    required this.rowHeight,
    required this.columnWidth,
    required this.nodeWidth,
    required this.nodeHeight,
    required this.currentNode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.brown[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final Paint highlightPaint = Paint()
      ..color = Colors.orange[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // 各親子関係の線を引く
    nodePositions.forEach((node, pos) {
      final double parentX = pos.x * columnWidth + (nodeWidth / 2);
      final double parentY = pos.y * rowHeight + nodeHeight;

      for (final child in node.nextNodes) {
        final childPos = nodePositions[child];
        if (childPos == null) continue;

        final double childX = childPos.x * columnWidth + (nodeWidth / 2);
        final double childY = childPos.y * rowHeight;

        // 現在選択中のルート上にある線かどうかを判定
        final bool isPathHighlighted = _isNodeInCurrentPath(node) && _isNodeInCurrentPath(child);

        final activePaint = isPathHighlighted ? highlightPaint : linePaint;

        // コネクタの描画パス（直角のクランク型）
        final Path path = Path();
        path.moveTo(parentX, parentY);
        
        final double midY = parentY + (childY - parentY) / 2;
        
        path.lineTo(parentX, midY); // まず垂直に下り
        path.lineTo(childX, midY);  // 水平に移動し
        path.lineTo(childX, childY); // 最後に子供に向かって垂直に下りる

        canvas.drawPath(path, activePaint);
      }
    });
  }

  // 指定したノードが、ルートから現在地(currentNode)までのパスに含まれているかを判定
  bool _isNodeInCurrentPath(GameNode node) {
    GameNode? temp = currentNode;
    while (temp != null) {
      if (temp == node) return true;
      temp = temp.parent;
    }
    return false;
  }

  @override
  bool shouldRepaint(covariant KifTreePainter oldDelegate) {
    return oldDelegate.currentNode != currentNode || oldDelegate.nodePositions != nodePositions;
  }
}
