import 'package:flutter/material.dart';
import 'package:kifdamari/pages/home_page.dart';

class ModeBadge extends StatelessWidget {
  final AppMode mode;

  const ModeBadge({
    super.key,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;

    switch (mode) {
      case AppMode.delete:
        text = '削除モード';
        color = Colors.red[600]!;
        break;
      case AppMode.edit:
        text = '編集モード';
        color = Colors.green[600]!;
        break;
      case AppMode.sort:
        text = '並び替えモード';
        color = Colors.blue[600]!;
        break;
      case AppMode.normal:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
