import 'dart:convert';
import 'dart:io';
import 'package:charset_converter/charset_converter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kifdamari/database/dao/kif_dao.dart';
import 'package:kifdamari/database/entity/kif_entity.dart';
import 'package:kifdamari/dialogs/comment_edit_dialog.dart';
import 'package:kifdamari/logic/shogi_rule_helper.dart';
import 'package:kifdamari/models/kif_tree.dart';
import 'package:kifdamari/logic/kif_parser.dart';
import 'package:kifdamari/snackbars/show_error_snackbar.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';
import 'package:kifdamari/widgets/kif_board.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/models/game_node.dart';
import 'package:kifdamari/widgets/kif_tree_view.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class KifEditorPage extends StatefulWidget {
  final KifEntity kifEntity;
  final int initialMoveNumber; // 💡 再生画面からの初期表示手数を引き継ぐ

  const KifEditorPage({
    super.key,
    required this.kifEntity,
    this.initialMoveNumber = 0, // 💡 デフォルトは0手目（開始局面）
  });

  @override
  State<KifEditorPage> createState() => _KifEditorPageState();
}

class _KifEditorPageState extends State<KifEditorPage> {
  KifTree? kifTree;
  bool _isLoading = true;
  bool _isReversed = false;

  int? _selectedFile;
  int? _selectedRank;
  String? _selectedHandPiece;

  double _dragDistance = 0.0;
  bool _isSidebarOpen = false;
  Offset _lastTapGlobalPosition = Offset.zero;

  // 最後にファイルに書き込んだ、または読み込んだ時の状態比較用文字列
  String _lastSavedContent = '';
  // 現在編集中の状態が保存された状態と一致しているか
  bool _isSaved = true;

  // コメント入力欄を制御するコントローラー
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initKifData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // 💡 パーサーに含まれない0手目コメント変更等も検知できるよう、全コメントも含めた状態文字列を生成
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

  // GameNodeの仕様（joinedComment）に合わせてコメントを同期
  void _syncCommentFromCurrentNode() {
    if (kifTree != null) {
      _commentController.text = kifTree!.currentNode.joinedComment;
    }
  }

  // 現在のメモリ上の状態と、最後に保存された内容を比較してフラグを更新する
  void _checkSaveStatus() {
    if (kifTree == null) return;
    final currentContent = _getExportContent();
    _isSaved = currentContent == _lastSavedContent;
  }

  Future<void> _initKifData() async {
    final String? path = widget.kifEntity.kifPath;
    if (path == null || path.isEmpty) {
      setState(() {
        kifTree = KifTree.initial();
        _lastSavedContent = _getExportContent(); // 初期状態を記憶
        _isSaved = true;
        _isLoading = false;
        _syncCommentFromCurrentNode();
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
        } catch (_) {
          content = await CharsetConverter.decode("Shift_JIS", bytes);
        }
        final tree = KifParser.decode(content);

        // 💡 遷移元から渡された手数（56手目など）にジャンプする
        tree.jumpTo(widget.initialMoveNumber);

        setState(() {
          kifTree = tree;
          _lastSavedContent = _getExportContent(); // 読み込み時の状態を記憶
          _isSaved = true;
          _isLoading = false;
          _syncCommentFromCurrentNode();
        });
      } else {
        throw Exception("ファイルが見つかりません");
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final String filePath = result.files.single.path!;
      final extension = p.extension(filePath).toLowerCase();

      const allowedExtensions = ['.kif', '.kifu', '.txt'];
      if (!allowedExtensions.contains(extension)) {
        if (mounted) {
          ShowErrorSnackbar.show(context, '対応していないファイル形式です (.kif, .kifu, .txt)');
        }
        return;
      }

      final file = File(filePath);

      if (!await file.exists()) {
        if (mounted) ShowErrorSnackbar.show(context, 'ファイルが存在しません');
        return;
      }

      final bytes = await file.readAsBytes();
      String content;
      try {
        content = utf8.decode(bytes, allowMalformed: false);
      } catch (_) {
        content = await CharsetConverter.decode("Shift_JIS", bytes);
      }

      final tree = KifParser.decode(content);

      setState(() {
        kifTree = tree;
        _selectedFile = null;
        _selectedRank = null;
        _selectedHandPiece = null;
        _syncCommentFromCurrentNode();
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

      setState(() {
        kifTree = tree;
        _selectedFile = null;
        _selectedRank = null;
        _selectedHandPiece = null;
        _syncCommentFromCurrentNode();
        _lastSavedContent = _getExportContent();
        _isSaved = true;
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

  void _onBoardTap(TapUpDetails details, BoxConstraints constraints) {
    if (kifTree == null) return;

    _lastTapGlobalPosition = details.globalPosition;

    final double boardWidth = constraints.maxWidth;
    final double boardHeight = constraints.maxHeight;

    final double cellWidth = boardWidth / 9;
    final double cellHeight = boardHeight / 9;

    double localX = details.localPosition.dx;
    double localY = details.localPosition.dy;

    if (_isReversed) {
      localX = boardWidth - localX;
      localY = boardHeight - localY;
    }

    int file = 9 - (localX / cellWidth).floor();
    int rank = (localY / cellHeight).floor() + 1;

    if (file < 1 || file > 9 || rank < 1 || rank > 9) return;

    _handleSquareClick(file, rank);
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

  Widget _buildControlPanel() {
    return Container(
      color: const Color(0XFFF1F1F5),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: () => setState(() {
              kifTree!.jumpTo(0);
              _selectedFile = null;
              _selectedRank = null;
              _selectedHandPiece = null;
              _syncCommentFromCurrentNode();
            }),
          ),
          IconButton(
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
          GestureDetector(
            onVerticalDragUpdate: (details) {
              _dragDistance += details.delta.dy;
              const double threshold = 10.0;
              if (_dragDistance <= -threshold) {
                setState(() {
                  kifTree!.stepNext();
                  _dragDistance = 0;
                  _selectedFile = null;
                  _selectedRank = null;
                  _selectedHandPiece = null;
                  _syncCommentFromCurrentNode();
                });
              } else if (_dragDistance >= threshold) {
                setState(() {
                  kifTree!.stepBack();
                  _dragDistance = 0;
                  _selectedFile = null;
                  _selectedRank = null;
                  _selectedHandPiece = null;
                  _syncCommentFromCurrentNode();
                });
              }
            },
            onVerticalDragEnd: (_) => _dragDistance = 0,
            child: SizedBox(
              width: 90,
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

                  return GestureDetector(
                    onTap: () {
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
                                displayLabel,
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
                },
              ),
            ),
          ),
          IconButton(
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
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: () => setState(() {
              kifTree!.jumpTo(kifTree!.totalMoveCount);
              _selectedFile = null;
              _selectedRank = null;
              _selectedHandPiece = null;
              _syncCommentFromCurrentNode();
            }),
          ),
        ],
      ),
    );
  }

  void _showCommentEditDialog() async {
    final oldComment = kifTree!.currentNode.joinedComment;
    final result = await showCommentEditDialog(context, oldComment);
    if (result != null) {
      setState(() {
        kifTree!.currentNode.comments.clear();
        kifTree!.currentNode.comments.addAll(result);
        _syncCommentFromCurrentNode();
        _checkSaveStatus(); // 💡 0手目の変更もハッシュ化文字列を通じて確実に未保存判定されます
      });
    }
  }

  Widget _buildCommentField() {
    final String currentComment = kifTree!.currentNode.joinedComment;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: _showCommentEditDialog,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: SingleChildScrollView(
              child: Text(
                currentComment.isEmpty ? 'タップしてこの局面のコメントを入力' : currentComment,
                style: TextStyle(
                  fontSize: 13,
                  color: currentComment.isEmpty ? Colors.grey[400] : Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || kifTree == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final double sidebarWidth = MediaQuery.of(context).size.width * 0.85;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        Navigator.of(context).pop(widget.kifEntity);
      },
      child: Scaffold(
        backgroundColor: const Color(0XFFF1F1F5),
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop(widget.kifEntity);
            },
          ),
          backgroundColor: const Color(0XFFFFFFFF),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.kifEntity.title.isEmpty ? '棋譜編集' : widget.kifEntity.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _isSaved ? Colors.green[600] : Colors.red[600],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _isSaved ? '保存済み' : '未保存',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'ファイルを開く',
              onPressed: _openLocalFile,
            ),
            IconButton(
              icon: const Icon(Icons.content_paste),
              tooltip: 'クリップボードから貼り付け',
              onPressed: _pasteFromClipboard,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: '共有',
              onPressed: _shareKifData,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'ローカル保存',
              onPressed: _saveKifData,
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
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
                          return GestureDetector(
                            onTapUp: (details) => _onBoardTap(details, constraints),
                            child: KifBoard(
                              state: kifTree!.currentNode.state,
                              isReversed: _isReversed,
                              selectedX: _selectedFile,
                              selectedY: _selectedRank,
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
                    child: _buildCommentField(),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAndKomaDai({required String playerName, required bool isSente, required bool isUpper}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
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

  Widget _buildNameLabel(String name, bool isSente) {
    final String key = isSente ? '先手' : '後手';

    return InkWell(
      onTap: () => _showEditPlayerNameDialog(key: key, currentName: name),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${isSente ? '▲' : '△'}$name",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 2),
            Icon(Icons.edit, size: 12, color: Colors.grey[600]),
          ],
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
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
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
        final isSelected = _selectedHandPiece == entry.key &&
            ((kifTree!.currentNode.state.nextPlayer == Player.sente && isSente) ||
                (kifTree!.currentNode.state.nextPlayer == Player.gote && !isSente));

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedHandPiece = null;
              } else {
                final currentPlayer = kifTree!.currentNode.state.nextPlayer;
                if ((currentPlayer == Player.sente && isSente) ||
                    (currentPlayer == Player.gote && !isSente)) {
                  _selectedHandPiece = entry.key;
                  _selectedFile = null;
                  _selectedRank = null;
                }
              }
            });
          },
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange.withOpacity(0.4) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Image.asset(
                  'assets/images/pieces/$assetPrefix${entry.key}.png',
                  width: 31,
                  height: 31,
                  fit: BoxFit.contain,
                ),
              ),
              if (entry.value > 1)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
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
          ),
        );
      }).toList(),
    );
  }

  Future<({String fileName, List<int> bytes})?> _prepareKifData() async {
    if (kifTree == null) return null;

    final String kifContent = KifParser.encode(kifTree!);
    final List<int> bytes = await CharsetConverter.encode("Shift_JIS", kifContent);

    final String fileName = "${DateTime.now().millisecondsSinceEpoch}.kif";

    return (fileName: fileName, bytes: bytes);
  }

  Future<void> _saveKifData() async {
    final kifData = await _prepareKifData();
    if (kifData == null) return;

    setState(() => _isLoading = true);

    try {
      String targetPath = widget.kifEntity.kifPath ?? "";
      bool isNewFile = targetPath.isEmpty || !await File(targetPath).exists();

      if (isNewFile) {
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final Directory saveDir = Directory(p.join(appDocDir.path, 'Kifdamari'));
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
        targetPath = p.join(saveDir.path, kifData.fileName);
      }

      final file = File(targetPath);
      await file.writeAsBytes(kifData.bytes, flush: true);

      if (isNewFile) {
        final sente = kifTree?.info['先手'] ?? '先手';
        final gote = kifTree?.info['後手'] ?? '後手';
        final totalMoves = kifTree?.totalMoveCount ?? 0;
        final detailText = '▲$sente vs △$gote ($totalMoves手)';

        final updatedKif = KifEntity(
          id: widget.kifEntity.id,
          tabId: widget.kifEntity.tabId,
          kifId: widget.kifEntity.kifId,
          title: widget.kifEntity.title,
          detail: detailText,
          kifOrder: widget.kifEntity.kifOrder,
          kifPath: targetPath,
          color: widget.kifEntity.color,
        );
        await KifDao().updateKif(updatedKif);
      }

      setState(() {
        _lastSavedContent = _getExportContent();
        _isSaved = true;
      });

      if (mounted) {
        ShowSuccessSnackbar.show(context, '棋譜を保存しました');
      }
    } catch (e) {
      ShowErrorSnackbar.show(context, '棋譜の保存に失敗しました');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareKifData() async {
    final kifData = await _prepareKifData();
    if (kifData == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, kifData.fileName));
      await tempFile.writeAsBytes(kifData.bytes, flush: true);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: widget.kifEntity.title.isEmpty ? "${DateTime.now().millisecondsSinceEpoch}.kif" : widget.kifEntity.title,
      );
    } catch (e) {
      debugPrint("KIF共有エラー: $e");
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

    return showMenu<bool>(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx - 60,
        tapPosition.dy - 100,
        tapPosition.dx + 60,
        tapPosition.dy,
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem<bool>(
          enabled: false,
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
              const SizedBox(width: 8),
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
      ],
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
