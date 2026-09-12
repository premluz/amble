import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';

/// One left-gutter time label — a clean clock-hour tick within the
/// visible range.
class TaskBoundary {
  const TaskBoundary(this.time);

  final DateTime time;
}

/// Every clock-hour tick from the first whole hour at or after
/// [rangeStart] through [rangeEnd], spaced [intervalHours] apart.
///
/// Reverted from the task-boundary-derived labels this replaced (see
/// docs/DECISIONS.md) back to a fixed grid — requested directly. Ticks
/// land on round clock hours (11:00, 12:00, ...), not offset from
/// [rangeStart] itself, since [rangeStart] is a dynamic, per-day computed
/// value (see `_DayTimelineState._visibleRange`) that rarely falls on a
/// whole hour — confirmed via AskUserQuestion rather than assumed.
/// [intervalHours] defaults to 1 and is the seam for the "every 2 hours"
/// variant mentioned as a near-term follow-up: the grid is entirely
/// driven by this one parameter, no other change needed to widen it.
List<TaskBoundary> hourlyGridTimes(
  DateTime rangeStart,
  DateTime rangeEnd, {
  int intervalHours = 1,
}) {
  var tick = DateTime(
    rangeStart.year,
    rangeStart.month,
    rangeStart.day,
    rangeStart.hour,
  );
  if (tick.isBefore(rangeStart)) {
    tick = tick.add(const Duration(hours: 1));
  }

  final ticks = <TaskBoundary>[];
  while (!tick.isAfter(rangeEnd)) {
    ticks.add(TaskBoundary(tick));
    tick = tick.add(Duration(hours: intervalHours));
  }
  return ticks;
}

/// Left-edge time labels for the day view: a fixed hourly grid within the
/// visible (dynamic, per-day) range — see [hourlyGridTimes].
class TaskBoundaryMarkers extends StatelessWidget {
  const TaskBoundaryMarkers({
    super.key,
    required this.rangeStart,
    required this.rangeEnd,
    required this.pixelsPerMinute,
    this.leftInset = 0,
    this.columnWidth,
    this.intervalHours = 1,
    this.hideLabelNear,
  });

  /// The day view's top edge — grid ticks are positioned relative to
  /// this and start at the first whole hour at or after it.
  final DateTime rangeStart;

  /// The day view's bottom edge — the last tick at or before this.
  final DateTime rangeEnd;
  final double pixelsPerMinute;

  /// Indents the hour labels from this widget's own left edge. The
  /// Timeline's scroll view no longer applies horizontal screen padding
  /// (so the tap-to-create ripple can reach the screen edges), so the
  /// labels carry that inset themselves rather than sitting flush against
  /// the physical edge.
  final double leftInset;

  /// The gutter's own width, from [leftInset] to where task pills start —
  /// when set, each label right-aligns within `[leftInset, leftInset +
  /// columnWidth]` instead of left-aligning at [leftInset] and growing
  /// rightward. Requested directly: "on task view time on left too big
  /// padding[;] make same as on right hand side" — the gutter is sized for
  /// the WIDEST label ("12:00 PM"), so a shorter one ("9 AM") left-aligned
  /// at the screen edge left a ragged, oversized gap before the first
  /// pill; right-aligning instead puts every label flush against the pill
  /// column regardless of its own text width, matching the tight inset
  /// already used on the timeline's right edge. Null keeps the original
  /// left-aligned behavior (e.g. for a caller with no fixed column to
  /// align within).
  final double? columnWidth;

  /// Spacing between ticks, in hours. Default 1 (every hour); the
  /// configurable-interval seam mentioned for a later pass.
  final int intervalHours;

  /// A time whose nearest grid label should be omitted, so
  /// [CurrentTimeIndicator]'s bold "now" label doesn't render on top of a
  /// muted grid label in the same gutter. Null keeps every label.
  final DateTime? hideLabelNear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final ticks = hourlyGridTimes(
      rangeStart,
      rangeEnd,
      intervalHours: intervalHours,
    );

    return Stack(
      // The 00:00 label at the range's very first tick is translated UP
      // by half its own line height (see the FractionalTranslation
      // below), so it extends above THIS Stack's own top edge — Clip.none
      // is what stops that half-label from being clipped to nothing by
      // the Stack's default hardEdge behaviour. The outer padding
      // reserved for it (`timeline_screen.dart`'s own `spacingLg` around
      // this widget) only makes room in the SCROLL viewport; it can't
      // undo a hard clip happening one layer further in. Reported
      // directly, a second time, after the first fix (that outer
      // padding) turned out not to be the actual clip boundary: "00:00
      // hours on top and bottom are cut off."
      clipBehavior: Clip.none,
      children: [
        for (final tick in ticks)
          if (!_isHiddenByNowLabel(tick.time, theme))
            Positioned(
              top: _minutesSinceStart(tick.time) * pixelsPerMinute,
              left: leftInset,
              width: columnWidth,
              child: FractionalTranslation(
                translation: const Offset(0, -0.5),
                child: Align(
                  // Right-aligned within the reserved column when
                  // [columnWidth] is set — see that field's own doc
                  // comment. `Alignment.centerLeft` (the default a bare
                  // Text would occupy) is what produced the original
                  // left-anchored, ragged-gap layout.
                  alignment: columnWidth == null
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Text(
                    TimeOfDay.fromDateTime(tick.time).format(context),
                    style: theme.textCaption.copyWith(
                      color: theme.colorTextSecondary,
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  double _minutesSinceStart(DateTime time) =>
      time.difference(rangeStart).inMinutes.toDouble();

  /// Whether [time]'s label sits close enough to the current-time label to
  /// visually collide with it. The threshold is the label's own rendered
  /// line height, derived from the type tokens, so this scales with the
  /// type scale instead of assuming a fixed pixel gap. Mirrors the
  /// collision rule the original fixed hourly grid used.
  bool _isHiddenByNowLabel(DateTime time, AmbleTheme theme) {
    final now = hideLabelNear;
    if (now == null) return false;
    final caption = theme.textCaption;
    final lineHeight = (caption.fontSize ?? 0) * (caption.height ?? 1);
    final minutesApart = time.difference(now).inMinutes.abs();
    return minutesApart * pixelsPerMinute < lineHeight;
  }
}
