import 'package:flutter/material.dart';

class ShowSuccessSnackbar {
  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SuccessSnackBar(context: context, message: message),
    );
  }
}

class SuccessSnackBar extends SnackBar {
  final BuildContext context;
  final String message;

  SuccessSnackBar({
    super.key,
    required this.context,
    required this.message,
  }) : super(
          content: Container(
            height: 50,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(
                  Icons.check,
                  color: Theme.of(context).colorScheme.primary,
                  size: 30,
                ),
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
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
          ),
        );
}