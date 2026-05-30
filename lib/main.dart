import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kifdamari/pages/home_page.dart';

void main() async {
  // 画面固定の非同期処理を動かすために、Flutterのバインディングを初期化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 画面の向きを「縦（通常）」と「縦（上下逆）」のみに固定
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const KifdamariApp());
}

class KifdamariApp extends StatelessWidget {
  const KifdamariApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomePage(),
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansJpTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
      ),
    );
  }
}
