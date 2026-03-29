import 'package:flutter/material.dart';
import '../database/entity/kif_entity.dart';
import '../main.dart';

class KifListItem extends StatelessWidget {
  final KifEntity kif;
  final AppMode mode;
  final VoidCallback onRefresh;

  const KifListItem({
    super.key,
    required this.kif,
    required this.mode,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Colors.grey, width: 1),
      ),
      margin: const EdgeInsets.all(1),
      child: InkWell(
        onTap: () {
          if (mode == AppMode.delete) {
            // TODO: 削除モードならダイアログを表示
          } else {
            // TODO: 将棋盤画面へ
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Image.asset(
                  'assets/images/initial.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kif.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      kif.detail ?? '詳細なし',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
