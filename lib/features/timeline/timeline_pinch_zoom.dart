import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../../shared/providers/preferences_providers.dart';
import 'timeline_debug_zoom_controls.dart';
import 'timeline_simulated_pinch.dart';

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
/// **Scroll-wheel zoom (desktop), 2026-10-09 — requested directly: "cmd +
/// scroll should be zoom in/out timeline on desktop."** While Cmd (macOS)
/// or Ctrl (elsewhere) is held, a mouse wheel or a two-finger trackpad
/// scroll zooms the scale around the pointer instead of scrolling. The
/// scroll view would otherwise claim the scroll first, so while the key is
/// held the wrapped child ignores pointers (this widget's listener, above
/// it, still receives them). Scroll up zooms in.
///
/// Single-finger interactions (scroll, drag-to-reschedule, long-press-to-
/// create, zone paint) are untouched in every mode — Task view's normal
/// state, Task view's Edit Mode (no structural difference at the level
/// this widget wraps — see docs/DECISIONS.md), Zone Grid's view mode, and
/// Zone Grid's edit mode all get this same widget wrapping the same
/// scrollable surface.
class TimelinePinchZoom extends ConsumerStatefulWidget {
  const TimelinePinchZoom({
    super.key,
    required this.child,
    this.multiTouch,
    this.scrollController,
  });

  final Widget child;
  final ScrollController? scrollController;

  /// Set true while two or more fingers are down (a pinch), false once
  /// fewer are — so a single-finger gesture (a marquee sweep) can stand
  /// aside for a pinch. Pass one to watch it from ABOVE this widget (the
  /// zone grid builds this one); descendants read it via
  /// [TimelineMultiTouch]. Owned by the caller when given, else internal.
  final ValueNotifier<bool>? multiTouch;

  @override
  ConsumerState<TimelinePinchZoom> createState() => _TimelinePinchZoomState();
}

class _TimelinePinchZoomState extends ConsumerState<TimelinePinchZoom> {
  final Map<int, Offset> _positions = {};

  /// Cmd (macOS / iOS) or Ctrl (elsewhere) is held: scrolling zooms.
  bool _zoomModifierHeld = false;

  /// The scroll offset the latest scroll-wheel zoom wants, applied after
  /// the frame that rescales the content (several events can land in one
  /// frame); null when none is waiting.
  double? _pendingOffset;

  static bool _modifierPressed() {
    final keyboard = HardwareKeyboard.instance;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.iOS => keyboard.isMetaPressed,
      _ => keyboard.isControlPressed,
    };
  }

  /// Follows the modifier. Also called on hover, so a key-up missed while
  /// the window was in the background can't leave the timeline ignoring
  /// pointers.
  bool _syncModifier([Object? _]) {
    final held = _modifierPressed();
    if (held != _zoomModifierHeld && mounted) {
      setState(() => _zoomModifierHeld = held);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_syncModifier);
  }

  late final ValueNotifier<bool> _ownMultiTouch = ValueNotifier(false);
  ValueNotifier<bool> get _multiTouch => widget.multiTouch ?? _ownMultiTouch;

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_syncModifier);
    _ownMultiTouch.dispose();
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_modifierPressed()) return;
    final scrolled = event.scrollDelta.dy;
    final anchor = event.localPosition;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (_) => _zoomBy(scrolled, anchor),
    );
  }

  /// A trackpad's two-finger scroll arrives as pan/zoom updates; content
  /// follows the fingers, so fingers moving down is scrolling up.
  void _handlePanZoom(PointerPanZoomUpdateEvent event) {
    if (_modifierPressed()) _zoomBy(-event.panDelta.dy, event.localPosition);
  }

  /// Zooms by [scrolled] (positive: scrolling down, zooming out), keeping
  /// the time under [anchor] still.
  void _zoomBy(double scrolled, Offset anchor) {
    if (scrolled == 0) return;
    final from = ref.read(timelinePixelsPerMinuteSettingProvider);
    final to =
        (from * math.exp(-scrolled / TimelineScrollTokens.scrollZoomDivisor))
            .clamp(
              TimelinePixelsPerMinuteSetting.minPixelsPerMinute,
              TimelinePixelsPerMinuteSetting.maxPixelsPerMinute,
            );
    if (to == from) return;
    ref.read(timelinePixelsPerMinuteSettingProvider.notifier).set(to);
    final scroll = widget.scrollController;
    if (scroll == null || !scroll.hasClients) return;
    final scheduled = _pendingOffset != null;
    _pendingOffset = timelineAnchoredScrollOffset(
      scrollOffset: _pendingOffset ?? scroll.offset,
      anchorY: anchor.dy,
      fromScale: from,
      toScale: to,
    );
    if (scheduled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _pendingOffset;
      _pendingOffset = null;
      if (target == null || !mounted || !scroll.hasClients) return;
      final position = scroll.position;
      scroll.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

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
    if (_positions.length != 2 ||
        baselineDistance == null ||
        baselineScale == null) {
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
    _multiTouch.value = _positions.length >= 2;
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
      onPointerHover: _syncModifier,
      onPointerSignal: _handlePointerSignal,
      onPointerPanZoomUpdate: _handlePanZoom,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: TimelineMultiTouch(
        notifier: _multiTouch,
        child: TimelineDebugZoomControls(
          multiTouch: _multiTouch,
          scrollController: widget.scrollController,
          // While Cmd/Ctrl is held the child ignores pointers so the scroll
          // view can't claim the wheel; this listener, above, still hears it.
          child: IgnorePointer(
            ignoring: _zoomModifierHeld,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Whether two or more fingers are down on the surrounding
/// [TimelinePinchZoom] — a pinch, which single-finger gestures (the marquee
/// sweeps in Edit Tasks and Edit Zones) must not be mistaken for.
class TimelineMultiTouch extends InheritedNotifier<ValueNotifier<bool>> {
  const TimelineMultiTouch({
    super.key,
    required ValueNotifier<bool> super.notifier,
    required super.child,
  });

  /// The live signal, without rebuilding on its changes (listen to it
  /// instead). Null outside a [TimelinePinchZoom].
  static ValueNotifier<bool>? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TimelineMultiTouch>()?.notifier;
}
