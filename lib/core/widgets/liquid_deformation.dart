import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../tokens/liquid_press_spec.dart';
import '../tokens/liquid_pulse_spec.dart';

/// The shared mechanics behind every liquid deformation: ease out to a
/// signed target (negative squeezes, positive swells), hold, then spring home
/// on a native spring that overshoots and lands exactly at rest.
/// Owned by a State; call [dispose] from its dispose.
class LiquidDeformation {
  LiquidDeformation(TickerProvider vsync)
    : _value = AnimationController.unbounded(vsync: vsync);

  /// Signed deformation: 0 at rest, negative squeezed, positive swollen.
  final AnimationController _value;
  var _disposed = false;

  Listenable get listenable => _value;

  /// Current signed deformation.
  double get value => _value.value;

  /// The in-flight approach to a target, until it lands. A quick tap lifts
  /// before then.
  TickerFuture? _approaching;

  /// Eases to [target] and holds there until [springHome].
  TickerFuture moveTo(double target, Duration duration) {
    final approaching = _value.animateTo(
      target,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
    _approaching = approaching;
    approaching.then((_) {
      if (identical(_approaching, approaching)) _approaching = null;
    });
    return approaching;
  }

  /// Springs back to rest, keeping the current velocity. A release that
  /// arrives mid-approach waits for it to land first, so even the quickest
  /// tap shows the full deformation instead of a flicker.
  void springHome(Duration duration, double bounce) {
    final approaching = _approaching;
    if (approaching != null) {
      approaching.then((_) => _spring(duration, bounce));
      return;
    }
    _spring(duration, bounce);
  }

  void _spring(Duration duration, double bounce) {
    if (_disposed) return;
    _value
        .animateWith(
          SpringSimulation(
            SpringDescription.withDurationAndBounce(
              duration: duration,
              bounce: bounce,
            ),
            _value.value,
            0,
            _value.velocity,
          ),
        )
        // The simulation stops within its tolerance, not at exactly 0;
        // without this the child keeps a permanent sub-pixel scale.
        .then((_) {
          if (!_disposed) _value.value = 0;
        });
  }

  /// Squeezes in to [LiquidPulseSpec.depth] and holds.
  TickerFuture compress(LiquidPulseSpec spec) =>
      moveTo(-spec.depth, spec.compressDuration);

  void release(LiquidPulseSpec spec) =>
      springHome(spec.springDuration, spec.bounce);

  /// A full squeeze-and-release with no finger involved.
  void pulse(LiquidPulseSpec spec) {
    compress(spec);
    release(spec);
  }

  /// Swells a control whose longest side is [longestSide] and holds.
  void press(LiquidPressSpec spec, double longestSide) =>
      moveTo(spec.growFor(longestSide), spec.growDuration);

  void unpress(LiquidPressSpec spec) =>
      springHome(spec.releaseDuration, spec.releaseBounce);

  /// Drops any deformation in progress and snaps to rest, for when the
  /// object must track a finger exactly.
  void settle() {
    _approaching = null;
    if (_value.value != 0 || _value.isAnimating) _value.value = 0;
  }

  /// Vertical scale follows the deformation fully; horizontal withholds
  /// [squash] of it, which is what reads as liquid.
  Matrix4 matrix(double squash) {
    final e = _value.value;
    return Matrix4.diagonal3Values(1 + e * (1 - squash), 1 + e, 1);
  }

  void dispose() {
    _disposed = true;
    _value.dispose();
  }
}
