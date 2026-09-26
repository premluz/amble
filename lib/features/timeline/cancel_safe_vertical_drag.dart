import 'package:flutter/material.dart';

/// Owns one vertical drag until end or pointer cancellation, forwarding
/// cancellation exactly once after a drag has started.
class CancelSafeVerticalDrag extends StatefulWidget {
  const CancelSafeVerticalDrag({
    super.key,
    required this.child,
    this.onTap,
    this.onStart,
    this.onUpdate,
    this.onEnd,
    this.onCancel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final GestureDragStartCallback? onStart;
  final GestureDragUpdateCallback? onUpdate;
  final GestureDragEndCallback? onEnd;
  final VoidCallback? onCancel;

  @override
  State<CancelSafeVerticalDrag> createState() => _CancelSafeVerticalDragState();
}

class _CancelSafeVerticalDragState extends State<CancelSafeVerticalDrag> {
  bool _active = false;

  void _start(DragStartDetails details) {
    _active = true;
    widget.onStart?.call(details);
  }

  void _end(DragEndDetails details) {
    if (!_active) return;
    _active = false;
    widget.onEnd?.call(details);
  }

  void _cancel() {
    if (!_active) return;
    _active = false;
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final handlesDrag =
        widget.onStart != null ||
        widget.onUpdate != null ||
        widget.onEnd != null ||
        widget.onCancel != null;
    return Listener(
      onPointerCancel: (_) => _cancel(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onVerticalDragStart: handlesDrag ? _start : null,
        onVerticalDragUpdate: widget.onUpdate,
        onVerticalDragEnd: handlesDrag ? _end : null,
        onVerticalDragCancel: handlesDrag ? _cancel : null,
        child: widget.child,
      ),
    );
  }
}
