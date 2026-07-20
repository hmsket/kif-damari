import 'package:flutter/material.dart';

Future<List<String>?> showCommentEditDialog(BuildContext context, String currentComment) {
  final TextEditingController dialogController = TextEditingController(text: currentComment);
  final FocusNode dialogFocusNode = FocusNode();

  return Navigator.of(context).push<List<String>>(
    PageRouteBuilder(
      opaque: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (dialogFocusNode.canRequestFocus) dialogFocusNode.requestFocus();
        });

        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black54),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Material(
                  color: Colors.white,
                  elevation: 24,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('コメント編集', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown)),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: dialogController,
                            focusNode: dialogFocusNode,
                            maxLines: 5,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'この局面のコメントを入力...',
                              filled: true,
                              fillColor: const Color(0XFFF5F5F7),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              onPressed: () {
                                final text = dialogController.text;
                                Navigator.pop(context, text.isEmpty ? <String>[] : text.split('\n'));
                              },
                              child: const Text('決定', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  ).then((result) {
    dialogFocusNode.dispose();
    dialogController.dispose();
    return result;
  });
}
