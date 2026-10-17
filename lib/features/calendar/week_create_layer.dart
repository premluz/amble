import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/week_hour_height_setting.dart';
import '../timeline/pending_task_draft_provider.dart';
import '../timeline/timeline_drag_math.dart';

/// The empty space of one week day: draws a new task. Click and drag
/// sweeps its span (as in desktop calendars); a hold makes the Day screen's
/// 15-minute draft, and dragging while holding stretches it. On release
/// the draft opens in the side panel. Sits under the day's items, so they
/// keep their own gestures.
class WeekCreateLayer extends ConsumerStatefulWidget {
  const WeekCreateLayer({super.key, required this.day});

  final DateTime day;

  @override
  ConsumerState<WeekCreateLayer> createState() => _WeekCreateLayerState();
}

class _WeekCreateLayerState extends ConsumerState<WeekCreateLayer> {
  /// Where the press began, in minutes since midnight.
  int _anchor = 0;

  PendingTaskDraftNotifier get _drafts =>
      ref.read(pendingTaskDraftProvider.notifier);

  double get _pixelsPerMinute =>
      ref.read(weekHourHeightSettingProvider) / Duration.minutesPerHour;

  DateTime _at(int minutes) =>
      DateTime(widget.day.year, widget.day.month, widget.day.day, 0, minutes);

  int _snapped(double y) {
    final steps = (y / _pixelsPerMinute / dragSnapMinutes).round();
    return math.min(
      Duration.minutesPerDay,
      math.max(0, steps * dragSnapMinutes),
    );
  }

  void _start(double y) {
    _anchor = math.min(
      Duration.minutesPerDay - quickAddDefaultMinutes,
      _snapped(y),
    );
    _drafts.start(
      scheduledAt: _at(_anchor),
      durationMinutes: quickAddDefaultMinutes,
    );
  }

  /// Click and drag: the draft spans from the press to the pointer, either
  /// way, at least the default length.
  void _sweep(double y) {
    final to = _snapped(y);
    final minutes = math.max(quickAddDefaultMinutes, (to - _anchor).abs());
    final from = math.min(
      Duration.minutesPerDay - minutes,
      math.min(_anchor, to),
    );
    _drafts
      ..updatePosition(_at(from))
      ..updateDuration(minutes);
  }

  /// Hold and drag, as on the Day screen: the end follows the pointer.
  void _stretch(double dy) => _drafts.updateDuration(
    math.max(
      minTaskDurationMinutes,
      quickAddDefaultMinutes + snappedDurationDelta(dy, _pixelsPerMinute),
    ),
  );

  void _open() {
    if (ref.read(pendingTaskDraftProvider) == null) return;
    ref.read(quickAddSheetVisibleProvider.notifier).show();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    supportedDevices: const {PointerDeviceKind.mouse},
    // The draft starts where the press began, not past the drag slop.
    dragStartBehavior: DragStartBehavior.down,
    onPanStart: (d) => _start(d.localPosition.dy),
    onPanUpdate: (d) => _sweep(d.localPosition.dy),
    onPanEnd: (_) => _open(),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (d) => _start(d.localPosition.dy),
      onLongPressMoveUpdate: (d) => _stretch(d.offsetFromOrigin.dy),
      onLongPressEnd: (_) => _open(),
    ),
  );
}
