import 'package:kifdamari/logic/handicap_presets.dart';
import 'package:kifdamari/logic/sfen_generator.dart';
import 'package:kifdamari/models/board_state.dart';
import 'package:kifdamari/models/game_node.dart';
import 'package:kifdamari/models/kif_tree.dart';

class KifParser {
  static const _zenToNum = {'１': 1, '２': 2, '３': 3, '４': 4, '５': 5, '６': 6, '７': 7, '８': 8, '９': 9};
  static const _kanToNum = {'一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9};

  static const _numToZen = ['', '１', '２', '３', '４', '５', '６', '７', '８', '９'];
  static const _numToKan = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

  static const _codeToKanji = {
    'fu': '歩', 'ya': '香', 'ke': '桂', 'gi': '銀',
    'ki': '金', 'ka': '角', 'hi': '飛', 'gy': '玉',
    'to': 'と', 'ny': '成香', 'nk': '成桂', 'ng': '成銀',
    'um': '馬', 'ry': '龍'
  };

  /// 盤面図（柿木形式）で使う駒の1文字表記
  static const _diagramPieceChars = {
    'fu': '歩', 'ya': '香', 'ke': '桂', 'gi': '銀',
    'ki': '金', 'ka': '角', 'hi': '飛', 'gy': '玉',
    'to': 'と', 'ny': '杏', 'nk': '圭', 'ng': '全',
    'um': '馬', 'ry': '龍',
  };

  /// 盤面図の駒文字 → 駒コード（王も玉として受け入れる）
  static const _diagramCharToCode = {
    '歩': 'fu', '香': 'ya', '桂': 'ke', '銀': 'gi',
    '金': 'ki', '角': 'ka', '飛': 'hi', '玉': 'gy', '王': 'gy',
    'と': 'to', '杏': 'ny', '圭': 'nk', '全': 'ng',
    '馬': 'um', '龍': 'ry', '竜': 'ry',
  };

  /// 持駒行の略字（成駒）を元の駒コードに戻す
  static const _promotedToBase = {
    'to': 'fu', 'ny': 'ya', 'nk': 'ke', 'ng': 'gi',
    'um': 'ka', 'ry': 'hi',
  };

  static const _diagramColumnHeader = '  ９ ８ ７ ６ ５ ４ ３ ２ １';
  static const _diagramRule = '+---------------------------+';
  static const _diagramRowKanji = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];

  /// KIFラベルを日本語に変換する
  static String convertToJapanese(
    String rawLabel, {
    int? lastToX,
    int? lastToY,
  }) {
    if (rawLabel.isEmpty) return '開始局面';

    // すでに日本語形式の場合（「同」「６四角」など）
    if (rawLabel.startsWith(RegExp(r'[１-９同]'))) {
      String clean = rawLabel.replaceAll(RegExp(r'\(.*\)'), '');
      if (clean.contains('馬成')) clean = clean.replaceAll('馬成', '角成');
      if (clean.contains('龍成')) clean = clean.replaceAll('龍成', '飛成');
      return clean;
    }

    // 駒打ちの場合（例: "+24fu"）
    if (rawLabel.startsWith('+')) {
      final match = RegExp(r"^\+([1-9])([1-9])([a-z]+)").firstMatch(rawLabel);
      if (match != null) {
        final toX = int.parse(match.group(1)!);
        final toY = int.parse(match.group(2)!);
        final piece = _codeToKanji[match.group(3)!] ?? '歩';

        final isSameSquare = (lastToX != null && lastToY != null) && (lastToX == toX && lastToY == toY);
        final squareLabel = isSameSquare ? '同' : "${_numToZen[toX]}${_numToKan[toY]}";

        return "$squareLabel${piece}打";
      }
    }

    // 通常の移動の場合（例: "7776fu", "2468um+"）
    final match = RegExp(r"^([1-9])([1-9])([1-9])([1-9])([a-z]+)(\+?)").firstMatch(rawLabel);
    if (match != null) {
      final toX = int.parse(match.group(3)!);
      final toY = int.parse(match.group(4)!);
      final pieceCode = match.group(5)!;
      final isPromotedAction = match.group(6)!.isNotEmpty;

      final isSameSquare = (lastToX != null && lastToY != null) && (lastToX == toX && lastToY == toY);
      final squareLabel = isSameSquare ? '同' : "${_numToZen[toX]}${_numToKan[toY]}";

      final piece = _codeToKanji[pieceCode] ?? '歩';
      final action = isPromotedAction ? '成' : '';

      return "$squareLabel$piece$action";
    }

    return rawLabel;
  }

  static KifTree decode(String text) {
    final lines = text.split(RegExp(r'\r?\n'));

    // 💡 修正箇所：先頭が「キー：値」になっている任意のヘッダー行にマッチさせる
    // ただし指し手行（数字で始まる行）やコメント行等と誤検知しないよう除外指定
    final infoRegex = RegExp(r"^([^0-9\s\*\'\=\-\#\&\/].*?)[：:](.*)$");
    final moveRegex = RegExp(r"^\s*(\d+)\s+([１-９同])\s*([一二三四五六七八九 ]?)\s*([^\s(]+)(?:\((\d)(\d)\))?");
    final branchRegex = RegExp(r"^変化[：:\s]*(\d+)\s*手(?:目)?");

    // 「手合割」ヘッダーが駒落ちプリセットと一致する場合は、その開始局面を root にする
    // （ヘッダー無し・平手・プリセット外は従来通り平手の初期局面から開始）
    final tree = KifTree(_buildRootNode(lines, infoRegex, moveRegex));
    GameNode currentNode = tree.root;

    int parsedMoveCount = 0;
    int parsedInfoCount = 0;

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // 盤面図の行（持駒行・手番行を含む）は info ヘッダーとして取り込まない
      if (_isBoardDiagramLine(trimmedLine)) continue;

      // コメント行の解析（' や * で始まる行）
      if (trimmedLine.startsWith('*') || trimmedLine.startsWith("'")) {
        currentNode.addComment(trimmedLine.substring(1));
        continue;
      }

      final branchMatch = branchRegex.firstMatch(trimmedLine);
      if (branchMatch != null) {
        final branchMoveNum = int.parse(branchMatch.group(1)!);
        final targetParentMoveNum = branchMoveNum - 1;

        GameNode? targetParent = currentNode;
        bool found = false;

        while (targetParent != null) {
          if (targetParent.moveNumber == targetParentMoveNum) {
            currentNode = targetParent;
            found = true;
            break;
          }
          targetParent = targetParent.parent;
        }

        if (!found) {
          GameNode backup = tree.root;
          for (int i = 0; i < targetParentMoveNum; i++) {
            if (backup.nextNodes.isNotEmpty) {
              backup = backup.nextNodes.first;
            }
          }
          currentNode = backup; 
        }
        continue;
      }

      final moveMatch = moveRegex.firstMatch(trimmedLine);
      if (moveMatch != null) {
        parsedMoveCount++;
        final moveNum = int.parse(moveMatch.group(1)!);
        final firstChar = moveMatch.group(2)!;
        final secondChar = moveMatch.group(3)?.trim() ?? "";
        final pieceName = moveMatch.group(4)!;
        final fromXStr = moveMatch.group(5);
        final fromYStr = moveMatch.group(6);

        int toX, toY;
        if (firstChar == '同') {
          if (currentNode.state.lastMoveToX == null || currentNode.state.lastMoveToY == null) {
            throw FormatException('「同」の指し手の直前に移動先が不明な行があります: $trimmedLine');
          }
          toX = currentNode.state.lastMoveToX!;
          toY = currentNode.state.lastMoveToY!;
        } else {
          toX = _zenToNum[firstChar]!;
          toY = _kanToNum[secondChar]!;
        }

        int? fromX = fromXStr != null ? int.parse(fromXStr) : null;
        int? fromY = fromYStr != null ? int.parse(fromYStr) : null;

        final nextState = currentNode.state.movePiece(
          fromX: fromX, fromY: fromY,
          toX: toX, toY: toY,
          pieceName: pieceName,
        );

        final cleanMoveLabel = trimmedLine
            .split(RegExp(r'\s+'))
            .skip(1)
            .join(' ')
            .replaceAll('+', '');

        final newNode = GameNode(
          moveNumber: moveNum,
          moveLabel: cleanMoveLabel,
          state: nextState,
          parent: currentNode,
        );

        currentNode.addChild(newNode);
        currentNode = newNode;
        continue;
      }

      final infoMatch = infoRegex.firstMatch(trimmedLine);
      if (infoMatch != null) {
        final key = infoMatch.group(1)!.trim();
        final value = infoMatch.group(2)!.trim();
        if (!key.startsWith('手数')) {
          tree.info[key] = value;
          parsedInfoCount++;
        }
      }
    }

    // 指し手もヘッダー情報もない場合（ただの文章の貼り付け等）はエラーとする
    // ヘッダー情報だけの0手KIF（氏名を編集した新規棋譜など）は読み込みを許容する
    if (parsedMoveCount == 0 && parsedInfoCount == 0) {
      throw const FormatException('有効な指し手データが含まれていません。');
    }

    return tree;
  }

  /// 指し手を解釈する前にヘッダーを読み、開始局面（root ノード）を決める。
  /// 優先順位: 盤面図 > 「手合割」ヘッダーのプリセット > 平手の初期局面。
  /// （盤面図の解析に失敗した場合は手合割/平手にフォールバックする）
  static GameNode _buildRootNode(List<String> lines, RegExp infoRegex, RegExp moveRegex) {
    // 盤面図があればそれを root 局面として採用する（手合割より優先）
    final diagramState = _parseBoardDiagram(lines, moveRegex);
    if (diagramState != null) {
      return GameNode(moveNumber: 0, state: diagramState, moveLabel: '開始局面');
    }

    // 「手合割」ヘッダーが駒落ちプリセットと一致する場合は、その開始局面を root にする
    // （ヘッダー無し・平手・プリセット外は従来通り平手の初期局面から開始）
    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty ||
          trimmedLine.startsWith('*') ||
          trimmedLine.startsWith("'")) {
        continue;
      }
      if (moveRegex.firstMatch(trimmedLine) != null) {
        // 指し手が始まったらヘッダーは終わり
        break;
      }
      final infoMatch = infoRegex.firstMatch(trimmedLine);
      if (infoMatch != null && infoMatch.group(1)!.trim() == '手合割') {
        final state = HandicapPresets.stateFor(infoMatch.group(2)!.trim());
        if (state != null) {
          return GameNode(moveNumber: 0, state: state, moveLabel: '開始局面');
        }
        // プリセット外（歩三兵・裸玉など）は従来通り平手として読む
        break;
      }
    }
    return GameNode(
      moveNumber: 0,
      state: BoardState.initial(),
      moveLabel: '開始局面',
    );
  }

  static String encode(KifTree tree) {
    final buffer = StringBuffer();

    tree.info.forEach((key, value) {
      buffer.writeln('$key：$value');
    });
    // root が平手の初期局面でない場合は、開始局面の盤面図を区切り行の前に書く
    if (!_isHirateRoot(tree.root.state)) {
      _writeBoardDiagram(buffer, tree.root.state);
    }
    buffer.writeln('手数----指手---------消費時間--');

    for (var comment in tree.root.comments) {
      buffer.writeln('*$comment');
    }

    _writeNodes(buffer, tree.root.nextNodes, null, null);

    return buffer.toString();
  }

  static void _writeNodes(StringBuffer buffer, List<GameNode> nodes, int? lastToX, int? lastToY) {
    if (nodes.isEmpty) return;

    final primaryNode = nodes.first;
    String cleanLabel = primaryNode.moveLabel ?? '';

    int? currentToX = primaryNode.state.lastMoveToX;
    int? currentToY = primaryNode.state.lastMoveToY;

    if (cleanLabel.startsWith(RegExp(r'[１-９同]'))) {
      if (cleanLabel.contains('馬成')) cleanLabel = cleanLabel.replaceAll('馬成', '角成');
      if (cleanLabel.contains('龍成')) cleanLabel = cleanLabel.replaceAll('龍成', '飛成');
    } else {
      if (cleanLabel.startsWith('+')) {
        final match = RegExp(r"^\+([1-9])([1-9])([a-z]+)").firstMatch(cleanLabel);
        if (match != null) {
          final toX = int.parse(match.group(1)!);
          final toY = int.parse(match.group(2)!);
          final piece = _codeToKanji[match.group(3)!] ?? '歩';

          final isSameSquare = (lastToX != null && lastToY != null) && (lastToX == toX && lastToY == toY);
          final squareLabel = isSameSquare ? '同' : "${_numToZen[toX]}${_numToKan[toY]}";

          cleanLabel = "$squareLabel${piece}打";
          currentToX = toX;
          currentToY = toY;
        }
      } else {
        final match = RegExp(r"^([1-9])([1-9])([1-9])([1-9])([a-z]+)(\+?)").firstMatch(cleanLabel);
        if (match != null) {
          final fromX = match.group(1)!;
          final fromY = match.group(2)!;
          final toX = int.parse(match.group(3)!);
          final toY = int.parse(match.group(4)!);
          final pieceCode = match.group(5)!;
          final isPromotedAction = match.group(6)!.isNotEmpty;

          final isSameSquare = (lastToX != null && lastToY != null) && (lastToX == toX && lastToY == toY);
          final squareLabel = isSameSquare ? '同' : "${_numToZen[toX]}${_numToKan[toY]}";

          final piece = _codeToKanji[pieceCode] ?? '歩';
          final action = isPromotedAction ? '成' : '';

          cleanLabel = "$squareLabel$piece$action($fromX$fromY)";
          currentToX = toX;
          currentToY = toY;
        }
      }
    }
    
    buffer.writeln('${primaryNode.moveNumber.toString().padLeft(4)} $cleanLabel');

    for (var comment in primaryNode.comments) {
      buffer.writeln('*$comment');
    }

    _writeNodes(buffer, primaryNode.nextNodes, currentToX, currentToY);

    for (int i = 1; i < nodes.length; i++) {
      final branchReplyNode = nodes[i];
      buffer.writeln('\n変化：${branchReplyNode.moveNumber}手目');
      _writeNodes(buffer, [branchReplyNode], lastToX, lastToY);
    }
  }

  /// root 局面が平手の初期局面（盤面・持駒・手番がすべて一致）かどうか
  static bool _isHirateRoot(BoardState state) {
    return SfenGenerator.generateKey(state) ==
        SfenGenerator.generateKey(BoardState.initial());
  }

  /// 開始局面の盤面図（柿木形式）を書き出す
  static void _writeBoardDiagram(StringBuffer buffer, BoardState state) {
    buffer.writeln(_diagramColumnHeader);
    buffer.writeln(_diagramRule);
    for (int y = 0; y < 9; y++) {
      final cells = StringBuffer();
      for (int x = 0; x < 9; x++) {
        final piece = state.grid[y][x];
        if (piece == null) {
          cells.write(' ・');
        } else {
          final name = _diagramPieceChars[piece.substring(1)] ?? '・';
          cells.write(piece.startsWith('b') ? ' $name' : 'v$name');
        }
      }
      buffer.writeln('|$cells|${_diagramRowKanji[y]}');
    }
    buffer.writeln(_diagramRule);
    buffer.writeln('先手の持駒：${_handDiagram(state.senteHand)}');
    buffer.writeln('後手の持駒：${_handDiagram(state.goteHand)}');
    buffer.writeln(state.nextPlayer == Player.sente ? '先手番' : '後手番');
  }

  /// 持駒を盤面図の持駒行の値（例: 「なし」「歩二　金」）にする。
  /// 並び順は 飛角金銀桂香歩。
  static String _handDiagram(Map<String, int> hand) {
    const order = ['hi', 'ka', 'ki', 'gi', 'ke', 'ya', 'fu'];
    final parts = <String>[];
    for (final type in order) {
      final count = hand[type] ?? 0;
      if (count <= 0) continue;
      final name = _diagramPieceChars[type]!;
      parts.add(count == 1 ? name : '$name${_handCountToKan(count)}');
    }
    return parts.isEmpty ? 'なし' : parts.join('　');
  }

  /// 持駒の枚数を漢数字にする（「二」「十」「十一」など）
  static String _handCountToKan(int count) {
    if (count <= 9) return _numToKan[count];
    if (count < 20) return count == 10 ? '十' : '十${_numToKan[count - 10]}';
    return '$count';
  }

  /// 盤面図の各行かどうか（info ヘッダーとして扱わない・指し手としても扱わない）
  static bool _isBoardDiagramLine(String line) {
    final t = line.trim();
    if (t.isEmpty) return false;
    if (t == _diagramRule) return true;
    if (_isDiagramColumnHeader(t)) return true;
    if (t.startsWith('|')) return true;
    if (t.startsWith('先手の持駒：') || t.startsWith('後手の持駒：')) return true;
    if (t == '先手番' || t == '後手番') return true;
    return false;
  }

  static bool _isDiagramColumnHeader(String t) {
    final compact = t.replaceAll(RegExp(r'[\s　]'), '');
    return compact == '９８７６５４３２１' || compact == '987654321';
  }

  /// 盤面図ブロックを解析して開始局面を復元する。無い・解析不能な場合は null。
  static BoardState? _parseBoardDiagram(List<String> lines, RegExp moveRegex) {
    for (int i = 0; i < lines.length; i++) {
      final t = lines[i].trim();
      if (t.startsWith('*') || t.startsWith("'")) continue;
      if (_isDiagramColumnHeader(t)) {
        final state = _parseDiagramBlock(lines, i);
        if (state != null) return state;
        continue;
      }
      if (_isBoardDiagramLine(t)) continue;
      // 指し手が始まったらヘッダー領域は終わり
      if (moveRegex.firstMatch(t) != null || t.startsWith('手数----')) break;
    }
    return null;
  }

  /// 列番号行の直後から盤面図ブロック（枠・段行・持駒行・手番行）を解析する
  static BoardState? _parseDiagramBlock(List<String> lines, int start) {
    int i = start + 1;
    if (i >= lines.length || lines[i].trim() != _diagramRule) return null;
    i++;

    final grid = List.generate(9, (_) => List<String?>.filled(9, null));
    for (int r = 0; r < 9; r++) {
      if (i >= lines.length) return null;
      final row = _parseDiagramRow(lines[i].trim(), r);
      if (row == null) return null;
      grid[r] = row;
      i++;
    }
    if (i >= lines.length || lines[i].trim() != _diagramRule) return null;
    i++;

    final hands = <String, Map<String, int>>{'先手': {}, '後手': {}};
    final seenHands = <String>{};
    for (int h = 0; h < 2; h++) {
      if (i >= lines.length) return null;
      final t = lines[i].trim();
      String? player;
      String? value;
      if (t.startsWith('先手の持駒：')) {
        player = '先手';
        value = t.substring('先手の持駒：'.length);
      } else if (t.startsWith('後手の持駒：')) {
        player = '後手';
        value = t.substring('後手の持駒：'.length);
      } else {
        return null;
      }
      if (seenHands.contains(player)) return null;
      final hand = _parseDiagramHand(value!);
      if (hand == null) return null;
      hands[player] = hand;
      seenHands.add(player);
      i++;
    }

    if (i >= lines.length) return null;
    final turnLine = lines[i].trim();
    if (turnLine != '先手番' && turnLine != '後手番') return null;

    return BoardState(
      grid: grid,
      senteHand: hands['先手']!,
      goteHand: hands['後手']!,
      nextPlayer: turnLine == '先手番' ? Player.sente : Player.gote,
    );
  }

  /// 段行（例: | ・v桂...|一）を解析して grid の1行を返す
  static List<String?>? _parseDiagramRow(String t, int rowIndex) {
    if (!t.startsWith('|') || t.length < 20) return null;
    if (t.codeUnitAt(19) != 0x7C) return null; // 19文字目（2個目の '|'）

    final row = <String?>[];
    for (int c = 0; c < 9; c++) {
      final cell = t.substring(1 + c * 2, 3 + c * 2);
      final first = cell[0];
      final second = cell[1];
      if (first == ' ') {
        if (second == '・') {
          row.add(null);
          continue;
        }
        final code = _diagramCharToCode[second];
        if (code == null) return null;
        row.add('b$code');
      } else if (first == 'v' || first == 'V') {
        final code = _diagramCharToCode[second];
        if (code == null) return null;
        row.add('w$code');
      } else {
        return null;
      }
    }

    // 行末の段（一..九）が行位置と一致することを確認（無い場合は許容）
    final suffix = t.substring(20).trim();
    if (suffix.isNotEmpty && _kanToNum[suffix] != rowIndex + 1) return null;

    return row;
  }

  /// 持駒行の値（例: 「なし」「歩二　金」）を解析する。不正な場合は null。
  static Map<String, int>? _parseDiagramHand(String value) {
    final hand = <String, int>{};
    final v = value.trim();
    if (v.isEmpty || v == 'なし') return hand;

    for (final token in v.split(RegExp(r'[\s　]+'))) {
      if (token.isEmpty) continue;
      final rawCode = _diagramCharToCode[token[0]];
      if (rawCode == null) return null;
      // 持駒は成駒にならないため、略字は元の駒に戻す
      final code = _promotedToBase[rawCode] ?? rawCode;

      int count = 1;
      if (token.length > 1) {
        count = 0;
        for (final ch in token.substring(1).split('')) {
          final d = _kanToNum[ch];
          if (d == null) return null;
          count = count * 10 + d;
        }
      }
      hand[code] = (hand[code] ?? 0) + count;
    }
    return hand;
  }
}
