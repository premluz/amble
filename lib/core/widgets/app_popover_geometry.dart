import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Where a popover of [size] goes beside [anchor] (both in screen
/// coordinates): to the anchor's left first, top-aligned with it, as a
/// side panel's pickers open over the content beside the panel; then to
/// its right; then below it. Always kept inside [bounds].
Offset popoverOrigin({
  required Rect anchor,
  required Size size,
  required Rect bounds,
  required double gap,
}) {
  final top = _clamp(anchor.top, bounds.top, bounds.bottom - size.height);
  final leftOfAnchor = anchor.left - gap - size.width;
  if (leftOfAnchor >= bounds.left) return Offset(leftOfAnchor, top);
  final rightOfAnchor = anchor.right + gap;
  if (rightOfAnchor + size.width <= bounds.right) {
    return Offset(rightOfAnchor, top);
  }
  return Offset(
    _clamp(anchor.left, bounds.left, bounds.right - size.width),
    _clamp(anchor.bottom + gap, bounds.top, bounds.bottom - size.height),
  );
}

/// [value] within [min]..[max]; [min] wins when the popover is larger than
/// the room, so its top-left (and its header) stays on screen.
double _clamp(double value, double min, double max) =>
    math.max(min, math.min(value, max));
