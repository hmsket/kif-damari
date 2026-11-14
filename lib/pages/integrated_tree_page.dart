import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/dao/position_appearance_dao.dart';
import 'package:kifdamari/database/dao/position_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/database/entity/position_appearance_entity.dart';
import 'package:kifdamari/database/entity/position_entity.dart';
import 'package:kifdamari/dialogs/comment_edit_dialog.dart';
import 'package:kifdamari/logic/integrated_tree_service.dart';
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/logic/shogi_rule_helper.dart';
import 'package:kifdamari/logic/sfen_generator.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/models/game_node.dart';
import 'package:kifdamari/pages/integrated_tree_root_page.dart';
import 'package:kifdamari/pages/kif_viewer_page.dart';
import 'package:kifdamari/snackbars/show_error_snackbar.dart';
import 'package:kifdamari/widgets/appearance_sidebar.dart';
import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/kif_board.dart';
import 'package:kifdamari/widgets/kif_tree_view.dart';
import 'package:url_launcher/url_launcher.dart';

/// 統合ツリーを直接辿る画面（仕様 F.3）
/// 再生画面と同じ骨格（アプリバーなし／経路表示・次の手チップなし）。
class IntegratedTreePage extends StatefulWidget {
  final PositionEntity rootPosition;

  /// 開き初めに現在地とする局面の positionKey（局面検索の結果画面から開くときに使う）。
  /// 指定した局面がツリー内に見つからない場合は根の局面で開く。
  final String? initialPositionKey;

  const IntegratedTreePage({
    super.key,
    required this.rootPosition,
    this.initialPositionKey,
  });

  @override
  State<IntegratedTreePage> createState() => _IntegratedTreePageState();
}

class _IntegratedTreePageState extends State<IntegratedTreePage>
    with TickerProviderStateMixin {
  IntegratedTree? tree;
  GameNode? current;
  bool _isLoading = true;
  bool _isReversed = false;

  // 出現情報（現在局面の positionKey に紐づく出現一覧と、その棋譜の実体）
  String? _loadedPositionKey;
  List<PositionAppearanceEntity> _appearances = const [];
  Map<int, KifEntity> _kifById = const {};

  bool _isRightSidebarOpen = false;
  bool _isLeftSidebarOpen = false;

  // 統合ツリーの削除モード（false=参照モード：×ボタン非表示、true=削除モード：×ボタン表示）
  bool _isTreeDeleteMode = false;

  // ダイヤル操作用の変数
  double _dialRotation = 0.0;
  double _dialAccumulator = 0.0;
  bool _isOverlayDialActive = false;
  final GlobalKey _overlayDialKey = GlobalKey();

  // 盤上の駒・持ち駒の選択／ドラッグ状態
  int? _selectedFile;
  int? _selectedRank;
  String? _selectedHandPiece;
  bool _isDraggingPiece = false;
  int? _dragFile;
  int? _dragRank;
  String? _dragPieceCode;
  Offset _dragGlobalPosition = Offset.zero;
  Offset _dragLocalPosition = Offset.zero;
  bool _dragIsFromHand = false;
  String? _dragHandPieceType;
  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _dragOverlayKey = GlobalKey();
  BoxConstraints? _boardConstraints;
  Offset _lastTapGlobalPosition = Offset.zero;

  final ScrollController _commentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initTree();
  }

  @override
  void dispose() {
    _commentScrollController.dispose();
    super.dispose();
  }

  Future<void> _initTree() async {
    final built = await IntegratedTreeService.buildTreeFromRoot(widget.rootPosition);
    if (!mounted) return;

    // 指定局面があればそこを現在地にする（根から現在地までの分岐選択も整える）
    GameNode? initial = built?.root;
    final initialKey = widget.initialPositionKey;
    if (built != null && initialKey != null) {
      final found = _findNodeByKey(built.root, initialKey);
      if (found != null) {
        initial = found;
        GameNode? temp = found;
        while (temp.parent != null) {
          final parent = temp.parent!;
          parent.selectedBranchIndex = parent.nextNodes.indexOf(temp);
          temp = parent;
        }
      }
    }

    setState(() {
      tree = built;
      current = initial;
      _isLoading = false;
    });
  }

  /// ツリー内から positionKey が一致する最初のノードを探す（幅優先）
  static GameNode? _findNodeByKey(GameNode root, String positionKey) {
    final queue = <GameNode>[root];
    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      if (node.positionKey == positionKey) return node;
      queue.addAll(node.nextNodes);
    }
    return null;
  }

  bool get _hasLoadError => !_isLoading && tree == null;

  // 現在局面の positionKey
  String? get _currentKey => current?.positionKey;

  // 現在局面の根からの手数
  int get _currentMoveNumber => current?.moveNumber ?? 0;

  // 現在局面の positionId
  int? get _currentPositionId {
    final key = _currentKey;
    if (key == null || tree == null) return null;
    return tree!.positionIdByKey[key];
  }

  // 現在地が根（開始局面）か
  bool get _isAtRoot => current != null && current!.parent == null;

  // 現在地の枝がこれ以上進めない（行き止まり）か
  bool get _isAtLeaf => current == null || current!.nextNodes.isEmpty;

  void _refreshPositionInfoIfNeeded() {
    final key = _currentKey;
    if (key == null || key == _loadedPositionKey) return;
    _loadedPositionKey = key;
    _appearances = const [];
    _kifById = const {};
    _loadPositionInfo(key);
  }

  Future<void> _loadPositionInfo(String key) async {
    try {
      final position = await PositionDao().getByKey(key);
      if (position == null) {
        if (!mounted || _loadedPositionKey != key) return;
        setState(() {
          _appearances = const [];
          _kifById = const {};
        });
        return;
      }
      final appearances = await PositionAppearanceDao().getByPositionId(position.id!);
      final kifs = await KifDao().getByIds(appearances.map((a) => a.kifId).toList());
      if (!mounted || _loadedPositionKey != key) return;
      setState(() {
        _appearances = appearances;
        _kifById = {for (final k in kifs) k.id!: k};
      });
    } catch (e) {
      debugPrint('出現情報の取得に失敗しました: $e');
      if (mounted && _loadedPositionKey == key) {
        setState(() {
          _appearances = const [];
          _kifById = const {};
        });
      }
    }
  }

  // 現在の局面が「他の棋譜にも出現する」かどうか（統合ツリー画面では出現があれば常にピルを出す）
  bool get _hasAppearance => _appearances.isNotEmpty;

  void _openRightSidebar() {
    setState(() {
      _isRightSidebarOpen = true;
      _isLeftSidebarOpen = false;
    });
  }

  void _openLeftSidebar() {
    setState(() {
      _isLeftSidebarOpen = true;
      _isRightSidebarOpen = false;
    });
  }

  // 現在地のノードを更新し、根から現在地までの分岐選択を整える
  void _selectNode(GameNode node) {
    if (tree == null) return;
    setState(() {
      current = node;
      _clearSelectionState();
      GameNode? temp = node;
      while (temp != null && temp.parent != null) {
        final parent = temp.parent!;
        parent.selectedBranchIndex = parent.nextNodes.indexOf(temp);
        temp = parent;
      }
      _isRightSidebarOpen = false;
    });
  }

  void _clearSelectionState() {
    _selectedFile = null;
    _selectedRank = null;
    _selectedHandPiece = null;
  }

  // ─── 進み方2: ツリー・コントロールでの移動 ───

  void _stepNext() {
    final node = current;
    if (node == null || node.nextNodes.isEmpty) return;
    _selectNode(node.nextNodes[node.selectedBranchIndex]);
  }

  void _stepBack() {
    final node = current;
    if (node == null || node.parent == null) return;
    setState(() {
      current = node.parent;
      _clearSelectionState();
    });
  }

  void _jumpToRoot() {
    if (current == null) return;
    setState(() {
      while (current!.parent != null) {
        current = current!.parent;
      }
      _clearSelectionState();
    });
  }

  void _jumpToLast() {
    if (current == null) return;
    setState(() {
      while (current!.nextNodes.isNotEmpty) {
        final node = current!;
        current = node.nextNodes[node.selectedBranchIndex];
      }
      _clearSelectionState();
    });
  }

  // ─── コメント編集（②と共通の導線） ───

  // 同じ positionKey を持つノードすべてにコメントを反映する
  void _applyCommentToNodes(String positionKey, List<String> comments) {
    final stack = <GameNode?>[];
    if (tree == null) return;
    stack.add(tree!.root);
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      if (node == null) continue;
      stack.addAll(node.nextNodes);
      if (node.positionKey == positionKey) {
        node.comments
          ..clear()
          ..addAll(comments);
      }
    }
  }

  void _showCommentEditDialog() async {
    final node = current;
    if (node == null || !_isCommentEditable) return;

    final positionKey = node.positionKey;
    final result = await showCommentEditDialog(context, node.joinedComment);
    if (result == null || !mounted) return;

    setState(() {
      if (positionKey != null) {
        _applyCommentToNodes(positionKey, result);
      } else {
        node.comments
          ..clear()
          ..addAll(result);
      }
    });

    final positionId = positionKey == null ? null : tree!.positionIdByKey[positionKey];
    if (positionId == null) return;
    final saved = await IntegratedTreeService.savePositionComment(positionId, result.join('\n'));
    if (!saved && mounted) {
      ShowErrorSnackbar.show(context, 'コメントの保存に失敗しました');
    }
  }

  // 現在局面のコメント編集が可能か（DB上も管理されている局面のみ）
  bool get _isCommentEditable => _currentPositionId != null;

  // ─── 統合ツリーの削除（仕様 F.3 / Q22） ───

  // ツリー表示の×ボタンで「その局面だけ」を削除する。
  // 親との枝（エッジ）を消すだけ。その先の局面・個別棋譜には触らず、
  // コメントも一緒に消える。墓標は残さない（再取り込みで復活してよい）。
  void _removeTreeNode(GameNode node) async {
    final parent = node.parent;
    final t = tree;
    if (parent == null || t == null) return; // 開始局面（根）は削除しない

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('局面の削除'),
        content: Text('${node.moveNumber}手目の局面を削除しますか？\n（この局面に付いたコメントも消えます）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final fromId = parent.positionKey == null
        ? null
        : t.positionIdByKey[parent.positionKey!];
    final toId = node.positionKey == null
        ? null
        : t.positionIdByKey[node.positionKey!];
    if (fromId == null || toId == null) {
      ShowErrorSnackbar.show(context, '局面の削除に失敗しました');
      return;
    }

    final ok = await IntegratedTreeService.removePositionEdge(
      fromPositionId: fromId,
      toPositionId: toId,
    );
    if (!ok || !mounted) {
      if (mounted) ShowErrorSnackbar.show(context, '局面の削除に失敗しました');
      return;
    }

    setState(() {
      parent.nextNodes.remove(node);

      if (parent.selectedBranchIndex >= parent.nextNodes.length) {
        parent.selectedBranchIndex = (parent.nextNodes.length - 1).clamp(0, 999);
      }

      // 現在地が削除した局面（またはその子孫）なら、その親局面へ戻す
      GameNode? temp = current;
      while (temp != null) {
        if (identical(node, temp)) {
          current = parent;
          break;
        }
        temp = temp.parent;
      }

      // 同じ局面（手順前後で他の経路から辿れるコピー）からもコメントを消す
      final nodeKey = node.positionKey;
      if (nodeKey != null) {
        _applyCommentToNodes(nodeKey, const <String>[]);
      }

      _clearSelectionState();
    });
  }

  // ─── 出現一覧の行タップ：その棋譜のその手数へジャンプする ───

  void _handleAppearanceTap(PositionAppearanceEntity appearance) {
    final kif = _kifById[appearance.kifId];
    if (kif == null) return;

    setState(() {
      _isLeftSidebarOpen = false;
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KifViewerPage(
          kifEntity: kif,
          initialMoveNumber: appearance.moveNumber,
        ),
      ),
    );
  }

  // ─── 進み方1: 盤面で駒を動かす（編集画面と同じ操作体系） ───

  /// 盤面上のローカル座標を（筋, 段）に変換する。盤の外の場合は null を返す。
  (int, int)? _boardCoordsFromLocal(Offset localPosition, BoxConstraints constraints) {
    final double boardWidth = constraints.maxWidth;
    final double boardHeight = constraints.maxHeight;

    final double cellWidth = boardWidth / 9;
    final double cellHeight = boardHeight / 9;

    double localX = localPosition.dx;
    double localY = localPosition.dy;

    if (_isReversed) {
      localX = boardWidth - localX;
      localY = boardHeight - localY;
    }

    final int file = 9 - (localX / cellWidth).floor();
    final int rank = (localY / cellHeight).floor() + 1;

    if (file < 1 || file > 9 || rank < 1 || rank > 9) return null;

    return (file, rank);
  }

  /// グローバル座標を盤面の（筋, 段）に変換する。盤の外の場合は null を返す。
  (int, int)? _boardCoordsFromGlobal(Offset globalPosition) {
    final RenderBox? box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    final BoxConstraints? constraints = _boardConstraints;
    if (box == null || constraints == null || !box.attached) return null;

    return _boardCoordsFromLocal(box.globalToLocal(globalPosition), constraints);
  }

  Offset? _localPositionFromGlobal(Offset globalPosition, GlobalKey key) {
    final RenderBox? box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.globalToLocal(globalPosition);
  }

  void _onBoardTap(TapUpDetails details, BoxConstraints constraints) {
    if (current == null) return;

    _lastTapGlobalPosition = details.globalPosition;

    final coord = _boardCoordsFromLocal(details.localPosition, constraints);
    if (coord == null) return;

    _handleSquareClick(coord.$1, coord.$2);
  }

  void _onBoardPanStart(DragStartDetails details, BoxConstraints constraints) {
    if (current == null) return;
    if (_dragIsFromHand) return;

    final coord = _boardCoordsFromLocal(details.localPosition, constraints);
    if (coord == null) return;

    final int file = coord.$1;
    final int rank = coord.$2;

    final currentState = current!.state;
    final String? piece = currentState.grid[rank - 1][9 - file];
    if (piece == null || !_isOwnPiece(piece, currentState.nextPlayer)) return;

    setState(() {
      _isDraggingPiece = true;
      _dragFile = file;
      _dragRank = rank;
      _dragPieceCode = piece;
      _dragGlobalPosition = details.globalPosition;
      _dragLocalPosition = details.localPosition;
      _selectedHandPiece = null;
      _selectedFile = file;
      _selectedRank = rank;
    });
  }

  void _onBoardPanUpdate(DragUpdateDetails details) {
    if (!_isDraggingPiece) return;
    if (_dragIsFromHand) return;

    setState(() {
      _dragGlobalPosition = details.globalPosition;
      _dragLocalPosition = details.localPosition;
    });
  }

  void _onBoardPanEnd(BoxConstraints constraints) {
    if (!_isDraggingPiece) return;
    if (_dragIsFromHand) return;

    final int? fromFile = _dragFile;
    final int? fromRank = _dragRank;
    final Offset dropLocal = _dragLocalPosition;
    final Offset dropGlobal = _dragGlobalPosition;

    setState(() {
      _isDraggingPiece = false;
      _dragFile = null;
      _dragRank = null;
      _dragPieceCode = null;
      _selectedFile = null;
      _selectedRank = null;
    });

    if (fromFile == null || fromRank == null) return;

    final coord = _boardCoordsFromLocal(dropLocal, constraints);
    if (coord == null || (coord.$1 == fromFile && coord.$2 == fromRank)) return;

    final validMoves = _getValidMoves(fromFile, fromRank);
    final bool canMove = validMoves.any((m) => m[0] == coord.$1 && m[1] == coord.$2);
    if (!canMove) return;

    _lastTapGlobalPosition = dropGlobal;

    _movePiece(fromFile: fromFile, fromRank: fromRank, toFile: coord.$1, toRank: coord.$2);
  }

  void _onBoardPanCancel() {
    if (!_isDraggingPiece) return;
    if (_dragIsFromHand) return;

    setState(() {
      _isDraggingPiece = false;
      _dragFile = null;
      _dragRank = null;
      _dragPieceCode = null;
      _selectedFile = null;
      _selectedRank = null;
    });
  }

  /// 持ち駒のドラッグ開始（駒台）
  void _onHandPanStart(DragStartDetails details, String pieceType, String assetCode, bool isOwnTurn) {
    if (current == null || !isOwnTurn) return;

    setState(() {
      _isDraggingPiece = true;
      _dragIsFromHand = true;
      _dragHandPieceType = pieceType;
      _dragFile = null;
      _dragRank = null;
      _dragPieceCode = assetCode;
      _dragGlobalPosition = details.globalPosition;
      _selectedHandPiece = pieceType;
      _selectedFile = null;
      _selectedRank = null;
    });
  }

  void _onHandPanUpdate(DragUpdateDetails details) {
    if (!_isDraggingPiece || !_dragIsFromHand) return;

    setState(() {
      _dragGlobalPosition = details.globalPosition;
    });
  }

  void _onHandPanEnd() {
    if (!_isDraggingPiece || !_dragIsFromHand) return;

    final String? pieceType = _dragHandPieceType;
    final Offset dropGlobal = _dragGlobalPosition;

    setState(() {
      _isDraggingPiece = false;
      _dragIsFromHand = false;
      _dragFile = null;
      _dragRank = null;
      _dragPieceCode = null;
      _dragHandPieceType = null;
      _selectedHandPiece = null;
      _selectedFile = null;
      _selectedRank = null;
    });

    if (pieceType == null || current == null) return;

    final coord = _boardCoordsFromGlobal(dropGlobal);
    if (coord == null) return;

    final validDrops = _getValidDropMoves(pieceType);
    final bool canDrop = validDrops.any((m) => m[0] == coord.$1 && m[1] == coord.$2);
    if (!canDrop) return;

    _dropPiece(pieceType: pieceType, toFile: coord.$1, toRank: coord.$2);
  }

  void _onHandPanCancel() {
    if (!_isDraggingPiece || !_dragIsFromHand) return;

    setState(() {
      _isDraggingPiece = false;
      _dragIsFromHand = false;
      _dragFile = null;
      _dragRank = null;
      _dragPieceCode = null;
      _dragHandPieceType = null;
      _selectedHandPiece = null;
      _selectedFile = null;
      _selectedRank = null;
    });
  }

  void _handleSquareClick(int file, int rank) {
    if (current == null) return;
    final currentState = current!.state;
    final String? clickedPiece = currentState.grid[rank - 1][9 - file];
    final currentPlayer = currentState.nextPlayer;

    setState(() {
      if (_selectedHandPiece != null) {
        if (clickedPiece == null) {
          final validDrops = _getValidDropMoves(_selectedHandPiece!);
          final bool canDrop = validDrops.any((m) => m[0] == file && m[1] == rank);
          if (canDrop) {
            final pieceType = _selectedHandPiece!;
            _selectedHandPiece = null;
            _dropPiece(pieceType: pieceType, toFile: file, toRank: rank);
            return;
          }
          _selectedHandPiece = null;
        } else {
          _selectedHandPiece = null;
          _selectPieceIfOwn(clickedPiece, file, rank, currentPlayer);
        }
      } else {
        if (_selectedFile == null) {
          _selectPieceIfOwn(clickedPiece, file, rank, currentPlayer);
        } else {
          if (_selectedFile == file && _selectedRank == rank) {
            _selectedFile = null;
            _selectedRank = null;
          } else if (clickedPiece != null && _isOwnPiece(clickedPiece, currentPlayer)) {
            _selectedFile = file;
            _selectedRank = rank;
          } else {
            final validMoves = _getValidMoves(_selectedFile!, _selectedRank!);
            final bool canMove = validMoves.any((m) => m[0] == file && m[1] == rank);
            if (canMove) {
              final fromFile = _selectedFile!;
              final fromRank = _selectedRank!;
              _selectedFile = null;
              _selectedRank = null;
              _movePiece(fromFile: fromFile, fromRank: fromRank, toFile: file, toRank: rank);
              return;
            }
            _selectedFile = null;
            _selectedRank = null;
          }
        }
      }
    });
  }

  bool _isOwnPiece(String pieceCode, Player player) {
    if (player == Player.sente && pieceCode.startsWith('b')) return true;
    if (player == Player.gote && pieceCode.startsWith('w')) return true;
    return false;
  }

  void _selectPieceIfOwn(String? pieceCode, int file, int rank, Player player) {
    if (pieceCode != null && _isOwnPiece(pieceCode, player)) {
      _selectedFile = file;
      _selectedRank = rank;
    }
  }

  String _getKanjiNameFromCode(String code) {
    final type = code.substring(1);
    switch (type) {
      case 'fu': return '歩';
      case 'ya': return '香';
      case 'ke': return '桂';
      case 'gi': return '銀';
      case 'ki': return '金';
      case 'ka': return '角';
      case 'hi': return '飛';
      case 'gy': return '玉';
      case 'to': return 'と金';
      case 'ny': return '成香';
      case 'nk': return '成桂';
      case 'ng': return '成銀';
      case 'um': return '馬';
      case 'ry': return '龍';
      default: return '歩';
    }
  }

  String _getKanjiNameFromHandCode(String type) {
    switch (type) {
      case 'fu': return '歩';
      case 'ya': return '香';
      case 'ke': return '桂';
      case 'gi': return '銀';
      case 'ki': return '金';
      case 'ka': return '角';
      case 'hi': return '飛';
      default: return '歩';
    }
  }

  Future<void> _movePiece({
    required int fromFile,
    required int fromRank,
    required int toFile,
    required int toRank,
  }) async {
    final currentState = current!.state;
    final String? movingPiece = currentState.grid[fromRank - 1][9 - fromFile];
    if (movingPiece == null) return;

    final isSente = movingPiece.startsWith('b');
    final String originalType = movingPiece.substring(1);

    const cannotPromoteTypes = {'ki', 'gy', 'to', 'ny', 'nk', 'ng', 'um', 'ry'};
    final bool canPromoteType = !cannotPromoteTypes.contains(originalType);

    final bool isFromInEnemyCamp = isSente ? (fromRank <= 3) : (fromRank >= 7);
    final bool isToInEnemyCamp = isSente ? (toRank <= 3) : (toRank >= 7);
    final bool isPromotionZone = isFromInEnemyCamp || isToInEnemyCamp;

    bool shouldPromote = false;

    if (canPromoteType && isPromotionZone) {
      final bool mustPromote = (originalType == 'fu' || originalType == 'ya') && (isSente ? toRank == 1 : toRank == 9) ||
          (originalType == 'ke' && (isSente ? toRank <= 2 : toRank >= 8));

      if (mustPromote) {
        shouldPromote = true;
      } else {
        final bool? result = await _showPromotionMenu(context, movingPiece, _lastTapGlobalPosition);
        if (result == null) return;
        shouldPromote = result;
      }
    }

    String pieceKanji = _getKanjiNameFromCode(movingPiece);
    if (shouldPromote) {
      if (pieceKanji == '歩') pieceKanji = 'と';
      else if (pieceKanji == '飛') pieceKanji = '龍';
      else if (pieceKanji == '角') pieceKanji = '馬';
      else pieceKanji = '成$pieceKanji';
    }

    final BoardState nextState = currentState.movePiece(
      fromX: fromFile,
      fromY: fromRank,
      toX: toFile,
      toY: toRank,
      pieceName: pieceKanji,
    );

    if (!mounted) return;
    await _commitMove(nextState);
  }

  Future<void> _dropPiece({
    required String pieceType,
    required int toFile,
    required int toRank,
  }) async {
    final currentState = current!.state;
    final String pieceKanji = _getKanjiNameFromHandCode(pieceType);

    final BoardState nextState = currentState.movePiece(
      fromX: null,
      fromY: null,
      toX: toFile,
      toY: toRank,
      pieceName: pieceKanji,
    );

    await _commitMove(nextState);
  }

  List<List<int>> _getValidMoves(int fromFile, int fromRank) {
    if (current == null) return [];
    return ShogiRuleHelper.getValidMoves(
      boardState: current!.state,
      fromFile: fromFile,
      fromRank: fromRank,
    );
  }

  List<List<int>> _getValidDropMoves(String pieceType) {
    if (current == null) return [];
    return ShogiRuleHelper.getValidDropMoves(
      boardState: current!.state,
      pieceType: pieceType,
    );
  }

  /// 指した結果を統合ツリーに反映する。
  /// 既存の枝（同じ指し手 or 同じ結果局面）に乗るか、新しい枝を生やして永続化する。
  Future<void> _commitMove(BoardState nextState) async {
    final t = tree;
    final parentNode = current;
    if (t == null || parentNode == null) return;

    final parentKey = parentNode.positionKey;
    final parentPositionId = parentKey == null ? null : t.positionIdByKey[parentKey];
    if (parentPositionId == null) {
      ShowErrorSnackbar.show(context, '統合ツリーへの登録に失敗しました');
      return;
    }

    // 既存の子に乗れるか
    GameNode? existing = _findExistingChild(parentNode, nextState);
    if (existing != null) {
      _selectNode(existing);
      return;
    }

    // 新しい枝として登録（局面・エッジはどの棋譜にも属さない）
    final result = await IntegratedTreeService.playMove(
      parentNode: parentNode,
      parentPositionId: parentPositionId,
      nextState: nextState,
    );
    if (result == null) {
      if (mounted) ShowErrorSnackbar.show(context, '統合ツリーへの登録に失敗しました');
      return;
    }

    final child = result.$1;
    final childPositionId = result.$2;

    if (!mounted) return;
    setState(() {
      parentNode.addChild(child);
      parentNode.selectedBranchIndex = parentNode.nextNodes.length - 1;
      if (child.positionKey != null) {
        t.positionIdByKey[child.positionKey!] = childPositionId;
      }
      current = child;
      _clearSelectionState();
    });
  }

  /// 既存の子ノードのうち、同じ指し手コード or 同じ結果局面に一致するものを探す
  GameNode? _findExistingChild(GameNode parentNode, BoardState nextState) {
    final childKey = SfenGenerator.generateKey(nextState);
    final moveLabel = SfenGenerator.moveCode(
      fromState: parentNode.state,
      toState: nextState,
      fallbackLabel: '',
    );

    for (final child in parentNode.nextNodes) {
      if (moveLabel.isNotEmpty && child.moveLabel == moveLabel) return child;
    }
    for (final child in parentNode.nextNodes) {
      if (child.positionKey == childKey) return child;
    }
    return null;
  }

  // ─── ダイヤル（手数ボックスのドラッグ操作） ───

  void _processDialPanUpdate(DragUpdateDetails details) {
    if (current == null) return;
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
      if (current!.nextNodes.isNotEmpty) {
        final node = current!;
        setState(() {
          current = node.nextNodes[node.selectedBranchIndex];
          _clearSelectionState();
        });
        HapticFeedback.selectionClick();
      }
      _dialAccumulator -= threshold;
    }

    while (_dialAccumulator <= -threshold) {
      if (current!.parent != null) {
        setState(() {
          current = current!.parent;
          _clearSelectionState();
        });
        HapticFeedback.selectionClick();
      }
      _dialAccumulator += threshold;
    }
  }

  Widget _buildLargeOverlayDial() {
    final bool hasBranch = (current?.nextNodes.length ?? 0) > 1;

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

  // ─── UI（再生画面と同一骨格） ───

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings();

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasLoadError) {
      return const Scaffold(
        body: Center(child: Text('統合ツリーの読み込みに失敗しました')),
      );
    }

    _refreshPositionInfoIfNeeded();

    // ドラッグ中の駒の画像（盤上の駒・持ち駒の両方）
    final bool isDragging = _isDraggingPiece && _dragPieceCode != null;
    String dragAsset = _dragPieceCode ?? '';
    if (!_dragIsFromHand && _isReversed) {
      if (dragAsset.startsWith('b')) {
        dragAsset = dragAsset.replaceFirst('b', 'w');
      } else if (dragAsset.startsWith('w')) {
        dragAsset = dragAsset.replaceFirst('w', 'b');
      }
    }
    final double dragCellSize = (_boardConstraints?.maxWidth ?? 0) / 9;
    final Offset? dragOverlayLocal =
        isDragging ? _localPositionFromGlobal(_dragGlobalPosition, _dragOverlayKey) : null;

    Widget boardArea = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: AspectRatio(
        aspectRatio: 0.93,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _boardConstraints = constraints;

            return GestureDetector(
              key: _boardKey,
              onTapUp: (details) => _onBoardTap(details, constraints),
              onPanStart: (details) => _onBoardPanStart(details, constraints),
              onPanUpdate: _onBoardPanUpdate,
              onPanEnd: (_) => _onBoardPanEnd(constraints),
              onPanCancel: _onBoardPanCancel,
              child: KifBoard(
                state: current!.state,
                isReversed: _isReversed,
                selectedX: _selectedFile,
                selectedY: _selectedRank,
                draggingX: _dragFile,
                draggingY: _dragRank,
                validMoves: (_selectedFile != null && _selectedRank != null)
                    ? _getValidMoves(_selectedFile!, _selectedRank!)
                    : (_selectedHandPiece != null)
                        ? _getValidDropMoves(_selectedHandPiece!)
                        : null,
              ),
            );
          },
        ),
      ),
    );

    Widget commentField = Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Stack(
        children: [
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
              onTap: _showCommentEditDialog,
              child: Scrollbar(
                controller: _commentScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _commentScrollController,
                  child: Linkify(
                    text: "${current!.joinedComment}",
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
                    onOpen: (link) async {
                      final url = Uri.parse(link.url);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        if (mounted) ShowErrorSnackbar.show(context, 'リンクを開けませんでした');
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          // ドラッグ時にコメント欄の上に浮かぶ文字なし大型ダイヤル
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
    );

    return Scaffold(
      body: Stack(
        key: _dragOverlayKey,
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildPlayerAndKomaDai(
                  playerName: _isReversed ? '後手' : '先手',
                  isSente: _isReversed,
                  isUpper: true,
                ),
                boardArea,
                _buildPlayerAndKomaDai(
                  playerName: _isReversed ? '先手' : '後手',
                  isSente: !_isReversed,
                  isUpper: false,
                ),
                Expanded(child: commentField),
                _buildControlPanel(),
              ],
            ),
          ),
          // 画面左端からの右スワイプで左サイドバーを開く
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 24,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 100) {
                  _openLeftSidebar();
                }
              },
            ),
          ),
          // 出現する棋譜の左サイドバー（②の「出現一覧」を再利用）
          AppearanceSidebar(
            open: _isLeftSidebarOpen,
            appearances: _appearances,
            kifById: _kifById,
            isCurrent: (appearance) => appearance.moveNumber == _currentMoveNumber,
            onTap: _handleAppearanceTap,
            onClose: () {
              setState(() {
                _isLeftSidebarOpen = false;
              });
            },
          ),
          if (_isRightSidebarOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isRightSidebarOpen = false;
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
            right: _isRightSidebarOpen ? 0 : -MediaQuery.of(context).size.width * 0.85,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.85,
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
                            '統合ツリー',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown[800],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _isTreeDeleteMode = !_isTreeDeleteMode;
                              });
                            },
                            icon: Icon(
                              _isTreeDeleteMode
                                  ? Icons.visibility
                                  : Icons.delete_outline,
                              size: 18,
                              color: _isTreeDeleteMode
                                  ? Colors.red[600]
                                  : Colors.brown[800],
                            ),
                            label: Text(
                              _isTreeDeleteMode ? '参照モードへ' : '削除モード',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _isTreeDeleteMode
                                    ? Colors.red[600]
                                    : Colors.brown[800],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _isRightSidebarOpen = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: KifTreeView(
                        rootNode: tree!.root,
                        currentNode: current!,
                        showBranchIcon: false, // 統合ツリー表示では分岐アイコンを付けない
                        flatNodeCards: true, // 統合ツリー表示のノードは影なし・背景白
                        onNodeSelected: _selectNode,
                        // 削除モードの間だけ × ボタンを表示（参照モードでは null で非表示）
                        onNodeDeleted:
                            _isTreeDeleteMode ? _removeTreeNode : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ドラッグ中の駒が指位置に追従して描画される
          if (isDragging && dragOverlayLocal != null)
            Positioned(
              left: dragOverlayLocal.dx - dragCellSize / 2,
              top: dragOverlayLocal.dy - dragCellSize / 2,
              width: dragCellSize,
              height: dragCellSize,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.7,
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Image.asset(
                      'assets/images/pieces/$dragAsset.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    final parentNode = current!.parent;
    final parentState = parentNode?.state;
    final String moveLabel = current!.moveLabel != null && current!.moveLabel!.isNotEmpty
        ? KifParser.convertToJapanese(
            current!.moveLabel!,
            lastToX: parentState?.lastMoveToX,
            lastToY: parentState?.lastMoveToY,
          )
        : '開始局面';

    return Container(
      color: const Color(0XFFF1F1F5),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          // 0. 他棋譜ピル（最左。現在局面が棋譜に出現する場合のみ表示）
          Expanded(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _hasAppearance
                  ? GestureDetector(
                      onTap: _openLeftSidebar,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black45, width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final char in '他棋譜'.split(''))
                              Text(
                                char,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  height: 1.1,
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(width: 24, height: 40),
            ),
          ),

          // 1. 根へ戻るボタン（⏮ は根＝開始局面へ）
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.first_page),
                onPressed: _isAtRoot ? null : _jumpToRoot,
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
                onPressed: _isAtRoot ? null : _stepBack,
              ),
            ),
          ),

          // 3. 中央の手数表示枠（根からの手数。タップで統合ツリー、ドラッグでダイヤル）
          Expanded(
            flex: 3,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 90),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!_isOverlayDialActive) {
                    _openRightSidebar();
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
                    final bool hasBranch = current!.nextNodes.length > 1;
                    final int currentMove = _currentMoveNumber;

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
                              currentMove == 0 ? '開始局面' : '${currentMove}手目',
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
                onPressed: _isAtLeaf ? null : _stepNext,
              ),
            ),
          ),

          // 5. 最後まで進むボタン
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.last_page),
                onPressed: _isAtLeaf ? null : _jumpToLast,
              ),
            ),
          ),

          // 6. メニュー（三点リーダー）。削除操作は④で扱うため含めない
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
                    leadingIcon: const Icon(Icons.account_tree, size: 20),
                    child: const Text('根を選び直す'),
                    onPressed: () {
                      Navigator.of(context, rootNavigator: false).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const IntegratedTreeRootPage(),
                        ),
                        (route) => route.isFirst,
                      );
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
        ? current!.state.senteHand
        : current!.state.goteHand;
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

    final Player currentPlayer = current!.state.nextPlayer;
    final bool isOwnTurn = (currentPlayer == Player.sente && isSente) ||
        (currentPlayer == Player.gote && !isSente);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: slots.map((entry) {
        if (entry == null) {
          return const Expanded(flex: 1, child: SizedBox.shrink());
        }

        final isSelected = _selectedHandPiece == entry.key && isOwnTurn;

        return Expanded(
          flex: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double size = constraints.maxWidth.clamp(16.0, 32.0);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedHandPiece = null;
                    } else if (isOwnTurn) {
                      _selectedHandPiece = entry.key;
                      _selectedFile = null;
                      _selectedRank = null;
                    }
                  });
                },
                onPanStart: (details) =>
                    _onHandPanStart(details, entry.key, '$assetPrefix${entry.key}', isOwnTurn),
                onPanUpdate: _onHandPanUpdate,
                onPanEnd: (_) => _onHandPanEnd(),
                onPanCancel: _onHandPanCancel,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.orange.withOpacity(0.4) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Image.asset(
                          'assets/images/pieces/$assetPrefix${entry.key}.png',
                          width: size,
                          height: size,
                          fit: BoxFit.contain,
                        ),
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
                ),
              );
            },
          ),
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

  Future<bool?> _showPromotionMenu(BuildContext context, String movingPiece, Offset tapPosition) {
    final isSente = movingPiece.startsWith('b');
    final String prefix = isSente ? 'b' : 'w';
    final String type = movingPiece.substring(1);

    final String normalPieceAsset = '$prefix$type';
    String promotedPieceType = '';
    switch (type) {
      case 'fu': promotedPieceType = 'to'; break;
      case 'ya': promotedPieceType = 'ny'; break;
      case 'ke': promotedPieceType = 'nk'; break;
      case 'gi': promotedPieceType = 'ng'; break;
      case 'ka': promotedPieceType = 'um'; break;
      case 'hi': promotedPieceType = 'ry'; break;
      default: promotedPieceType = type;
    }
    final String promotedPieceAsset = '$prefix$promotedPieceType';

    const double dialogWidth = 150.0;
    const double dialogHeight = 90.0;
    const double margin = 12.0;

    final screenSize = MediaQuery.of(context).size;

    double left = tapPosition.dx - (dialogWidth / 2);
    double top = tapPosition.dy - dialogHeight - 10;

    left = left.clamp(margin, screenSize.width - dialogWidth - margin);

    if (top < margin) {
      top = tapPosition.dy + 20;
    }
    top = top.clamp(margin, screenSize.height - dialogHeight - margin);

    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  width: dialogWidth,
                  color: Theme.of(context).cardColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(true),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: Image.asset(
                                  'assets/images/pieces/$promotedPieceAsset.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('成', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).pop(false),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: Image.asset(
                                  'assets/images/pieces/$normalPieceAsset.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('不成', style: TextStyle(fontSize: 11, color: Colors.black87)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
