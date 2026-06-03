import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppSettings {
  final Box _box = Hive.box('settings_box');

  final Map<String, dynamic> _defaults = {
    'isDarkMode': false,
    'fontSize': 14.0,
    'thumbnailSize': 120,
    'defaultPlayerName': 'プレイヤー',
  };

  ValueListenable<Box<dynamic>> get listenable => _box.listenable();

  T get<T>(String key) {
    return _box.get(key, defaultValue: _defaults[key]) as T;
  }

  Future<void> set(String key, dynamic value) async {
    await _box.put(key, value);
  }
}
