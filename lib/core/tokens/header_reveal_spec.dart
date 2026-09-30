import 'dart:ui' show Size;

import 'motion_primitives.dart';
import 'liquid_morph_spec.dart';

/// Component motion tokens for the shell header swapping the main nav for a
/// route's own header (Edit mode's Things | Zones): the nav's items fade
/// out one after another, left to right, and once the first is gone a glass
/// pane falls out of the notch — a pill the Dynamic Island's size, centred
/// at the top of the screen — and widens on both sides into the route
/// header, with the Inbox mic's stretch into the voice toolbar
/// ([LiquidMorphSpec.dockPane]). Exiting plays it backwards: the pane
/// narrows on both sides and rises into the notch while the nav returns.
abstract final class HeaderRevealSpec {
  /// One nav item's fade.
  static const itemFadeMs = MotionPrimitives.durationViewCrossfadeMs;

  /// Delay between consecutive nav items, the dock's own stagger.
  static const staggerMs = MotionPrimitives.durationContextDockStaggerMs;

  /// The pane starts growing as the first nav item finishes leaving.
  static const morphStartMs = itemFadeMs;

  static const morph = LiquidMorphSpec.dockPane;

  /// Long enough for the morph's slowest spring (its pop) to settle.
  static double get morphSeconds => [
    morph.widthSeconds,
    morph.heightSeconds,
    morph.popSeconds,
  ].reduce((a, b) => a > b ? a : b);

  static int get totalMs =>
      morphStartMs + (morphSeconds * Duration.millisecondsPerSecond).round();

  static Duration get duration => Duration(milliseconds: totalMs);

  /// Where the morph starts, as a share of [duration].
  static double get morphStart => morphStartMs / totalMs;

  /// The pane's origin: the Dynamic Island's footprint (its size, and its
  /// distance below the screen's top). The pane emerges from under it, so
  /// the island itself hides the join.
  static const notchSize = Size(126, 37);
  static const notchTop = 11.0;

  /// Coming back, the nav doesn't wait for the pane: its items fade in
  /// while the pane shrinks away, starting this far into the return.
  static const returnLeadMs = itemFadeMs ~/ 2;

  /// Nav item [index]'s fade-in window on the way back, as controller
  /// values (the controller runs 1 → 0), in reading order.
  static (double, double) itemReturnWindow(int index) {
    final startMs = returnLeadMs + index * staggerMs;
    return (1 - (startMs + itemFadeMs) / totalMs, 1 - startMs / totalMs);
  }

  /// Nav item [index]'s fade window, as shares of [duration].
  static (double, double) itemWindow(int index) {
    final start = index * staggerMs;
    return (start / totalMs, (start + itemFadeMs) / totalMs);
  }
}
