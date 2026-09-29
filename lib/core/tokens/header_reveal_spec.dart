import 'motion_primitives.dart';
import 'liquid_morph_spec.dart';

/// Component motion tokens for the shell header swapping the main nav for a
/// route's own header (Edit mode's Things | Zones): the nav's items fade
/// out one after another, left to right, and once the first is gone a glass
/// pane grows out of that spot into the route header — the Inbox mic's
/// stretch into the voice toolbar ([LiquidMorphSpec.dockPane]). Exiting plays
/// it backwards.
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

  /// Nav item [index]'s fade window, as shares of [duration].
  static (double, double) itemWindow(int index) {
    final start = index * staggerMs;
    return (start / totalMs, (start + itemFadeMs) / totalMs);
  }
}
