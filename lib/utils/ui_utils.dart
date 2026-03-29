import 'package:flutter/material.dart';

class UiUtils {
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          height: 50,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(Icons.check, color: Color(0xFF527D66), size: 30),
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
          )
        ),
        backgroundColor: Color.fromARGB(255, 223, 225, 224),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),

        shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: Color(0xFF527D66), // 枠線の色
          width: 1.5, // 枠線の太さ
        ),
      ),
      ),
    );
  }
}
