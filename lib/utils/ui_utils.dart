import 'package:flutter/material.dart';

class UiUtils {
  static void showSuccessSnackBar(BuildContext context, String message) {
    // 現在のテーマからColorSchemeを取得
    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          height: 50,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(Icons.check, color: colorScheme.primary, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: colorScheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            // 枠線の色をPrimaryにする
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
