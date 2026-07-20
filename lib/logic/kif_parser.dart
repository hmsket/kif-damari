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

  static String convertToJapanese(String rawLabel) {
    if (rawLabel.isEmpty) return '開始局面';

    if (rawLabel.startsWith(RegExp(r'[１-９同]'))) {
      String clean = rawLabel.replaceAll(RegExp(r'\(.*\)'), '');
      if (clean.contains('馬成')) clean = clean.replaceAll('馬成', '角成');
      if (clean.contains('龍成')) clean = clean.replaceAll('龍成', '飛成');
      return clean;
    }

    if (rawLabel.startsWith('+')) {
      final match = RegExp(r"^\+([1-9])([1-9])([a-z]+)").firstMatch(rawLabel);
      if (match != null) {
        final file = _numToZen[int.parse(match.group(1)!)];
        final rank = _numToKan[int.parse(match.group(2)!)];
        final piece = _codeToKanji[match.group(3)!] ?? '歩';
        return "$file$rank${piece}打";
      }
    }

    final match = RegExp(r"^([1-9])([1-9])([1-9])([1-9])([a-z]+)(\+?)").firstMatch(rawLabel);
    if (match != null) {
      final toX = int.parse(match.group(3)!);
      final toY = int.parse(match.group(4)!);
      final pieceCode = match.group(5)!;
      final isPromotedAction = match.group(6)!.isNotEmpty;

      final file = _numToZen[toX];
      final rank = _numToKan[toY];
      
      final piece = _codeToKanji[pieceCode] ?? '歩';
      final action = isPromotedAction ? '成' : '';

      return "$file$rank$piece$action";
    }

    return rawLabel;
  }

  static KifTree decode(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final tree = KifTree.initial();
    GameNode currentNode = tree.root;

    final infoRegex = RegExp(r"^([^：:]+)[：:](.*)$");
    final moveRegex = RegExp(r"^\s*(\d+)\s+([１-９同])\s*([一二三四五六七八九 ]?)\s*([^\s(]+)(?:\((\d)(\d)\))?");
    final branchRegex = RegExp(r"^変化[：:\s]*(\d+)\s*手(?:目)?");

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      if (trimmedLine.startsWith('*')) {
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
        final moveNum = int.parse(moveMatch.group(1)!);
        final firstChar = moveMatch.group(2)!;
        final secondChar = moveMatch.group(3)?.trim() ?? "";
        final pieceName = moveMatch.group(4)!;
        final fromXStr = moveMatch.group(5);
        final fromYStr = moveMatch.group(6);

        int toX, toY;
        if (firstChar == '同') {
          if (currentNode.state.lastMoveToX == null || currentNode.state.lastMoveToY == null) {
            toX = 0; toY = 0;
          } else {
            toX = currentNode.state.lastMoveToX!;
            toY = currentNode.state.lastMoveToY!;
          }
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
          parent: currentNode, // 💡 修正点：親への参照を紐付けることで変化のデコードを正常化
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
    return tree;
  }

  static String encode(KifTree tree) {
    final buffer = StringBuffer();

    tree.info.forEach((key, value) {
      buffer.writeln('$key：$value');
    });
    buffer.writeln('手数----指手----消費時間--');

    _writeNodes(buffer, tree.root.nextNodes);

    return buffer.toString();
  }

  static void _writeNodes(StringBuffer buffer, List<GameNode> nodes) {
    if (nodes.isEmpty) return;

    final primaryNode = nodes.first;
    String cleanLabel = primaryNode.moveLabel ?? '';

    if (cleanLabel.startsWith(RegExp(r'[１-９同]'))) {
      if (cleanLabel.contains('馬成')) cleanLabel = cleanLabel.replaceAll('馬成', '角成');
      if (cleanLabel.contains('龍成')) cleanLabel = cleanLabel.replaceAll('龍成', '飛成');
    } else {
      if (cleanLabel.startsWith('+')) {
        final match = RegExp(r"^\+([1-9])([1-9])([a-z]+)").firstMatch(cleanLabel);
        if (match != null) {
          final file = _numToZen[int.parse(match.group(1)!)];
          final rank = _numToKan[int.parse(match.group(2)!)];
          final piece = _codeToKanji[match.group(3)!] ?? '歩';
          cleanLabel = "$file$rank${piece}打";
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

          final file = _numToZen[toX];
          final rank = _numToKan[toY];
          final piece = _codeToKanji[pieceCode] ?? '歩';
          final action = isPromotedAction ? '成' : '';

          // 正しいKIF規格「２六歩(27)」に変換
          cleanLabel = "$file$rank$piece$action($fromX$fromY)";
        }
      }
    }
    
    buffer.writeln('${primaryNode.moveNumber.toString().padLeft(4)} $cleanLabel');

    for (var comment in primaryNode.comments) {
      buffer.writeln('*$comment');
    }

    _writeNodes(buffer, primaryNode.nextNodes);

    for (int i = 1; i < nodes.length; i++) {
      final branchReplyNode = nodes[i];
      buffer.writeln('\n変化：${branchReplyNode.moveNumber}手目');
      _writeNodes(buffer, [branchReplyNode]);
    }
  }
}
