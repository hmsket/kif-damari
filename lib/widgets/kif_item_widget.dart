import 'dart:io';
import 'package:flutter/material.dart';

class KifItemWidget extends StatelessWidget {
  final String title;
  final String? detail;
  final String? imgPath;
  final Widget? trailing;

  const KifItemWidget({
    super.key,
    required this.title,
    this.detail,
    this.imgPath,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120, height: 120,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildImage(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? '' : title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      (detail == null || detail!.isEmpty) ? '' : detail!,
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

  /// 画像表示ロジック
  Widget _buildImage() {
    // 1. imgPath があり、かつファイルが存在する場合
    if (imgPath != null && imgPath!.isNotEmpty) {
      final file = File(imgPath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4), // 少し角を丸くすると馴染みます
          child: Image.file(file, fit: BoxFit.contain),
        );
      }
    }

    // 2. それ以外は初期画像を表示
    return Image.asset('assets/images/initial.png', fit: BoxFit.contain);
  }
}
