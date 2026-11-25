import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:kifdamari/logic/saf_helper.dart';

/// 棋譜ファイルの読み込みを、content:// / file:// / ローカルパスの
/// いずれでも行えるようにするヘルパー。
class KifFileReader {
  KifFileReader._();

  static Future<Uint8List?> readBytes(String location) async {
    if (location.startsWith('content://')) {
      return SafHelper.readFileBytes(location);
    }

    try {
      final file = File(toLocalPath(location));
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// ファイルをUTF-8として読み込み、失敗した場合はShift_JISとして読む。
  static Future<String?> readText(String location) async {
    final bytes = await readBytes(location);
    if (bytes == null) return null;

    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return CharsetConverter.decode('Shift_JIS', bytes);
    }
  }

  /// file:// URI をローカルファイルパスに変換する。それ以外はそのまま返す。
  static String toLocalPath(String location) {
    if (location.startsWith('file://')) {
      return Uri.parse(location).toFilePath();
    }
    return location;
  }
}
