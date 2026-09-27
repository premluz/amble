import 'package:flutter/material.dart';

/// Paints behind rounded keyboards without reserving their inset a second time.
class SheetKeyboardBackground extends StatelessWidget {
  const SheetKeyboardBackground({
    super.key,
    required this.inset,
    required this.color,
    required this.child,
  });

  final double inset;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _KeyboardBackgroundPainter(inset, color),
    child: child,
  );
}

class _KeyboardBackgroundPainter extends CustomPainter {
  const _KeyboardBackgroundPainter(this.inset, this.color);

  final double inset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (inset <= 0) return;
    canvas.drawRect(
      Rect.fromLTRB(
        0,
        (size.height - inset).clamp(0, size.height),
        size.width,
        size.height,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_KeyboardBackgroundPainter oldDelegate) =>
      inset != oldDelegate.inset || color != oldDelegate.color;
}
