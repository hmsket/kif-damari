import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ホーム画面の棋譜カード「色変更」プルダウンと同じ見た目を
/// 再生・編集画面の⋮メニューに適用するための共通スタイル。
class AppPopupMenuStyle {
  const AppPopupMenuStyle._();

  static MenuStyle get menuStyle => MenuStyle(
        backgroundColor: WidgetStateProperty.all(Colors.white),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(8.0),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 4),
        ),
      );

  static ButtonStyle get itemStyle => MenuItemButton.styleFrom(
        foregroundColor: const Color(0xFF222222),
        disabledForegroundColor: const Color(0xFF999999),
        textStyle: TextStyle(
          fontSize: 14,
          fontFamily: GoogleFonts.notoSansJp().fontFamily,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        minimumSize: const Size(0, 48),
      );
}
