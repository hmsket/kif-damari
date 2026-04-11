import 'package:flutter/material.dart';
import 'package:kifdamari/widgets/kif_board.dart';

class KifViewerPage extends StatelessWidget {
  final String? kifPath;

  const KifViewerPage({super.key, required this.kifPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildPlayerAndKomaDai(playerName: "渡辺 明", isSente: false),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: AspectRatio(
                aspectRatio: 0.93, // 盤の縦横比
                child: const KifBoard(),
              ),
            ),
            _buildPlayerAndKomaDai(playerName: "藤井 聡太", isSente: true),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.brown[200]!),
                ),
                child: const SingleChildScrollView(
                  child: Text(
                    "【棋譜コメント】\nここに指し手の解説や、分岐などの情報を表示します。\n124手で藤井聡太竜王の勝ち。",
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ),
            ),
            _buildControlPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerAndKomaDai({required String playerName, required bool isSente}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      color: Colors.brown[50], 
      child: Row(
        children: [
          if (!isSente) ...[
            _buildNameLabel(playerName, isSente),
            const SizedBox(width: 12),
          ],          
          Expanded(child: _buildPieceStand(isSente)),
          if (isSente) ...[
            const SizedBox(width: 12),
            _buildNameLabel(playerName, isSente),
          ],
        ],
      ),
    );
  }

  Widget _buildNameLabel(String name, bool isSente) {
    return Text(
      "${isSente ? '▲' : '△'}$name",
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildPieceStand(bool isSente) {
    return Row(
      mainAxisAlignment: isSente ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        // 本当はコマの画像を並べる
        Text("持駒なし", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}

Widget _buildControlPanel() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    color: Colors.brown[50], // 下部エリアを少し色分け
    child: 
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: () {
              // 初期盤面に戻る
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            iconSize: 36, // メインのボタンは少し大きく
            onPressed: () {
              // 一手戻る
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            iconSize: 36,
            onPressed: () {
              // 一手進む
            },
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: () {
              // 最終局面まで進む
            },
          ),
          // 盤面反転ボタン
          IconButton(
            icon: const Icon(Icons.cached),
            onPressed: () {
              // 盤面を180度回転させる
            },
          ),
        ],
      ),
  );
}
