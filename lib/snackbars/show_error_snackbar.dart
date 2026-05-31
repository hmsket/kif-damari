import 'package:flutter/material.dart';

class ShowErrorSnackbar {
  static void show(BuildContext context, String message) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => ErrorSnackBarWidget(
        message: message,
        onDismissed: () {
          if (overlayEntry.mounted) {
            overlayEntry.remove();
          }
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

class ErrorSnackBarWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismissed;

  const ErrorSnackBarWidget({
    super.key,
    required this.message,
    required this.onDismissed,
  });

  @override
  State<ErrorSnackBarWidget> createState() => _ErrorSnackBarWidgetState();
}

class _ErrorSnackBarWidgetState extends State<ErrorSnackBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _startLifecycle();
  }

  Future<void> _startLifecycle() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || _isDismissed) return;
    
    await _controller.forward();    
    _dismiss();
  }

  void _dismiss() {
    if (_isDismissed) return;
    _isDismissed = true;
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPadding + 16,
      left: 16,
      right: 16,
      child: Dismissible(
        key: UniqueKey(),
        direction: DismissDirection.down,
        onDismissed: (direction) {
          _dismiss();
        },
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 70,
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.red[700]!,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.close,
                    color: Colors.red[700],
                    size: 30,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
