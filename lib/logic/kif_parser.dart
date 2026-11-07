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
    final tree = KifTree.initial();
    GameNode currentNode = tree.root;

    // 💡 修正箇所：先頭が「キー：値」になっている任意のヘッダー行にマッチさせる
    // ただし指し手行（数字で始まる行）やコメント行等と誤検知しないよう除外指定
    final infoRegex = RegExp(r"^([^0-9\s\*\'\=\-\#\&\/].*?)[：:](.*)$");
    final moveRegex = RegExp(r"^\s*(\d+)\s+([１-９同])\s*([一二三四五六七八九 ]?)\s*([^\s(]+)(?:\((\d)(\d)\))?");
    final branchRegex = RegExp(r"^変化[：:\s]*(\d+)\s*手(?:目)?");

    int parsedMoveCount = 0;

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

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
        }
      }
    }

    // 💡【判定強化】
    // 1. 指し手が1手もない場合（ヘッダーだけのテキストやただの文章）はエラーとする
    // （※開始局面のみで指し手のないKIFファイルを許容したい場合は「parsedMoveCount == 0 && parsedInfoCount == 0」にしてください）
    if (parsedMoveCount == 0) {
      throw const FormatException('有効な指し手データが含まれていません。');
    }

    return tree;
  }

  static String encode(KifTree tree) {
    final buffer = StringBuffer();

    tree.info.forEach((key, value) {
      buffer.writeln('$key：$value');
    });
    buffer.writeln('手数----指手----消費時間--');

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
}
