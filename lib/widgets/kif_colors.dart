import 'dart:math';

import 'package:flutter/material.dart';

import 'package:kifdamari/widgets/app_settings.dart';
import 'package:kifdamari/widgets/constants.dart';

class KifColors {
  KifColors._();

  static const List<Map<String, dynamic>> palette = [
    {'value': 0xFFFFFFFF, 'label': 'white', 'textColor': Colors.black87},
    {'value': 0xFFF7D6D3, 'label': 'red', 'textColor': Colors.black87},
    {'value': 0xFFFFE6C7, 'label': 'orange', 'textColor': Colors.black87},
    {'value': 0xFFFFF6CC, 'label': 'yellow', 'textColor': Colors.black87},
    {'value': 0xFFE6F5D6, 'label': 'green', 'textColor': Colors.black87},
    {'value': 0xFFDFF5EE, 'label': 'teal', 'textColor': Colors.black87},
    {'value': 0xFFE3F1F8, 'label': 'blue', 'textColor': Colors.black87},
    {'value': 0xFFE0E9FB, 'label': 'dark_blue', 'textColor': Colors.black87},
    {'value': 0xFFE9DDF8, 'label': 'violet', 'textColor': Colors.black87},
    {'value': 0xFFF9DDEA, 'label': 'pink', 'textColor': Colors.black87},
    {'value': 0xFFEEE4D6, 'label': 'brown', 'textColor': Colors.black87},
    {'value': 0xFFEFF1F4, 'label': 'gray', 'textColor': Colors.black87},
  ];

  static const String modeWhite = 'white';
  static const String modeFixed = 'fixed';
  static const String modeRandom = 'random';

  static String modeLabel(String mode) {
    switch (mode) {
      case modeFixed:
        return '指定した色';
      case modeRandom:
        return 'ランダム';
      case modeWhite:
      default:
        return '白';
    }
  }

  static String colorLabel(int color) {
    for (final data in palette) {
      if (data['value'] == color) {
        return data['label'] as String;
      }
    }
    return '${color.toRadixString(16)}';
  }

  /// 新規棋譜作成時のデフォルト色を設定から解決する。
  /// ランダムモードの場合は呼び出し時点で 1 回だけ決まる。
  static int resolveDefaultColor(AppSettings settings, [Random? random]) {
    final mode = settings.get<String>('defaultKifColorMode');
    switch (mode) {
      case modeFixed:
        final color = settings.get<int>('defaultKifColor');
        return color ?? colorWhite;
      case modeRandom:
        final values = palette.map((data) => data['value'] as int).toList();
        final rand = random ?? Random();
        return values[rand.nextInt(values.length)];
      case modeWhite:
      default:
        return colorWhite;
    }
  }
}
