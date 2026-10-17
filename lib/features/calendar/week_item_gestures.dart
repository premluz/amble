import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../../shared/models/scheduled_block.dart';
import '../../shared/providers/week_hour_height_setting.dart';
import 'week_drag.dart';

/// Pointers that drag at once. Touch and pens first hold, as on the Day
/// screen, so a swipe still scrolls the week.
const _mouse = {PointerDeviceKind.mouse};
const _touch = {
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
};

/// Makes a week item movable — to another time or another day — and, when
/// [height] leaves room, resizable from its top and bottom edges. The
/// drag lives in [weekDragProvider]; [onDrop] lands it and ends it.
/// [ghost] fades the item while its preview is elsewhere. Taps reach
/// [child] untouched.
class WeekItemGestures extends ConsumerStatefulWidget {
  const WeekItemGestures({
    super.key,
    required this.item,
    required this.days,
    required this.dayWidth,
    required this.onDrop,
    required this.child,
    this.height = 0,
    this.ghost = false,
  });

  final ScheduledBlock item;
  final List<DateTime> days;
  final double dayWidth;

  /// Lands the drag, dropped at [anchor] (global), then ends it.
  final Future<void> Function(WeekDrag drag, Offset anchor) onDrop;
  final Widget child;

  /// The item's drawn height; 0 (text rows) means move only.
  final double height;
  final bool ghost;

  @override
  ConsumerState<WeekItemGestures> createState() => _WeekItemGesturesState();
}

class _WeekItemGesturesState extends ConsumerState<WeekItemGestures> {
  Offset _origin = Offset.zero;
  Offset _last = Offset.zero;

  WeekDragNotifier get _drags => ref.read(weekDragProvider.notifier);

  /// This item's drag, if it is the one in progress.
  WeekDrag? get _drag {
    final drag = ref.read(weekDragProvider);
    return drag?.item.id == widget.item.id ? drag : null;
  }

  void _begin(WeekDragMode mode, Offset global) {
    _origin = global;
    _last = global;
    _drags.begin(widget.item, mode);
  }

  void _update(Offset global) {
    _last = global;
    final drag = _drag;
    if (drag == null) return;
    final target = weekDragTarget(
      drag,
      delta: global - _origin,
      dayWidth: widget.dayWidth,
      hourHeight: ref.read(weekHourHeightSettingProvider),
      days: widget.days,
    );
    _drags.update(drag.moveTo(target));
  }

  void _end() {
    final drag = _drag;
    if (drag == null) return;
    if (!drag.changed) return _drags.end();
    unawaited(widget.onDrop(drag, _last));
  }

  void _cancel() {
    if (_drag != null) _drags.end();
  }

  @override
  Widget build(BuildContext context) {
    const edge = CalendarGridTokens.weekResizeEdge;
    final move = GestureDetector(
      supportedDevices: _mouse,
      // Measured from the press, not from where the drag passed its slop,
      // so the item follows the pointer exactly.
      dragStartBehavior: DragStartBehavior.down,
      onPanStart: (d) => _begin(WeekDragMode.move, d.globalPosition),
      onPanUpdate: (d) => _update(d.globalPosition),
      onPanEnd: (_) => _end(),
      onPanCancel: _cancel,
      child: GestureDetector(
        supportedDevices: _touch,
        onLongPressStart: (d) => _begin(WeekDragMode.move, d.globalPosition),
        onLongPressMoveUpdate: (d) => _update(d.globalPosition),
        onLongPressEnd: (_) => _end(),
        onLongPressCancel: _cancel,
        child: widget.child,
      ),
    );
    return Opacity(
      opacity: widget.ghost ? DragPreviewTokens.ghostOpacity : 1,
      child: Stack(
        // The item keeps the size its column gives it.
        fit: StackFit.passthrough,
        children: [
          move,
          if (widget.height >= edge * 3)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: edge,
              child: _edge(WeekDragMode.resizeTop),
            ),
          if (widget.height >= edge * 2)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: edge,
              child: _edge(WeekDragMode.resizeBottom),
            ),
        ],
      ),
    );
  }

  Widget _edge(WeekDragMode mode) => MouseRegion(
    cursor: SystemMouseCursors.resizeUpDown,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragStart: (d) => _begin(mode, d.globalPosition),
      onVerticalDragUpdate: (d) => _update(d.globalPosition),
      onVerticalDragEnd: (_) => _end(),
      onVerticalDragCancel: _cancel,
    ),
  );
}
