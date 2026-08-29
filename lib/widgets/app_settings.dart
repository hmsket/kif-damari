import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kifdamari/widgets/constants.dart';

class AppSettings {
  final Box _box = Hive.box('settings_box');

  final Map<String, dynamic> _defaults = {
    'isDarkMode': false,
    'fontSize': 14.0,
    'kifLimit': defaultKifLimit,
    'thumbnailSize': 120,
    'defaultPlayerName': 'プレイヤー',
    'kifTitle': '{先手} vs {後手}',
    'kifDetail': '{棋戦} / {戦型} / {対局日}',
  };

  ValueListenable<Box<dynamic>> get listenable => _box.listenable();

  T get<T>(String key) {
    return _box.get(key, defaultValue: _defaults[key]) as T;
  }

  Future<void> set(String key, dynamic value) async {
    await _box.put(key, value);
  }
}
