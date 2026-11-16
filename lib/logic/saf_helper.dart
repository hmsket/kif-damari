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

  /// Android ネイティブのフォルダ選択ピッカー（SAF ツリーピッカー）を起動し、
  /// 選択されたツリーの content:// URI を返す。選択は永続化される。
  static Future<String?> pickTree() async {
    try {
      final String? uri = await _channel.invokeMethod('pickTree');
      return uri;
    } on PlatformException catch (e) {
      print("フォルダ選択エラー: ${e.message}");
      return null;
    }
  }

  /// 選択済みツリー（フォルダ）内に新規ファイルを作成し、バイトデータを書き込む。
  /// 成功した場合は作成されたファイルの content:// URI を、失敗した場合（オフライン等）は null を返す。
  static Future<String?> createFileInTree(String treeUriString, String fileName, Uint8List bytes) async {
    try {
      final String? uri = await _channel.invokeMethod('createFileInTree', {
        'treeUri': treeUriString,
        'fileName': fileName,
        'bytes': bytes,
      });
      return uri;
    } on PlatformException catch (e) {
      print("ファイル作成エラー: ${e.message}");
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
