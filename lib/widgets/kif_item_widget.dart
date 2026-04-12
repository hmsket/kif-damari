import 'package:flutter/material.dart';

class KifItemWidget extends StatelessWidget {
  final String title;
  final String? detail;
  final Widget? trailing;

  const KifItemWidget({
    super.key,
    required this.title,
    this.detail,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像部分
            SizedBox(
              width: 120, height: 120,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset('assets/images/initial.png', fit: BoxFit.contain),
              ),
            ),
            // テキスト部分
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'タイトル未入力' : title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      (detail == null || detail!.isEmpty) ? '詳細なし' : detail!,
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
        // 右上のアイコン配置用
        if (trailing != null)
          Positioned(
            top: 6,
            right: 6,
            child: trailing!,
          ),
      ],
    );
  }
}
