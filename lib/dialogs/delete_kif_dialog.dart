import 'package:flutter/material.dart';
import 'package:kifdamari/snackbars/show_success_snackbar.dart';

void showDeleteSelectedKifsDialog(BuildContext context, int count, Future<void> Function() onDeleteConfirmed) {
  showDialog(
    context: context,
    builder: (context) => DeleteSelectedKifsDialogContent(
      count: count,
      onDeleteConfirmed: onDeleteConfirmed,
    ),
  );
}

class DeleteSelectedKifsDialogContent extends StatelessWidget {
  final int count;
  final Future<void> Function() onDeleteConfirmed;

  const DeleteSelectedKifsDialogContent({
    super.key,
    required this.count,
    required this.onDeleteConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
      ),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // タイトル
            const Text(
              '棋譜を削除します',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 赤いゴミ箱アイコン
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFF2D46), // 明るい赤
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.delete,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 説明文
            Text(
              '選択した棋譜：$count 件',
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 右寄せ横並びのボタンエリア
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // キャンセル（やめる）ボタン (枠線あり)
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Color(0xFFCCCCCC), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'キャンセル',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 削除ボタン (黒塗りつぶし)
                ElevatedButton(
                  onPressed: () async {
                    await onDeleteConfirmed();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ShowSuccessSnackbar.show(
                          context, "$count件の棋譜を削除しました");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF222222), // シックな黒色
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    '削除',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
