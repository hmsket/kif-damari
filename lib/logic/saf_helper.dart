import 'package:flutter/services.dart';

class SafHelper {
  static const MethodChannel _channel = MethodChannel('com.kifdamari/saf');

  /// Android ネイティブのファイル選択ピッカーを起動し、選択されたファイルの content:// URI を返す
  static Future<String?> pickFile() async {
    try {
      final String? uri = await _channel.invokeMethod('pickFile');
      return uri;
    } on PlatformException catch (e) {
      print("ファイル選択エラー: ${e.message}");
      return null;
    }
  }

  /// content:// URI からバイトデータを読み込む
  static Future<Uint8List?> readFileBytes(String uriString) async {
    try {
      final Uint8List? bytes = await _channel.invokeMethod('readFile', {
        'uri': uriString,
      });
      return bytes;
    } on PlatformException catch (e) {
      print("ファイル読み込みエラー: ${e.message}");
      return null;
    }
  }

  /// content:// URI の元ファイル（Google Drive等）へ直接上書き保存する
  static Future<bool> writeFileBytes(String uriString, Uint8List bytes) async {
    try {
      final bool? success = await _channel.invokeMethod('writeFile', {
        'uri': uriString,
        'bytes': bytes,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      print("ファイル書き込みエラー: ${e.message}");
      return false;
    }
  }
}
