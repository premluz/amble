import 'package:flutter/widgets.dart';

import 'app_bubble_burst.dart';
import 'app_water_ripple.dart';

/// The overlay half of a task's completion moment: bubbles rising from the
/// pill's top and the faint water ripple leaving its outline. The pill's own
/// bounce is state-driven (`AppLiquidPulse` with `LiquidPulseSpec.complete`
/// on the completed flag), so it plays on every completion path by itself.
abstract final class AppCompletionFeedback {
  /// [pill] is the pill's rect in [context]'s local coordinates, and
  /// [radius] its corner radius.
  static void play({
    required BuildContext context,
    required Rect pill,
    required double radius,
  }) {
    AppBubbleBurst.show(
      context: context,
      origin: pill.topCenter,
      sourceWidth: pill.width,
    );
    AppWaterRipple.show(context: context, rect: pill, radius: radius);
  }
}
