import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../../shared/providers/week_hour_height_setting.dart';

/// The scroll offset that keeps the time under [anchorY] (a point in the
/// viewport) still when the hour height changes from [fromHeight] to
/// [toHeight].
double weekAnchoredScrollOffset({
  required double scrollOffset,
  required double anchorY,
  required double fromHeight,
  required double toHeight,
}) => (scrollOffset + anchorY) * toHeight / fromHeight - anchorY;

/// Zooms the week's hour height: Cmd (macOS) / Ctrl (elsewhere) + scroll,
/// or a trackpad pinch. Same gestures as the Day timeline's zoom, kept
/// around the point under the pointer. While the modifier is held the child
/// ignores pointers so its scroll view doesn't scroll instead.
class WeekZoom extends ConsumerStatefulWidget {
  const WeekZoom({super.key, required this.scroll, required this.child});

  final ScrollController scroll;
  final Widget child;

  @override
  ConsumerState<WeekZoom> createState() => _WeekZoomState();
}

class _WeekZoomState extends ConsumerState<WeekZoom> {
  bool _modifierHeld = false;
  double _lastPinchScale = 1;

  /// The offset the latest zoom wants, applied after the frame that resizes
  /// the grid (several events can land in one frame).
  double? _pendingOffset;

  static bool _modifierPressed() {
    final keyboard = HardwareKeyboard.instance;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.iOS => keyboard.isMetaPressed,
      _ => keyboard.isControlPressed,
    };
  }

  // Also run on hover, so a key-up missed while the window was in the
  // background can't leave the grid ignoring pointers.
  bool _syncModifier([Object? _]) {
    final held = _modifierPressed();
    if (held != _modifierHeld && mounted) setState(() => _modifierHeld = held);
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_syncModifier);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_syncModifier);
    super.dispose();
  }

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_modifierPressed()) return;
    final scrolled = event.scrollDelta.dy;
    final anchor = event.localPosition;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (_) => _zoomBy(
        math.exp(-scrolled / TimelineScrollTokens.scrollZoomDivisor),
        anchor,
      ),
    );
  }

  /// A trackpad pinch carries a cumulative scale; a two-finger scroll with
  /// the modifier held arrives as a pan.
  void _onPanZoom(PointerPanZoomUpdateEvent event) {
    if (event.scale != 1 || _lastPinchScale != 1) {
      final ratio = event.scale / _lastPinchScale;
      _lastPinchScale = event.scale;
      _zoomBy(ratio, event.localPosition);
    } else if (_modifierPressed()) {
      _zoomBy(
        math.exp(event.panDelta.dy / TimelineScrollTokens.scrollZoomDivisor),
        event.localPosition,
      );
    }
  }

  void _zoomBy(double factor, Offset anchor) {
    final from = ref.read(weekHourHeightSettingProvider);
    final notifier = ref.read(weekHourHeightSettingProvider.notifier);
    unawaited(notifier.zoomBy(factor));
    final to = ref.read(weekHourHeightSettingProvider);
    final scroll = widget.scroll;
    if (to == from || !scroll.hasClients) return;
    final scheduled = _pendingOffset != null;
    _pendingOffset = weekAnchoredScrollOffset(
      scrollOffset: _pendingOffset ?? scroll.offset,
      anchorY: anchor.dy,
      fromHeight: from,
      toHeight: to,
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

  @override
  Widget build(BuildContext context) => Listener(
    // Translucent: while the child ignores pointers nothing under the
    // Listener is hit, and it must still hear the scroll.
    behavior: HitTestBehavior.translucent,
    onPointerSignal: _onSignal,
    onPointerHover: _syncModifier,
    onPointerPanZoomStart: (_) => _lastPinchScale = 1,
    onPointerPanZoomUpdate: _onPanZoom,
    onPointerPanZoomEnd: (_) => _lastPinchScale = 1,
    child: IgnorePointer(ignoring: _modifierHeld, child: widget.child),
  );
}
