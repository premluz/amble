import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/preferences_providers.dart';

/// Detects a two-finger pinch anywhere within [child]'s bounds and adjusts
/// [TimelinePixelsPerMinuteSetting] live — the Timeline's own vertical
/// time-scale zoom, shared by the spatial Task view and the Zone Grid/Edit
/// screen. Requested directly: "we can set scale size in dev settings...
/// let's add pinch zoom in out timeline spatial in view and edit modes
/// (zones also) to zoom in and out scale."
///
/// Built on the same passive-[Listener] foundation as
/// [TwoFingerLongPress] (see that widget's own doc comment for the full
/// reasoning) rather than [GestureDetector]'s built-in `onScale*`
/// callbacks — confirmed via AskUserQuestion. `GestureDetector.onScale`
/// CLAIMS the gesture arena, which on the Zone Grid screen specifically
/// would compete with (or require restructuring) the existing opaque
/// `'zone-paint-surface'` `GestureDetector` that already owns long-press
/// (view mode) and pan (edit mode) for zone painting — the same
/// coexistence problem `TwoFingerLongPress` was already built to solve
/// for Edit Mode entry. A [Listener] observes every pointer passively; a
/// genuine single-finger paint/drag/scroll gesture underneath is
/// completely unaffected, and this widget only acts once a SECOND pointer
/// is confirmed down alongside the first.
///
/// Algorithm: once exactly 2 pointers are down, record the distance
/// between them. On every subsequent move (while still exactly 2
/// pointers), compute the new distance and scale [pixelsPerMinute] by the
/// ratio of new-to-old distance, clamped to
/// [TimelinePixelsPerMinuteSetting]'s own min/max — the same clamp the
/// setting's own `set()` applies, so this is never the only thing
/// enforcing the range. A 3rd pointer joining, or either of the two
/// original pointers lifting, ends the pinch (the next 2-pointer state
/// starts a fresh baseline distance rather than continuing the old one).
///
/// Single-finger interactions (scroll, drag-to-reschedule, long-press-to-
/// create, zone paint) are untouched in every mode — Task view's normal
/// state, Task view's Edit Mode (no structural difference at the level
/// this widget wraps — see docs/DECISIONS.md), Zone Grid's view mode, and
/// Zone Grid's edit mode all get this same widget wrapping the same
/// scrollable surface.
class TimelinePinchZoom extends ConsumerStatefulWidget {
  const TimelinePinchZoom({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TimelinePinchZoom> createState() => _TimelinePinchZoomState();
}

class _TimelinePinchZoomState extends ConsumerState<TimelinePinchZoom> {
  final Map<int, Offset> _positions = {};

  /// The distance between the two tracked pointers when the current pinch
  /// began (or was last re-based after a pointer count change) — null
  /// whenever fewer/more than exactly 2 pointers are down.
  double? _baselineDistance;

  /// [TimelinePixelsPerMinuteSetting]'s own value at the moment
  /// [_baselineDistance] was recorded — the pinch scales FROM this, not
  /// from a continuously-compounding value, so floating-point drift never
  /// accumulates across a single long pinch gesture.
  double? _baselineScale;

  void _handlePointerDown(PointerDownEvent event) {
    _positions[event.pointer] = event.position;
    _rebaseIfExactlyTwo();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_positions.containsKey(event.pointer)) return;
    _positions[event.pointer] = event.position;

    final baselineDistance = _baselineDistance;
    final baselineScale = _baselineScale;
    if (_positions.length != 2 || baselineDistance == null || baselineScale == null) {
      return;
    }
    if (baselineDistance == 0) return;

    final currentDistance = _distanceBetween();
    final ratio = currentDistance / baselineDistance;
    ref
        .read(timelinePixelsPerMinuteSettingProvider.notifier)
        .set(baselineScale * ratio);
  }

  void _handlePointerUp(PointerUpEvent event) {
    _positions.remove(event.pointer);
    _rebaseIfExactlyTwo();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _positions.remove(event.pointer);
    _rebaseIfExactlyTwo();
  }

  /// Re-establishes the pinch's own starting distance/scale whenever the
  /// tracked pointer count transitions to (or away from) exactly 2 — a
  /// 3rd finger joining, or dropping to 1/0, always ends the current pinch
  /// rather than letting it continue with a stale baseline.
  void _rebaseIfExactlyTwo() {
    if (_positions.length == 2) {
      setState(() {
        _baselineDistance = _distanceBetween();
        _baselineScale = ref.read(timelinePixelsPerMinuteSettingProvider);
      });
    } else {
      _baselineDistance = null;
      _baselineScale = null;
    }
  }

  double _distanceBetween() {
    final points = _positions.values.toList();
    return (points[0] - points[1]).distance;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Translucent, same reasoning as TwoFingerLongPress: this widget
      // must never intercept a single-finger gesture underneath, only
      // watch alongside it.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }
}
