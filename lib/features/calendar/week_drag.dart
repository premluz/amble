import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/scheduled_block.dart';
import '../timeline/timeline_drag_math.dart';

/// What a week drag changes: the whole item, or one of its edges.
enum WeekDragMode { move, resizeTop, resizeBottom }

/// A task (or the new-task draft) being moved or resized in the week: the
/// [item] as it rests, and where it would land if dropped now.
@immutable
class WeekDrag {
  const WeekDrag({
    required this.item,
    required this.mode,
    required this.start,
    required this.durationMinutes,
  });

  final ScheduledBlock item;
  final WeekDragMode mode;
  final DateTime start;
  final int durationMinutes;

  int get originMinutes =>
      item.scheduledEnd.difference(item.scheduledStart).inMinutes;

  bool get changed =>
      start != item.scheduledStart || durationMinutes != originMinutes;

  bool isOn(DateTime day) =>
      start.year == day.year &&
      start.month == day.month &&
      start.day == day.day;

  WeekDrag moveTo(({DateTime start, int durationMinutes}) target) => WeekDrag(
    item: item,
    mode: mode,
    start: target.start,
    durationMinutes: target.durationMinutes,
  );
}

/// The drag in progress in the week, if any. Columns draw the dragged item
/// faded where it rests and the preview where it would land.
class WeekDragNotifier extends Notifier<WeekDrag?> {
  @override
  WeekDrag? build() => null;

  void begin(ScheduledBlock item, WeekDragMode mode) => state = WeekDrag(
    item: item,
    mode: mode,
    start: item.scheduledStart,
    durationMinutes: item.scheduledEnd
        .difference(item.scheduledStart)
        .inMinutes,
  );

  void update(WeekDrag drag) => state = drag;

  void end() => state = null;
}

final weekDragProvider = NotifierProvider<WeekDragNotifier, WeekDrag?>(
  WeekDragNotifier.new,
);

/// Where [drag]'s item lands after the pointer moved [delta] since the drag
/// began: time snapped as on the Day screen, a move crossing to the day
/// column it is over (within [days]), always inside one day.
({DateTime start, int durationMinutes}) weekDragTarget(
  WeekDrag drag, {
  required Offset delta,
  required double dayWidth,
  required double hourHeight,
  required List<DateTime> days,
}) {
  final pixelsPerMinute = hourHeight / Duration.minutesPerHour;
  final origin = drag.item.scheduledStart;
  final span = (
    start: origin.hour * Duration.minutesPerHour + origin.minute,
    duration: drag.originMinutes,
  );
  return switch (drag.mode) {
    WeekDragMode.move => _move(
      span,
      _targetDay(origin, delta.dx, dayWidth, days),
      snappedMinutesDelta(delta.dy, pixelsPerMinute),
    ),
    WeekDragMode.resizeBottom => _resizeBottom(
      span,
      origin,
      snappedDurationDelta(delta.dy, pixelsPerMinute),
    ),
    WeekDragMode.resizeTop => _resizeTop(
      span,
      origin,
      snappedDurationDelta(delta.dy, pixelsPerMinute),
    ),
  };
}

typedef _Span = ({int start, int duration});

DateTime _at(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, 0, minutes);

({DateTime start, int durationMinutes}) _move(
  _Span span,
  DateTime day,
  int shift,
) {
  final latest = math.max(0, Duration.minutesPerDay - span.duration);
  final start = math.min(latest, math.max(0, span.start + shift));
  return (start: _at(day, start), durationMinutes: span.duration);
}

({DateTime start, int durationMinutes}) _resizeBottom(
  _Span span,
  DateTime day,
  int shift,
) {
  final longest = math.max(
    minTaskDurationMinutes,
    Duration.minutesPerDay - span.start,
  );
  final duration = math.min(
    longest,
    math.max(minTaskDurationMinutes, span.duration + shift),
  );
  return (start: _at(day, span.start), durationMinutes: duration);
}

({DateTime start, int durationMinutes}) _resizeTop(
  _Span span,
  DateTime day,
  int shift,
) {
  final end = span.start + span.duration;
  final latest = math.max(0, end - minTaskDurationMinutes);
  final start = math.min(latest, math.max(0, span.start + shift));
  return (start: _at(day, start), durationMinutes: end - start);
}

/// The day column [dx] points at, counting from [origin]'s column.
DateTime _targetDay(
  DateTime origin,
  double dx,
  double dayWidth,
  List<DateTime> days,
) {
  final from = days.indexWhere(
    (d) =>
        d.year == origin.year && d.month == origin.month && d.day == origin.day,
  );
  if (from < 0 || dayWidth <= 0) return origin;
  return days[(from + (dx / dayWidth).round()).clamp(0, days.length - 1)];
}
