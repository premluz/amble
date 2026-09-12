import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/timeline_screen.dart';

/// Pure-math coverage for [entranceScaleFor] — the just-created task's
/// pill "pop in and spring/bounce back" entrance, requested directly:
/// "scale up... larger than the task pill e.g. 120% and bounce to 100%
/// width, and kind of spring easing." Driving the real animation through
/// `_DraggableTaskBlock`'s `fadeInOnFirstBuild` requires the full
/// `TimelineScreen` plus `recentlySavedTaskProvider` wiring for a purely
/// deterministic curve computation, so this tests the extracted function
/// directly instead.
void main() {
  test('starts at 0 — the pill pops in from nothing, not from its resting '
      'size', () {
    expect(entranceScaleFor(0), 0.0);
  });

  test('settles back to exactly 1.0 at progress 1 — no residual scale', () {
    expect(entranceScaleFor(1), 1.0);
  });

  test('peaks at exactly 1.2 (120%) partway through, not just below or '
      'above it', () {
    var peak = 0.0;
    for (var i = 0; i <= 1000; i++) {
      final progress = i / 1000;
      final scale = entranceScaleFor(progress);
      if (scale > peak) peak = scale;
    }
    expect(peak, closeTo(1.2, 0.001));
  });

  test('overshoots past 1.0 before settling — the "bounce" shape, not a '
      'plain ease-in', () {
    // Somewhere in the back half of the animation the scale must exceed
    // 1.0 (the overshoot) before landing back exactly on it at progress 1
    // — this is what makes it a spring/bounce rather than a monotonic
    // approach to 1.0.
    final samples = [for (var i = 1; i < 10; i++) entranceScaleFor(i / 10)];
    expect(
      samples.any((s) => s > 1.0),
      isTrue,
      reason:
          'no sample overshot 1.0 — this would just be a fade, not a '
          'spring bounce',
    );
  });

  test('never dips below 0 or rises above the 1.2 peak — a bounded curve', () {
    for (var i = 0; i <= 100; i++) {
      final scale = entranceScaleFor(i / 100);
      expect(scale, greaterThanOrEqualTo(0.0));
      expect(scale, lessThanOrEqualTo(1.2001));
    }
  });
}
