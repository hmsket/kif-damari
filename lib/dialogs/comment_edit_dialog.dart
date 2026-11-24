import 'package:flutter/material.dart';

Future<List<String>?> showCommentEditDialog(BuildContext context, String currentComment) {
  return Navigator.of(context).push<List<String>>(
    PageRouteBuilder(
      opaque: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _CommentEditSheet(currentComment: currentComment);
      },
    ),
  );
}

class _CommentEditSheet extends StatefulWidget {
  final String currentComment;

  const _CommentEditSheet({super.key, required this.currentComment});

  @override
  State<_CommentEditSheet> createState() => _CommentEditSheetState();
}

class _CommentEditSheetState extends State<_CommentEditSheet> {
  static const double _dismissThreshold = 50;
  static const Duration _settleDuration = Duration(milliseconds: 200);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _textFieldKey = GlobalKey();

  int? _dragPointerId;
  double? _dragStartY;
  double _dragOffset = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.currentComment;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _focusNode.canRequestFocus) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_dragPointerId != null) return;
    // テキスト入力中の指の動き（範囲選択・スクロール）ではシートを動かさない
    final RenderObject? textField = _textFieldKey.currentContext?.findRenderObject();
    if (textField is RenderBox &&
        textField.size.contains(textField.globalToLocal(event.position))) {
      return;
    }
    _dragPointerId = event.pointer;
    _dragStartY = event.position.dy;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _dragPointerId || _dragStartY == null) return;
    final double offset = event.position.dy - _dragStartY!;
    if (offset <= 0) {
      if (_dragOffset != 0 || _isDragging) {
        setState(() {
          _dragOffset = 0;
          _isDragging = false;
        });
      }
      return;
    }
    setState(() {
      _dragOffset = offset;
      _isDragging = true;
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _dragPointerId) return;
    _dragPointerId = null;
    _dragStartY = null;
    if (_dragOffset >= _dismissThreshold) {
      _dismiss();
    } else {
      setState(() {
        _dragOffset = 0;
        _isDragging = false;
      });
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _dragPointerId) return;
    _dragPointerId = null;
    _dragStartY = null;
    setState(() {
      _dragOffset = 0;
      _isDragging = false;
    });
  }

  void _dismiss() {
    final double target = MediaQuery.of(context).size.height;
    setState(() {
      _dragOffset = target;
      _isDragging = false;
    });
    Future.delayed(_settleDuration, () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
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
            child: AnimatedContainer(
              duration: _isDragging ? Duration.zero : _settleDuration,
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, _dragOffset, 0),
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
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
                              const Text('コメント編集', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            key: _textFieldKey,
                            controller: _controller,
                            focusNode: _focusNode,
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF222222),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                final text = _controller.text;
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
          ),
        ),
      ],
    );
  }
}
