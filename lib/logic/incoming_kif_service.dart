import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 他のアプリから ACTION_VIEW で渡された .kif ファイルの URI を受け取る。
class IncomingKifService {
  IncomingKifService._();

  static const MethodChannel _channel = MethodChannel('com.kifdamari/intent');
  static bool _listening = false;
  static void Function(String uri)? _onUri;

  /// 受信の待ち受けを開始する。
  ///
  /// アプリ未起動時に開かれた場合はネイティブに保持された初期 URI を、
  /// 起動中に開かれた場合はネイティブからの通知を受け取って [onUri] に渡す。
  static Future<void> listen(void Function(String uri) onUri) async {
    _onUri = onUri;
    if (_listening) return;
    _listening = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onViewIntent' && call.arguments is String) {
        final uri = call.arguments as String;
        if (uri.isNotEmpty) _onUri?.call(uri);
      }
    });

    try {
      final initialUri = await _channel.invokeMethod<String>('getInitialViewUri');
      if (initialUri != null && initialUri.isNotEmpty) {
        _onUri?.call(initialUri);
      }
    } on MissingPluginException {
      // Android 以外ではファイル関連付けによる受信を行わない。
    } on PlatformException catch (e) {
      debugPrint('受信した棋譜ファイルの取得エラー: ${e.message}');
    }
  }
}
