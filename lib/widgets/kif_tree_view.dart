import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:kifdamari/models/game_node.dart';

/// 棋譜の分岐を美しい樹形図（ツリービュー）で描画するWidget。
/// InteractiveViewer を使用しているため、ドラッグスクロールやピンチによるズームに対応しています。
class KifTreeView extends StatefulWidget {
  final GameNode rootNode;        // 0手目のルートノード
  final GameNode currentNode;     // 現在選択されているノード
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
  static const double rowHeight = 85.0;     // 手数（縦方向）の間隔
  static const double columnWidth = 95.0;  // 分岐（横方向）の間隔
  static const double nodeWidth = 75.0;    // ノード（ボタン）の幅
  static const double nodeHeight = 50.0;   // ノード（ボタン）の高さ

  late GameNode rootNode;
  
  // 🌟 同一局面（千日手や手戻りなど）がマップのキー重複でバグるのを防ぐため、
  // 参照一致 (Identity) で比較する HashMap を使用します。
  Map<GameNode, Point<double>> nodePositions = HashMap<GameNode, Point<double>>.identity();
  double maxColumn = 0;
  double maxRow = 0;

  @override
  void initState() {
    super.initState();
    _buildTreeLayout();
  }

  @override
  void didUpdateWidget(KifTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _buildTreeLayout();
  }

  /// 外部から渡されたルートノードを基に、各ノードの2次元グリッド座標 (X: 分岐列, Y: 手数) を計算します
  void _buildTreeLayout() {
    rootNode = widget.rootNode;

    // 参照一致の空のマップで初期化
    nodePositions = HashMap<GameNode, Point<double>>.identity();
    maxColumn = 0;
    maxRow = 0;

    // 行(手数)ごとの、現在使用可能な最新の列番号を追跡するマップ
    final Map<int, double> nextColumnForRow = {};

    _calculatePositions(rootNode, 0.0, nextColumnForRow);
  }

  /// 再帰的にツリーを探索し、重ならないように座標を割り当てるアルゴリズム
  void _calculatePositions(GameNode node, double preferredColumn, Map<int, double> nextColumnForRow) {
    final int row = node.moveNumber;
    
    // この行（手数）ですでに他の分岐が使っている右端の列を取得
    double assignedColumn = preferredColumn;
    final double currentNextAvail = nextColumnForRow[row] ?? 0.0;
    
    if (assignedColumn < currentNextAvail) {
      assignedColumn = currentNextAvail;
    }

    // 座標を確定 (X, Y)
    nodePositions[node] = Point(assignedColumn, row.toDouble());
    
    // この行の次の空き列を更新 (ノード同士が重ならないように1.2マス空ける)
    nextColumnForRow[row] = assignedColumn + 1.2;

    if (assignedColumn > maxColumn) maxColumn = assignedColumn;
    if (row > maxRow) maxRow = row.toDouble();

    // 子ノード（次の一手）を探索
    for (int i = 0; i < node.nextNodes.length; i++) {
      // 最初の子供（本譜）は同じ列を維持し、2番目以降の分岐（変化）は右側にずらして配置する
      final double childPreferredColumn = (i == 0) ? assignedColumn : assignedColumn + (i * 1.0);
      _calculatePositions(node.nextNodes[i], childPreferredColumn, nextColumnForRow);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (nodePositions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 描画エリアの全体サイズを決定
    final double contentWidth = (maxColumn + 1) * columnWidth + 120;
    final double contentHeight = (maxRow + 1) * rowHeight + 120;

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(100.0), // スクロール時に端に余裕を持たせる
      minScale: 0.1, // 🌟 ズームアウトで全体を見渡しやすくする
      maxScale: 2.0,
      constrained: false, // 🌟 超重要：これを false にすることで、画面サイズを超えたスクロールを許可します！
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // 🌟 背景タップを確実に拾うための設定
        child: Container(
          width: contentWidth,
          height: contentHeight,
          padding: const EdgeInsets.all(30.0),
          // 🌟 colorを指定してタッチ可能にする（透明にすることで見た目はそのまま）
          color: Colors.transparent, 
          child: Stack(
            clipBehavior: Clip.none, // 念のためはみ出しによるクリップを無効化
            children: [
              // 1. ノード間を繋ぐコネクタ線（折れ線）を CustomPaint で描画
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
              // 2. 各ノードを Widget（ボタン）として配置
              ...nodePositions.entries.map((entry) {
                final node = entry.key;
                final pos = entry.value;

                final double left = pos.x * columnWidth;
                final double top = pos.y * rowHeight;

                final bool isCurrent = node == widget.currentNode;
                final bool hasBranch = node.nextNodes.length > 1;

                // 指し手テキスト（カッコ内の座標などをトリム・Null安全に対応）
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
                        // 現在検討中の局面はオレンジ、分岐のある局面は薄いオレンジ、通常は白
                        color: isCurrent
                            ? Colors.orange[300]
                            : (hasBranch ? Colors.orange[50] : Colors.white),
                        border: Border.all(
                          color: isCurrent
                              ? Colors.orange[800]!
                              : (hasBranch ? Colors.orange[400]! : Colors.grey[400]!),
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
                          // 分岐がある場合に小さなアイコンを添える
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

  /// 指定したノードが、ルートから現在地(currentNode)までのパスに含まれているかを判定
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
