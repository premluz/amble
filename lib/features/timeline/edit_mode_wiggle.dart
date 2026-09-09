import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The "rearrange mode" wiggle — a small, continuous rotation oscillation
/// applied to every visible Task capsule and Zone container while Edit
/// Mode is active, per CONSTITUTION.md ("same visual language as iOS/
/// Android home-screen rearrange mode"). This is Edit Mode's ONLY
/// persistent visual signal (there is no other chrome distinguishing it
/// from the ordinary Timeline), so it's applied unconditionally to every
/// wiggling block — required, not decorative, per the work order.
///
/// [phaseOffset] (0..1) staggers each block's own oscillation so a Timeline
/// full of blocks doesn't wiggle in perfect unison, which would read as one
/// synchronized animation rather than many independently "loose" items —
/// callers derive it from something stable per-block (e.g. a hash of the
/// task/zone id) so the same block always gets the same offset and
/// doesn't visibly jump phase on rebuild.
///
/// Wraps [child] unconditionally — [enabled] false renders [child] with
/// zero rotation rather than being absent from the tree, so toggling Edit
/// Mode never remounts (and so never disturbs) whatever gesture detector
/// lives inside [child].
class EditModeWiggle extends StatefulWidget {
  const EditModeWiggle({
    super.key,
    required this.enabled,
    required this.child,
    this.phaseOffset = 0,
  });

  final bool enabled;
  final Widget child;
  final double phaseOffset;

  @override
  State<EditModeWiggle> createState() => _EditModeWiggleState();
}

class _EditModeWiggleState extends State<EditModeWiggle>
    with SingleTickerProviderStateMixin {
  /// One full back-and-forth cycle — fast enough to read as "jiggling,"
  /// slow enough not to look like an error state. Matches the reference
  /// home-screen-rearrange cadence (roughly 2-3 wiggles/second) rather
  /// than a token, since no existing motion token in this codebase is
  /// meant for a continuously-repeating animation (every `motion*` token
  /// times a one-shot transition).
  static const _cycleDuration = Duration(milliseconds: 260);

  /// Peak rotation, in radians — small enough that a whole day of blocks
  /// wiggling at once doesn't read as chaotic. ~2.3 degrees.
  static const _maxAngle = 0.04;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycleDuration);
    if (widget.enabled) _start();
  }

  @override
  void didUpdateWidget(EditModeWiggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled == oldWidget.enabled) return;
    if (widget.enabled) {
      _start();
    } else {
      _controller.stop();
      // Eases back to upright rather than snapping the instant Edit Mode
      // turns off — matches the reference's own exit behavior.
      _controller.animateTo(0, duration: _cycleDuration, curve: Curves.easeOut);
    }
  }

  void _start() {
    // Phase-shifted start position (not just a delayed START time) is
    // what actually staggers the oscillation: two controllers both begun
    // at t=0 with different delays would still be in lockstep once both
    // are running, since `repeat(reverse: true)` has no concept of a
    // per-instance phase. Seeding the controller's OWN value before it
    // starts repeating is what keeps every block permanently out of sync
    // with every other one, not just briefly at the start.
    _controller.value = widget.phaseOffset % 1.0;
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // sin, not the raw controller value, so the motion eases through
        // zero at both ends of the swing instead of moving at a constant
        // rate and reversing direction abruptly — a linear back-and-forth
        // reads as mechanical, not "loose."
        final angle = math.sin(_controller.value * math.pi * 2) * _maxAngle;
        return Transform.rotate(
          angle: widget.enabled ? angle : 0,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
