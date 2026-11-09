import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/dialogs/comment_edit_dialog.dart';
import 'package:kifdamari/dialogs/discard_changes_dialog.dart';
import 'package:kifdamari/logic/shogi_rule_helper.dart';
import 'package:kifdamari/models/kif_tree.dart';
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/logic/saf_helper.dart';
import 'package:kifdamari/snackbars/show_error_snackbar.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';
import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/kif_board.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/models/game_node.dart';
import 'package:kifdamari/widgets/kif_tree_view.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class KifEditorPage extends StatefulWidget {
  final KifEntity kifEntity;
  final int initialMoveNumber;
  final List<int>? initialBranchPath;

  const KifEditorPage({
    super.key,
    required this.kifEntity,
    this.initialMoveNumber = 0,
    this.initialBranchPath,
  });

  @override
  State<KifEditorPage> createState() => _KifEditorPageState();
}

class _KifEditorPageState extends State<KifEditorPage> {
  KifTree? kifTree;
  bool _isLoading = true;
  bool _isReversed = false;

  late KifEntity _currentEntity;

  int? _selectedFile;
  int? _selectedRank;
  String? _selectedHandPiece;

  // ダイヤル操作用の変数
  double _dialRotation = 0.0;
  double _dialAccumulator = 0.0;
  bool _isOverlayDialActive = false; // コメント欄オーバーレイ表示フラグ
  final GlobalKey _overlayDialKey = GlobalKey();

  bool _isSidebarOpen = false;
  Offset _lastTapGlobalPosition = Offset.zero;

  // 盤上の駒・持ち駒のドラッグ中の状態
  bool _isDraggingPiece = false;
  int? _dragFile;
  int? _dragRank;
  String? _dragPieceCode;
  Offset _dragGlobalPosition = Offset.zero;
  Offset _dragLocalPosition = Offset.zero;

  // 持ち駒のドラッグ中の状態
  bool _dragIsFromHand = false;
  String? _dragHandPieceType;
  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _dragOverlayKey = GlobalKey();
  BoxConstraints? _boardConstraints;

  // 最後にファイルに書き込んだ、または読み込んだ時の状態比較用文字列
  String _lastSavedContent = '';
  // 現在編集中の状態が保存された状態と一致しているか
  bool _isSaved = true;

  // コメント入力欄を制御するコントローラー
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentEntity = widget.kifEntity;
    _initKifData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _getExportContent() {
    if (kifTree == null) return '';
    final encoded = KifParser.encode(kifTree!);

    final StringBuffer commentBuffer = StringBuffer();
    void collectComments(GameNode node) {
      if (node.comments.isNotEmpty) {
        commentBuffer.write('node_${node.moveNumber}_${node.comments.join(",")}');
      }
      for (final child in node.nextNodes) {
        collectComments(child);
      }
    }

    collectComments(kifTree!.root);

    return '$encoded\n__COMMENTS_HASH__:${commentBuffer.toString()}';
  }

  void _syncCommentFromCurrentNode() {
    if (kifTree != null) {
      _commentController.text = kifTree!.currentNode.joinedComment;
    }
  }

  void _checkSaveStatus() {
    if (kifTree == null) return;
    final currentContent = _getExportContent();
    if (_lastSavedContent.isEmpty) {
      _isSaved = false;
    } else {
      _isSaved = currentContent == _lastSavedContent;
    }
  }

  Future<void> _initKifData() async {
    final String? path = _currentEntity.kifPath;
    if (path == null || path.isEmpty) {
      setState(() {
        kifTree = KifTree.initial();
        _lastSavedContent = _getExportContent();
        _isSaved = true;
        _isLoading = false;
        _syncCommentFromCurrentNode();
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
        } catch (_) {
          content = await CharsetConverter.decode("Shift_JIS", bytes);
        }
        final tree = KifParser.decode(content);

        if (widget.initialBranchPath != null && widget.initialBranchPath!.isNotEmpty) {
          GameNode temp = tree.root;
          for (final branchIndex in widget.initialBranchPath!) {
            if (branchIndex >= 0 && branchIndex < temp.nextNodes.length) {
              temp.selectedBranchIndex = branchIndex;
              temp = temp.nextNodes[branchIndex];
            } else {
              break;
            }
          }
          tree.currentNode = temp;
        } else {
          tree.jumpTo(widget.initialMoveNumber);
        }

        setState(() {
          kifTree = tree;
          _lastSavedContent = _getExportContent();
          _isSaved = true;
          _isLoading = false;
          _syncCommentFromCurrentNode();
        });
      } else {
        throw Exception("ファイルが見つからないか読み込めません");
      }
    } catch (e) {
      debugPrint("KIF解析エラー: $e");
      setState(() {
        kifTree = KifTree.initial();
        _lastSavedContent = _getExportContent();
        _isSaved = true;
        _isLoading = false;
        _syncCommentFromCurrentNode();
      });
    }
  }

  Future<void> _openLocalFile() async {
    try {
      final String? targetPath = await SafHelper.pickFile();
      if (targetPath == null || targetPath.isEmpty) return;

      Uint8List? bytes;
      if (targetPath.startsWith('content://')) {
        bytes = await SafHelper.readFileBytes(targetPath);
      } else {
        final file = File(targetPath);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }

      if (bytes == null) {
        if (mounted) ShowErrorSnackbar.show(context, 'ファイルの読み込みに失敗しました');
        return;
      }

      String content;
      try {
        content = utf8.decode(bytes, allowMalformed: false);
      } catch (_) {
        content = await CharsetConverter.decode("Shift_JIS", bytes);
      }

      final tree = KifParser.decode(content);

      if (!mounted) return;

      setState(() {
        kifTree = tree;
        _selectedFile = null;
        _selectedRank = null;
        _selectedHandPiece = null;
        _syncCommentFromCurrentNode();

        _currentEntity = KifEntity(
          id: _currentEntity.id,
          tabId: _currentEntity.tabId,
          kifId: _currentEntity.kifId,
          title: _currentEntity.title,
          detail: _currentEntity.detail,
          kifOrder: _currentEntity.kifOrder,
          kifPath: targetPath,
          imgPath: _currentEntity.imgPath,
          color: _currentEntity.color,
        );

        _lastSavedContent = _getExportContent();
        _isSaved = true;
      });

      if (mounted) {
        ShowSuccessSnackbar.show(context, '棋譜ファイルを読み込みました');
      }
    } catch (e) {
      debugPrint("ファイル読み込みエラー: $e");
      if (mounted) {
        ShowErrorSnackbar.show(context, 'ファイルの読み込み・解析に失敗しました');
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text;

    if (text == null || text.trim().isEmpty) {
      if (mounted) {
        ShowErrorSnackbar.show(context, 'クリップボードにテキストがありません');
      }
      return;
    }

    try {
      final tree = KifParser.decode(text);

      if (!mounted) return;

      setState(() {
        kifTree = tree;
        _selectedFile = null;
        _selectedRank = null;
        _selectedHandPiece = null;
        _syncCommentFromCurrentNode();
        _lastSavedContent = '';
        _isSaved = false;
      });

      if (mounted) {
        ShowSuccessSnackbar.show(context, 'クリップボードから棋譜を読み込みました');
      }
    } catch (e) {
      debugPrint("クリップボードからの棋譜解析エラー: $e");
      if (mounted) {
        ShowErrorSnackbar.show(context, '棋譜データの解析に失敗しました');
      }
    }
  }

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

  /// グローバル座標を指定したウィジェットのローカル座標に変換する。
  Offset? _localPositionFromGlobal(Offset globalPosition, GlobalKey key) {
    final RenderBox? box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.globalToLocal(globalPosition);
  }

  void _onBoardTap(TapUpDetails details, BoxConstraints constraints) {
    if (kifTree == null) return;

    _lastTapGlobalPosition = details.globalPosition;

    final coord = _boardCoordsFromLocal(details.localPosition, constraints);
    if (coord == null) return;

    _handleSquareClick(coord.$1, coord.$2);
  }

  void _onBoardPanStart(DragStartDetails details, BoxConstraints constraints) {
    if (kifTree == null) return;
    if (_dragIsFromHand) return;

    final coord = _boardCoordsFromLocal(details.localPosition, constraints);
    if (coord == null) return;

    final int file = coord.$1;
    final int rank = coord.$2;

    final currentState = kifTree!.currentNode.state;
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

    setState(() {
      _isDraggingPiece = false;
      _dragFile = null;
      _dragRank = null;
      _dragPieceCode = null;
      _selectedFile = null;
      _selectedRank = null;
    });

    if (fromFile == null || fromRank == null) return;

    final coord = _boardCoordsFromLocal(_dragLocalPosition, constraints);
    if (coord == null || (coord.$1 == fromFile && coord.$2 == fromRank)) return;

    final validMoves = _getValidMoves(fromFile, fromRank);
    final bool canMove = validMoves.any((m) => m[0] == coord.$1 && m[1] == coord.$2);
    if (!canMove) return;

    _lastTapGlobalPosition = _dragGlobalPosition;

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

  /// 持ち駒のドラッグ開始（駒台）。有効な駒のみ（タップ選択と同じ条件）。
  void _onHandPanStart(DragStartDetails details, String pieceType, String assetCode, bool isOwnTurn) {
    if (kifTree == null || !isOwnTurn) return;

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

  /// 持ち駒のドラッグ終了。盤上の打てるマスなら _dropPiece で打ち、それ以外はキャンセル。
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

    if (pieceType == null || kifTree == null) return;

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
    final currentState = kifTree!.currentNode.state;
    final String? clickedPiece = currentState.grid[rank - 1][9 - file];
    final currentPlayer = currentState.nextPlayer;

    setState(() {
      if (_selectedHandPiece != null) {
        if (clickedPiece == null) {
          final validDrops = _getValidDropMoves(_selectedHandPiece!);
          final bool canDrop = validDrops.any((m) => m[0] == file && m[1] == rank);
          if (canDrop) {
            _dropPiece(pieceType: _selectedHandPiece!, toFile: file, toRank: rank);
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
              _movePiece(fromFile: _selectedFile!, fromRank: _selectedRank!, toFile: file, toRank: rank);
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

  void _movePiece({required int fromFile, required int fromRank, required int toFile, required int toRank}) async {
    final currentState = kifTree!.currentNode.state;
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
        if (mounted) {
          final bool? result = await _showPromotionMenu(context, movingPiece, _lastTapGlobalPosition);
          if (result == null) return;
          shouldPromote = result;
        }
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

    setState(() {
      final int nextMoveNumber = kifTree!.currentNode.moveNumber + 1;
      final String promoteFlag = shouldPromote ? '+' : '';
      final String label = "$fromFile$fromRank$toFile$toRank$originalType$promoteFlag";

      final String targetMovedPiece = nextState.grid[toRank - 1][9 - toFile] ?? '';

      final existingNodeIndex = kifTree!.currentNode.nextNodes.indexWhere((node) {
        final state = node.state;
        if (state.lastMoveToX != toFile || state.lastMoveToY != toRank) return false;
        final nodePiece = state.grid[toRank - 1][9 - toFile] ?? '';
        return nodePiece == targetMovedPiece;
      });

      if (existingNodeIndex != -1) {
        kifTree!.currentNode.selectedBranchIndex = existingNodeIndex;
        kifTree!.currentNode = kifTree!.currentNode.nextNodes[existingNodeIndex];
      } else {
        final newNode = GameNode(
          moveNumber: nextMoveNumber,
          state: nextState,
          moveLabel: label,
          parent: kifTree!.currentNode,
        );

        kifTree!.currentNode.nextNodes.add(newNode);
        kifTree!.currentNode.selectedBranchIndex = kifTree!.currentNode.nextNodes.length - 1;
        kifTree!.currentNode = newNode;
      }

      _syncCommentFromCurrentNode();
      _checkSaveStatus();
    });
  }

  void _dropPiece({required String pieceType, required int toFile, required int toRank}) {
    final currentState = kifTree!.currentNode.state;
    final String pieceKanji = _getKanjiNameFromHandCode(pieceType);

    final BoardState nextState = currentState.movePiece(
      fromX: null,
      fromY: null,
      toX: toFile,
      toY: toRank,
      pieceName: pieceKanji,
    );

    setState(() {
      final int nextMoveNumber = kifTree!.currentNode.moveNumber + 1;
      final String label = "+$toFile$toRank$pieceType";

      final String targetMovedPiece = nextState.grid[toRank - 1][9 - toFile] ?? '';

      final existingNodeIndex = kifTree!.currentNode.nextNodes.indexWhere((node) {
        final state = node.state;
        if (state.lastMoveToX != toFile || state.lastMoveToY != toRank) return false;
        final nodePiece = state.grid[toRank - 1][9 - toFile] ?? '';
        return nodePiece == targetMovedPiece;
      });

      if (existingNodeIndex != -1) {
        kifTree!.currentNode.selectedBranchIndex = existingNodeIndex;
        kifTree!.currentNode = kifTree!.currentNode.nextNodes[existingNodeIndex];
      } else {
        final newNode = GameNode(
          moveNumber: nextMoveNumber,
          state: nextState,
          moveLabel: label,
          parent: kifTree!.currentNode,
        );

        kifTree!.currentNode.nextNodes.add(newNode);
        kifTree!.currentNode.selectedBranchIndex = kifTree!.currentNode.nextNodes.length - 1;
        kifTree!.currentNode = newNode;
      }

      _syncCommentFromCurrentNode();
      _checkSaveStatus();
    });
  }

  List<List<int>> _getValidMoves(int fromFile, int fromRank) {
    if (kifTree == null) return [];
    return ShogiRuleHelper.getValidMoves(
      boardState: kifTree!.currentNode.state,
      fromFile: fromFile,
      fromRank: fromRank,
    );
  }

  List<List<int>> _getValidDropMoves(String pieceType) {
    if (kifTree == null) return [];
    return ShogiRuleHelper.getValidDropMoves(
      boardState: kifTree!.currentNode.state,
      pieceType: pieceType,
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
          _selectedFile = null;
          _selectedRank = null;
          _selectedHandPiece = null;
          _syncCommentFromCurrentNode();
        });
        HapticFeedback.selectionClick();
      }
      _dialAccumulator -= threshold;
    }

    while (_dialAccumulator <= -threshold) {
      if (kifTree != null && kifTree!.currentNode.parent != null) {
        setState(() {
          kifTree!.stepBack();
          _selectedFile = null;
          _selectedRank = null;
          _selectedHandPiece = null;
          _syncCommentFromCurrentNode();
        });
        HapticFeedback.selectionClick();
      }
      _dialAccumulator += threshold;
    }
  }

  Widget _buildControlPanel() {
    return Container(
      color: const Color(0XFFF1F1F5),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.first_page),
                onPressed: () => setState(() {
                  kifTree!.jumpTo(0);
                  _selectedFile = null;
                  _selectedRank = null;
                  _selectedHandPiece = null;
                  _syncCommentFromCurrentNode();
                }),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_left),
                iconSize: 36,
                onPressed: () => setState(() {
                  kifTree!.stepBack();
                  _selectedFile = null;
                  _selectedRank = null;
                  _selectedHandPiece = null;
                  _syncCommentFromCurrentNode();
                }),
              ),
            ),
          ),
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

                  final rawLabel = kifTree!.currentNode.moveLabel;
                  final parentState = kifTree!.currentNode.parent?.state;
                  final displayLabel = rawLabel != null && rawLabel.isNotEmpty
                      ? KifParser.convertToJapanese(
                          rawLabel,
                          lastToX: parentState?.lastMoveToX,
                          lastToY: parentState?.lastMoveToY,
                        )
                      : '開始局面';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasBranch ? Colors.orange[100] : Colors.white,
                      border: Border.all(
                        color: hasBranch ? Colors.orange[700]! : Colors.black45,
                        width: hasBranch ? 2.0 : 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${kifTree!.currentNode.moveNumber}手目',
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayLabel,
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
                },
              ),
            ),
            ),
          ),
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_right),
                iconSize: 36,
                onPressed: () => setState(() {
                  kifTree!.stepNext();
                  _selectedFile = null;
                  _selectedRank = null;
                  _selectedHandPiece = null;
                  _syncCommentFromCurrentNode();
                }),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.last_page),
                onPressed: () => setState(() {
                  kifTree!.jumpTo(kifTree!.totalMoveCount);
                  _selectedFile = null;
                  _selectedRank = null;
                  _selectedHandPiece = null;
                  _syncCommentFromCurrentNode();
                }),
              ),
            ),
          ),
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
                    leadingIcon: const Icon(Icons.folder_open, size: 20),
                    child: const Text('棋譜ファイルを開く'),
                    onPressed: _openLocalFile,
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.content_paste, size: 20),
                    child: const Text('クリップボードから貼り付け'),
                    onPressed: _pasteFromClipboard,
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.save, size: 20),
                    child: const Text('保存する'),
                    onPressed: _saveKifData,
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

  void _showCommentEditDialog() async {
    final oldComment = kifTree!.currentNode.joinedComment;
    final result = await showCommentEditDialog(context, oldComment);
    if (result == null || !mounted) return;
    setState(() {
      kifTree!.currentNode.comments.clear();
      kifTree!.currentNode.comments.addAll(result);
      _syncCommentFromCurrentNode();
      _checkSaveStatus();
    });
  }

  Widget _buildCommentField() {
    final settings = AppSettings();
    final String currentComment = kifTree!.currentNode.joinedComment;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showCommentEditDialog,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: IgnorePointer(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Text(
                    currentComment.isEmpty ? 'タップしてこの局面のコメントを入力' : currentComment,
                    style: TextStyle(
                      fontSize: settings.get<double>('fontSize'),
                      color: currentComment.isEmpty ? Colors.grey[400] : Colors.black87,
                    ),
                    strutStyle: StrutStyle(
                      fontSize: settings.get<double>('fontSize'),
                      height: 1.5,
                      forceStrutHeight: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 文字なし仕様の大型ダイヤルウィジェット
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
                left: 53,
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
              Positioned(left: 57.5, top: 102.5, child: _buildDialDot()),
              Positioned(left: 12.5, top: 57.5, child: _buildDialDot()),
              Positioned(left: 102.5, top: 57.5, child: _buildDialDot()),
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

  /// 戻る操作（PopScope / AppBarの戻るボタン）からの共通の終了処理。
  /// 未保存の変更がある場合は確認ダイアログを表示する。
  Future<void> _handleBackNavigation() async {
    if (!_isSaved) {
      final bool confirmed = await showDiscardChangesDialog(context);
      if (!confirmed) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(_currentEntity);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || kifTree == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final double sidebarWidth = MediaQuery.of(context).size.width * 0.85;

    // ドラッグ中の駒の画像（盤上の駒・持ち駒の両方）。指位置に追従して描画する。
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: const Color(0XFFF1F1F5),
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _handleBackNavigation();
            },
          ),
          backgroundColor: const Color(0XFFFFFFFF),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isSaved ? Colors.green[600] : Colors.red[600],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _isSaved ? '保存済み' : '未保存',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.content_paste),
                      tooltip: 'クリップボードから貼り付け',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      onPressed: _pasteFromClipboard,
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      tooltip: '保存',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      onPressed: _saveKifData,
                    ),
                    const SizedBox(width: 4),
                  ],
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            key: _dragOverlayKey,
            children: [
              Column(
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
                              state: kifTree!.currentNode.state,
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
                  ),
                  _buildPlayerAndKomaDai(
                    playerName: _isReversed ? (kifTree!.info['後手'] ?? '後手') : (kifTree!.info['先手'] ?? '先手'),
                    isSente: !_isReversed,
                    isUpper: false,
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildCommentField(),
                        // ドラッグ時にコメント欄の上に浮かび上がる文字なしシンプル大型ダイヤル
                        if (_isOverlayDialActive)
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                  _buildControlPanel(),
                ],
              ),
              if (_isSidebarOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _isSidebarOpen = false),
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
                                onPressed: () => setState(() => _isSidebarOpen = false),
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
                                _selectedFile = null;
                                _selectedRank = null;
                                _selectedHandPiece = null;

                                GameNode? temp = selectedNode;
                                while (temp != null && temp.parent != null) {
                                  final parent = temp.parent!;
                                  parent.selectedBranchIndex = parent.nextNodes.indexOf(temp);
                                  temp = parent;
                                }

                                _isSidebarOpen = false;
                                _syncCommentFromCurrentNode();
                              });
                            },
                            onNodeDeleted: (nodeToDelete) {
                              _deleteGameNode(nodeToDelete);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
        ),
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

    final Player currentPlayer = kifTree!.currentNode.state.nextPlayer;
    final bool isOwnTurn = (currentPlayer == Player.sente && isSente) ||
        (currentPlayer == Player.gote && !isSente);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: slots.map((entry) {
        if (entry == null) {
          return const Expanded(flex: 1, child: SizedBox.shrink());
        }

        final isSelected = _selectedHandPiece == entry.key &&
            ((kifTree!.currentNode.state.nextPlayer == Player.sente && isSente) ||
                (kifTree!.currentNode.state.nextPlayer == Player.gote && !isSente));

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
    final String key = isSente ? '先手' : '後手';

    return Align(
      alignment: alignment,
      child: InkWell(
        onTap: () => _showEditPlayerNameDialog(key: key, currentName: name),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${isSente ? '▲' : '△'}$name",
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.edit, size: 12, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditPlayerNameDialog({required String key, required String currentName}) async {
    final controller = TextEditingController(
      text: (currentName == '先手' || currentName == '後手') ? '' : currentName,
    );

    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$keyの氏名変更'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '$keyの氏名を入力',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'キャンセル',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text(
                '変更',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (newName != null && kifTree != null) {
      setState(() {
        final finalName = newName.isEmpty ? key : newName;
        kifTree!.info[key] = finalName;
        _checkSaveStatus();
      });
    }
  }

  Future<({String fileName, List<int> bytes})?> _prepareKifData() async {
    if (kifTree == null) return null;

    final String kifContent = KifParser.encode(kifTree!);
    final List<int> bytes = await CharsetConverter.encode("Shift_JIS", kifContent);

    final String fileName = "${DateTime.now().millisecondsSinceEpoch}.kif";

    return (fileName: fileName, bytes: bytes);
  }

  Map<String, String> _generateValueMap() {
    final info = kifTree?.info ?? {};
    
    final Map<String, String> values = {
      '先手': info['先手'] ?? '先手',
      '後手': info['後手'] ?? '後手',
      '棋戦': info['棋戦'] ?? info['イベント'] ?? '',
      '戦型': info['戦型'] ?? '',
      '対局日': info['対局日'] ?? info['開始日時'] ?? info['対局日時'] ?? info['日付'] ?? '',
    };

    info.forEach((key, value) {
      values[key] = value;
    });

    return values;
  }

  String _applyTemplate(String template, Map<String, String> values) {
    return template.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (match) {
      final key = match.group(1)!;
      return values[key] ?? '';
    });
  }

  String _generateTitleText() {
    final settings = AppSettings();
    final String titleTemplate = settings.get<String>('kifTitle');
    return _applyTemplate(titleTemplate, _generateValueMap());
  }

  String _generateDetailText() {
    if (kifTree == null) return widget.kifEntity.detail ?? '';

    final settings = AppSettings();
    final String detailTemplate = settings.get<String>('kifDetail');
    return _applyTemplate(detailTemplate, _generateValueMap());
  }

  Future<void> _saveKifData() async {
    final kifData = await _prepareKifData();
    if (kifData == null) return;

    setState(() => _isLoading = true);

    try {
      String targetPath = _currentEntity.kifPath ?? "";
      bool isNewFile = targetPath.isEmpty || 
          (!targetPath.startsWith('content://') && !await File(targetPath).exists());

      if (isNewFile) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final Directory saveDir = Directory(p.join(appDocDir.path, 'Kifdamari'));
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
        targetPath = p.join(saveDir.path, kifData.fileName);
      }

      if (targetPath.startsWith('content://')) {
        final success = await SafHelper.writeFileBytes(
          targetPath,
          Uint8List.fromList(kifData.bytes),
        );
        if (!success) {
          throw Exception("Google Drive 上書き保存に失敗しました");
        }
      } else {
        final file = File(targetPath);
        await file.writeAsBytes(kifData.bytes, flush: true);
      }

      final titleText = _generateTitleText();
      final detailText = _generateDetailText();

      final updatedKif = KifEntity(
        id: _currentEntity.id,
        tabId: _currentEntity.tabId,
        kifId: _currentEntity.kifId,
        title: titleText,
        detail: detailText,
        kifOrder: _currentEntity.kifOrder,
        kifPath: targetPath,
        imgPath: _currentEntity.imgPath,
        color: _currentEntity.color,
      );
      await KifDao().updateKif(updatedKif);

      _currentEntity = updatedKif;

      setState(() {
        _lastSavedContent = _getExportContent();
        _isSaved = true;
      });

      if (mounted) {
        ShowSuccessSnackbar.show(context, '棋譜を保存しました');
      }
    } catch (e) {
      debugPrint("保存エラー: $e");
      if (mounted) {
        ShowErrorSnackbar.show(context, '棋譜の保存に失敗しました');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  void _deleteGameNode(GameNode node) async {
    if (node.parent == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('指し手の削除'),
        content: Text('${node.moveNumber}手目以降の手をすべて削除しますか？\n（この操作は取り消せません）'),
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

    if (confirm != true) return;

    final parent = node.parent!;

    setState(() {
      parent.nextNodes.remove(node);

      if (_isNodeOrDescendantCurrent(node)) {
        kifTree!.currentNode = parent;
      }

      if (parent.selectedBranchIndex >= parent.nextNodes.length) {
        parent.selectedBranchIndex = (parent.nextNodes.length - 1).clamp(0, 999);
      }

      _selectedFile = null;
      _selectedRank = null;
      _selectedHandPiece = null;
      _syncCommentFromCurrentNode();
      _checkSaveStatus();
    });

    if (mounted) {
      ShowSuccessSnackbar.show(context, '指定した手を削除しました');
    }
  }

  bool _isNodeOrDescendantCurrent(GameNode targetNode) {
    GameNode? temp = kifTree?.currentNode;
    while (temp != null) {
      if (temp == targetNode) return true;
      temp = temp.parent;
    }
    return false;
  }
}
