import 'dart:async';

import 'package:flutter/material.dart';

/// Detects a two-finger long-press anywhere within [child]'s bounds and
/// fires [onTwoFingerLongPress] — the second Edit Mode entry point per
/// CONSTITUTION.md, alongside the "Edit" text link.
///
/// Flutter has no built-in two-finger-long-press recognizer — every
/// stock long-press widget (`GestureDetector.onLongPress`,
/// `LongPressDraggable`) tracks exactly one pointer's gesture arena. This
/// is built on the lower-level [Listener] instead, which reports every
/// raw pointer event regardless of how many fingers are down, without
/// itself entering the gesture arena — critical here, since it must NOT
/// compete with (or require restructuring) either the existing single-
/// finger long-press-to-create gesture (`PlaceTaskLineLayer`, a
/// `LongPressDraggable`) or the existing single-finger drag-to-reschedule
/// gesture (`TaskCapsuleBlock`'s own `GestureDetector`) already present in
/// the same subtree. A `Listener` observes pointers passively — it never
/// claims them — so a single-finger gesture underneath still starts and
/// resolves completely normally; this widget simply also counts how many
/// pointers are simultaneously down and reacts once that count is exactly
/// two.
///
/// Algorithm: once the pointer count transitions to exactly 2 (from 1),
/// start a ~400ms timer and record both pointers' starting positions. The
/// timer fires (calling [onTwoFingerLongPress]) only if, for its whole
/// duration, the count stayed at exactly 2 AND neither pointer moved more
/// than [_moveThreshold] from where it started. A 3rd pointer joining, a
/// pointer lifting before the timer fires, or either pointer moving past
/// the threshold cancels the timer outright — matching an ordinary
/// single-finger long-press's own "movement/extra touch cancels it"
/// contract, just generalized to two fingers.
class TwoFingerLongPress extends StatefulWidget {
  const TwoFingerLongPress({
    super.key,
    required this.onTwoFingerLongPress,
    required this.child,
  });

  final VoidCallback onTwoFingerLongPress;
  final Widget child;

  @override
  State<TwoFingerLongPress> createState() => _TwoFingerLongPressState();
}

class _TwoFingerLongPressState extends State<TwoFingerLongPress> {
  static const _pressDuration = Duration(milliseconds: 400);

  /// How far a tracked pointer may drift from its down-position before the
  /// pending long-press is cancelled — generous enough to absorb a
  /// resting finger's natural micro-jitter, tight enough that an actual
  /// two-finger drag/pinch never fires this instead.
  static const _moveThreshold = 12.0;

  final Map<int, Offset> _downPositions = {};
  Timer? _timer;

  void _handlePointerDown(PointerDownEvent event) {
    _downPositions[event.pointer] = event.position;

    // A 3rd (or later) pointer joining an already-pending 2-finger press
    // invalidates it outright — three fingers down is not this gesture.
    if (_downPositions.length != 2) {
      _cancelTimer();
      return;
    }

    _timer = Timer(_pressDuration, () {
      _timer = null;
      widget.onTwoFingerLongPress();
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final start = _downPositions[event.pointer];
    if (start == null) return;
    if ((event.position - start).distance > _moveThreshold) {
      _cancelTimer();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _downPositions.remove(event.pointer);
    // Any pointer lifting while a 2-finger press is pending cancels it —
    // regardless of whether it was one of the two originally tracked
    // pointers, since the count is no longer 2 either way.
    _cancelTimer();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _downPositions.remove(event.pointer);
    _cancelTimer();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Passive observation only — `HitTestBehavior.translucent` lets
      // every pointer event still reach `child`'s own gesture detectors
      // underneath, which is the whole point: this widget must never
      // intercept a single-finger gesture, only watch alongside it.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }
}
