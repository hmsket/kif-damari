import 'dart:collection';
import 'dart:math';
import 'package:flutter/gestures.dart'; // kTouchSlop
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart'; // BoundedFrictionSimulation（慣性スクロール用）
import 'package:flutter/scheduler.dart'; // Ticker
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/models/game_node.dart';
import 'package:kifdamari/widgets/app_settings.dart';

class KifTreeView extends StatefulWidget {
  final GameNode rootNode;
  final GameNode currentNode;
  final Function(GameNode) onNodeSelected;
  final Function(GameNode)? onNodeDeleted; // 💡 削除用コールバック（nullの場合は閲覧モードとして動作）

  const KifTreeView({
    super.key,
    required this.rootNode,
    required this.currentNode,
    required this.onNodeSelected,
    this.onNodeDeleted, // 💡 編集画面でのみ渡す
  });

  @override
  State<KifTreeView> createState() => _KifTreeViewState();
}

class _KifTreeViewState extends State<KifTreeView> with TickerProviderStateMixin {
  // グリッド配置のサイズ定義
  static const double rowHeight = 70.0;   // 手数（縦方向）の間隔
  static const double columnWidth = 95.0; // 分岐（横方向）の間隔
  static const double nodeWidth = 75.0;   // ノード（ボタン）の幅
  static const double nodeHeight = 50.0;  // ノード（ボタン）の高さ

  // 💡 スクロール挙動の調整用定数
  // ドラッグ移動の倍率は設定「treeScrollSpeed」から読み込む（既定値 2.0）
  static const double flickFriction = 0.08;      // 慣性スクロールの摩擦係数（小さいほど遠くまで滑る）
  static const double flickMaxVelocity = 2500.0; // 慣性スクロール速度の上限 (px/s)
  static const double flickMinVelocity = 50.0;   // 慣性スクロールを開始する最低速度 (px/s)
  static const int velocitySampleWindowMs = 100; // 速度算出に使うサンプル時間幅 (ms)
  static const double treeBoundaryMargin = 100.0; // パン可能な範囲のマージン

  final AppSettings _settings = AppSettings();
  double _panSpeedMultiplier = 2.0; // ドラッグ移動・慣性初速に掛ける倍率（設定由来）

  late GameNode rootNode;
  late TransformationController _transformationController;

  // 💡 自前パン＆慣性スクロール用の状態
  int? _trackedPointerId; // パン追跡中の指（1本目のみ。nullなら追跡していない）
  double _panTravelDistance = 0.0; // パン開始しきい値判定用の累計移動量
  final List<Duration> _panPointerTimes = <Duration>[];
  final List<Offset> _panPointerPositions = <Offset>[];
  Ticker? _inertiaTicker;
  FrictionSimulation? _inertiaSimX;
  FrictionSimulation? _inertiaSimY;

  Map<GameNode, Point<double>> nodePositions = HashMap<GameNode, Point<double>>.identity();
  double maxColumn = 0;
  double maxRow = 0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _buildTreeLayout();

    // 💡 スクロール速度の設定値を読み込み、変更をリアルタイムで反映する
    _panSpeedMultiplier = _settings.get<double>('treeScrollSpeed');
    _settings.listenable.addListener(_onSettingsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentNode();
    });
  }

  void _onSettingsChanged() {
    final double newValue = _settings.get<double>('treeScrollSpeed');
    if (newValue == _panSpeedMultiplier) return;
    _panSpeedMultiplier = newValue;
  }

  @override
  void didUpdateWidget(KifTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _buildTreeLayout();

    if (oldWidget.currentNode != widget.currentNode) {
      // 💡 自動スクロールが起きるので慣性スクロールを停止する（即時）
      _cancelInertia();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentNode();
      });
    }
  }

  @override
  void dispose() {
    _settings.listenable.removeListener(_onSettingsChanged);
    _cancelInertia();
    _transformationController.dispose();
    super.dispose();
  }

  // 現在の手(currentNode)の位置が画面の上方中央に来るようにスクロール(並行移動)させる
  void _scrollToCurrentNode() {
    // 💡 自動スクロールが起きたら慣性スクロールは止める
    _cancelInertia();
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

  /// コンテンツ全体の論理サイズ（InteractiveViewerのchildと同じ値）
  double get contentWidth => (maxColumn + 1) * columnWidth + 120;
  double get contentHeight => (maxRow + 1) * rowHeight + 120;

  // 💡 ドラッグ（パン）と慣性スクロールの自前処理
  // InteractiveViewer標準のパンは panEnabled: false で無効化し、
  // ここで「設定倍率（_panSpeedMultiplier）倍の移動」と「指を離した後の慣性」を実現する。

  void _onPointerDown(PointerDownEvent event) {
    // 指が触れたら慣性は中止する
    _cancelInertia();
    if (_trackedPointerId != null) {
      // 2本目の指が触れた → ピンチズームへ。シングル指パンの追跡は中止
      _trackedPointerId = null;
      _panTravelDistance = 0.0;
      _panPointerTimes.clear();
      _panPointerPositions.clear();
      return;
    }
    _trackedPointerId = event.pointer;
    _panTravelDistance = 0.0;
    _panPointerTimes.clear();
    _panPointerPositions.clear();
    _recordPointerSample(event.timeStamp, event.localPosition);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _trackedPointerId) return;

    // しきい値（タップ判定用のslop）未満の微細な移動は、ドラッグとタップを
    // 取り違えないように無視する
    if (_panTravelDistance < kTouchSlop) {
      _panTravelDistance += event.delta.distance;
      if (_panTravelDistance < kTouchSlop) {
        _recordPointerSample(event.timeStamp, event.localPosition);
        return;
      }
    }

    _applyPan(event.delta * _panSpeedMultiplier);
    _recordPointerSample(event.timeStamp, event.localPosition);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _trackedPointerId) return;
    _trackedPointerId = null;

    final Offset velocity = _estimatePointerVelocity() * _panSpeedMultiplier;
    if (velocity.distance < flickMinVelocity) return;
    _startInertia(velocity);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _trackedPointerId) return;
    _trackedPointerId = null;
    _panTravelDistance = 0.0;
    _panPointerTimes.clear();
    _panPointerPositions.clear();
  }

  void _recordPointerSample(Duration time, Offset position) {
    _panPointerTimes.add(time);
    _panPointerPositions.add(position);

    // 直近 velocitySampleWindowMs ミリ秒分のサンプルだけを保持する
    final Duration window = const Duration(milliseconds: velocitySampleWindowMs);
    while (_panPointerTimes.length > 2 &&
        _panPointerTimes.last - _panPointerTimes.first > window) {
      _panPointerTimes.removeAt(0);
      _panPointerPositions.removeAt(0);
    }
  }

  /// 記録したサンプルから指の速度 (px/s) を算出する
  Offset _estimatePointerVelocity() {
    if (_panPointerTimes.length < 2) return Offset.zero;
    final double seconds = (_panPointerTimes.last - _panPointerTimes.first).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (seconds <= 0) return Offset.zero;
    final Offset traveled = _panPointerPositions.last - _panPointerPositions.first;
    return Offset(traveled.dx / seconds, traveled.dy / seconds);
  }

  /// パン許容範囲 [min, max] を計算する。
  /// InteractiveViewer(boundaryMargin = treeBoundaryMargin)と同じ条件（シーン座標での
  /// ビューポート四隅が [-margin, コンテンツ + margin] の矩形内に収まる）を再現する。
  /// 現在値が範囲外（自動スクロール後など）の場合でも境界へスナップしないよう、
  /// 範囲を現在値まで広げて返す。
  (double, double) _panRange({
    required double current,
    required double viewportSize,
    required double contentSize,
    required double scale,
  }) {
    final double boundMin = viewportSize - scale * (contentSize + treeBoundaryMargin);
    final double boundMax = scale * treeBoundaryMargin;
    if (boundMin > boundMax) {
      // 境界がビューポートより小さい場合はこの軸では動かせない
      return (current, current);
    }
    return (min(boundMin, current), max(boundMax, current));
  }

  void _applyPan(Offset panDelta) {
    final Size viewSize = context.size ?? const Size(0, 0);
    if (viewSize.width == 0 || viewSize.height == 0) return;

    final Matrix4 matrix = _transformationController.value;
    final double scale = matrix.getMaxScaleOnAxis();
    final double currentX = matrix.getTranslation().x;
    final double currentY = matrix.getTranslation().y;
    final (double loX, double hiX) = _panRange(
      current: currentX,
      viewportSize: viewSize.width,
      contentSize: contentWidth,
      scale: scale,
    );
    final (double loY, double hiY) = _panRange(
      current: currentY,
      viewportSize: viewSize.height,
      contentSize: contentHeight,
      scale: scale,
    );
    final double nextX = (currentX + panDelta.dx).clamp(loX, hiX).toDouble();
    final double nextY = (currentY + panDelta.dy).clamp(loY, hiY).toDouble();
    if (nextX == currentX && nextY == currentY) return;

    // translate()はスケール後の座標系で効くため、スケールで割って戻す
    _transformationController.value = matrix.clone()
      ..translate((nextX - currentX) / scale, (nextY - currentY) / scale);
  }

  /// 指を離した瞬間の速度で、滑りながら減速して止まる慣性スクロールを開始する
  void _startInertia(Offset velocity) {
    _cancelInertia();

    // 滑りすぎを防ぐため速度に上限を設ける
    final double cap = flickMaxVelocity;
    Offset startVelocity = velocity;
    if (startVelocity.dx.abs() > cap) {
      startVelocity = Offset(startVelocity.dx.sign * cap, startVelocity.dy);
    }
    if (startVelocity.dy.abs() > cap) {
      startVelocity = Offset(startVelocity.dx, startVelocity.dy.sign * cap);
    }
    if (startVelocity == Offset.zero) return;

    final Size viewSize = context.size ?? const Size(0, 0);
    if (viewSize.width == 0 || viewSize.height == 0) return;

    final Matrix4 matrix = _transformationController.value;
    final double scale = matrix.getMaxScaleOnAxis();
    final double startX = matrix.getTranslation().x;
    final double startY = matrix.getTranslation().y;

    final (double loX, double hiX) = _panRange(
      current: startX,
      viewportSize: viewSize.width,
      contentSize: contentWidth,
      scale: scale,
    );
    final (double loY, double hiY) = _panRange(
      current: startY,
      viewportSize: viewSize.height,
      contentSize: contentHeight,
      scale: scale,
    );

    // BoundedFrictionSimulationは位置を[lo, hi]にクランプしながら減速し、
    // 端に到達したらそこで止まる（はみ出し続けない）
    _inertiaSimX = BoundedFrictionSimulation(flickFriction, startX, startVelocity.dx, loX, hiX);
    _inertiaSimY = BoundedFrictionSimulation(flickFriction, startY, startVelocity.dy, loY, hiY);

    _inertiaTicker = createTicker(_handleInertiaTick)..start();
  }

  void _handleInertiaTick(Duration elapsed) {
    final FrictionSimulation? simX = _inertiaSimX;
    final FrictionSimulation? simY = _inertiaSimY;
    if (simX == null || simY == null) return;

    final double time = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final double targetX = simX.x(time);
    final double targetY = simY.x(time);

    final Matrix4 matrix = _transformationController.value;
    final double scale = matrix.getMaxScaleOnAxis();
    final double currentX = matrix.getTranslation().x;
    final double currentY = matrix.getTranslation().y;
    if (targetX != currentX || targetY != currentY) {
      // translate()はスケール後の座標系で効くため、スケールで割って戻す
      _transformationController.value = matrix.clone()
        ..translate((targetX - currentX) / scale, (targetY - currentY) / scale);
    }

    // 実質静止（速度がごく小さい）になったら、トレーラを長く引っ張らないよう終了する
    if ((simX.isDone(time) || simX.dx(time).abs() < 15.0) &&
        (simY.isDone(time) || simY.dx(time).abs() < 15.0)) {
      _cancelInertia();
    }
  }

  void _cancelInertia() {
    _inertiaSimX = null;
    _inertiaSimY = null;
    final Ticker? ticker = _inertiaTicker;
    _inertiaTicker = null;
    if (ticker != null) {
      ticker.stop();
      ticker.dispose();
    }
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

    // 💡 標準のパン（panEnabled: false で無効化）の代わりに、上側の Listener で
    // ドラッグ移動（設定のスクロール速度倍）と慣性スクロールを自前処理する。
    final Widget tree = InteractiveViewer(
      transformationController: _transformationController, // コントローラーを紐付け
      boundaryMargin: const EdgeInsets.all(treeBoundaryMargin), 
      minScale: 0.1, 
      maxScale: 2.0,
      constrained: false, 
      panEnabled: false, // 💡 パンは自前処理（ピンチズームは標準のまま）
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
                final bool isRoot = node.moveNumber == 0;

                // 💡 修正点: 1手前（親ノード）の着手先座標を取得して「同」の判定に引き渡す
                final parentState = node.parent?.state;
                final String label = node.moveLabel != null && node.moveLabel!.isNotEmpty
                    ? KifParser.convertToJapanese(
                        node.moveLabel!,
                        lastToX: parentState?.lastMoveToX,
                        lastToY: parentState?.lastMoveToY,
                      )
                    : '開始局面';

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
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isRoot ? '0手目' : '${node.moveNumber}手目',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isCurrent ? Colors.brown[900] : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                isRoot ? '開始局面' : label,
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
                          // 💡 分岐アイコン（×ボタンと重ならないよう左上に配置）
                          if (hasBranch && !isCurrent)
                            const Positioned(
                              top: 2,
                              left: 2,
                              child: Icon(
                                Icons.alt_route,
                                size: 10,
                                color: Colors.orange,
                              ),
                            ),
                          // 💡 コメント付き局面ノードの印（青い吹き出し・右上に配置）
                          if (node.comments.isNotEmpty)
                            const Positioned(
                              top: 2,
                              right: 2,
                              child: Icon(
                                Icons.chat_bubble,
                                size: 10,
                                color: Colors.blue,
                              ),
                            ),
                          // 💡 削除用×ボタン（開始局面以外 & onNodeDeletedが渡されている編集モード時のみ表示）
                          if (!isRoot && widget.onNodeDeleted != null)
                            Positioned(
                              top: -5,
                              right: -5,
                              child: GestureDetector(
                                onTap: () => widget.onNodeDeleted!(node),
                                child: const Padding(
                                  padding: EdgeInsets.all(4), // タップ領域の確保
                                  child: Icon(
                                    Icons.cancel,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                ),
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

    // 💡 InteractiveViewer自身のパンは無効なので、指の動きを直接受け取って
    // パン（設定のスクロール速度倍）と慣性スクロールを処理する。
    // ノードのタップ選択には影響しない（Listenerはジェスチャ競合に参加しない）。
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: tree,
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
