import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kifdamari/widgets/constants.dart';

class AppSettings {
  AppSettings() {
    try {
      _box = Hive.box('settings_box');
    } catch (_) {
      _box = null;
    }
  }

  Box<dynamic>? _box;

  static final Map<String, dynamic> _fallbackValues = {};
  static final ValueNotifier<dynamic> _fallbackRevision = ValueNotifier<dynamic>(0);

  final Map<String, dynamic> _defaults = {
    'isDarkMode': false,
    'fontSize': 14.0,
    'kifLimit': defaultKifLimit,
    'thumbnailSize': 120,
    'treeScrollSpeed': 2.0,
    'dialDegreesPerMove': 12.6,
    'defaultKifColorMode': 'white',
    'defaultKifColor': colorWhite,
    'defaultPlayerName': 'プレイヤー',
    'kifTitle': '{先手} vs {後手}',
    'kifDetail': '棋戦：{棋戦}\n戦型：{戦型}\n対局日：{対局日}',
    'defaultSaveTreeUri': '',
    'homeViewMode': 'grid',
    'showAdvancedFeatures': false,
  };

  ValueListenable<dynamic> get listenable => _box?.listenable() ?? _fallbackRevision;

  T get<T>(String key) {
    final value = _box?.get(key, defaultValue: _defaults[key]) ??
        _fallbackValues[key] ??
        _defaults[key];
    return value as T;
  }

  Future<void> set(String key, dynamic value) async {
    final box = _box;
    if (box == null) {
      _fallbackValues[key] = value;
      _fallbackRevision.value++;
      return;
    }
    await box.put(key, value);
  }

  bool get showAdvancedFeatures => get<bool>('showAdvancedFeatures') ?? false;
}
