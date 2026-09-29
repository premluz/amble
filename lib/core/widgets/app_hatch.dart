import 'package:flutter/widgets.dart';

/// Fills its box with thin parallel lines at 45°, rising left to right:
/// the brand's "provenance" texture for things that come from elsewhere
/// (imported calendar events). Paint-only; the caller clips it to a shape.
class AppHatch extends StatelessWidget {
  const AppHatch({
    super.key,
    required this.color,
    required this.spacing,
    required this.strokeWidth,
  }) : assert(spacing > 0),
       assert(strokeWidth > 0);

  final Color color;

  /// Distance between neighbouring lines, measured along the box's width.
  final double spacing;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _HatchPainter(color, spacing, strokeWidth),
    size: Size.infinite,
  );
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter(this.color, this.spacing, this.strokeWidth);

  final Color color;
  final double spacing;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;
    // Each line runs from the bottom edge up at 45°; starting one full
    // height to the left covers the bottom-left corner as well.
    final reach = size.height;
    for (var x = -reach; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, size.height), Offset(x + reach, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) =>
      old.color != color ||
      old.spacing != spacing ||
      old.strokeWidth != strokeWidth;
}
