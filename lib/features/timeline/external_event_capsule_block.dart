import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/external_calendar_event.dart';
import 'duration_label.dart';
import 'task_capsule_block.dart'
    show taskDurationColumnWidth, taskTimeColumnWidth;

/// **Reversed 2026-09-06** (confirmed directly — "the importend tasks
/// sohuld also be same format as amble tasks... pill in zones and text
/// outside same positioned x and same format on task view and list view"):
/// external/imported calendar events now render as a REAL capsule pill,
/// visually matching [TaskCapsuleBlock]'s exact geometry and
/// [TaskCapsuleTextRow]'s exact text format/position, superseding
/// CONSTITUTION.md's original "never a TaskCapsuleBlock" lock for the
/// VISUAL shape specifically. Confirmed via AskUserQuestion this is
/// look-only: no move, no resize, no completion, no drag — the one
/// interaction stays the existing tap-for-info sheet
/// ([showExternalCalendarEventInfo]).
///
/// Deliberately a SEPARATE widget from [TaskCapsuleBlock], not that widget
/// reused with a fake/adapter [ExternalCalendarEvent]-as-`Task` wrapper —
/// `TaskCapsuleBlock` is tightly coupled to real `Task` fields
/// (status/category/completion/drag/resize) that have no meaning for a
/// read-only foreign event, and building a wrapper risks an accidental
/// write path into a repository this event was never meant to touch. This
/// widget only mirrors the PILL's geometry (badge size, duration-based
/// height, rounded rail) and the TEXT row's format — it shares no state or
/// gesture logic with the real capsule at all.
///
/// **2026-09-07**: now participates in overlap-cluster detection and lane
/// sharing exactly like a real task — see `timeline_screen.dart`'s own
/// doc comment on event/task stacking parity. [left] stays fixed at the
/// day column's origin (never lane-shifted) while [columnOffset] carries
/// the rail's own lane x, mirroring `_DraggableTaskBlock`'s split between
/// its own `left`/`columnOffset` exactly — see [left]'s own doc comment.
class ExternalEventCapsuleBlock extends StatelessWidget {
  const ExternalEventCapsuleBlock({
    super.key,
    required this.theme,
    required this.event,
    required this.rangeStart,
    required this.pixelsPerMinute,
    required this.left,
    required this.columnOffset,
    required this.textColumnLeft,
    required this.textColumnRight,
    this.collapsedTop,
    this.collapsedHeight,
    this.compactText = false,
    this.durationVisible = true,
    this.onTap,
  });

  final AmbleTheme theme;
  final ExternalCalendarEvent event;

  /// Same coordinate space every other time-positioned Timeline element
  /// shares — see `ZoneBackgroundBlock`'s own doc comment.
  final DateTime rangeStart;
  final double pixelsPerMinute;

  /// The outer box's own left edge — the day column's fixed origin
  /// (`hourGutterWidth`), matching `_DraggableTaskBlock.left` exactly.
  /// **Never lane-shifted**: [columnOffset] carries the lane offset for
  /// the rail alone, so the text column (relative to this same fixed
  /// origin via [textColumnLeft]) never moves when an event lands in a
  /// deeper lane. Real bug, reported directly from a screenshot ("text
  /// not aligned wit hnative tasks") — an earlier version baked
  /// `pillBoxLeftForColumn` straight into this field, so a laned event's
  /// entire box (rail AND text) shifted right by a full pill width,
  /// exactly the way `_DraggableTaskBlock` deliberately avoids by keeping
  /// its own `left` fixed and shifting only its rail's `columnOffset`.
  final double left;

  /// The rail's own lane x, relative to [left] — the SAME
  /// `pillBoxLeftForColumn(column: slot.column, ...)` value
  /// `_DraggableTaskBlock`'s own rail uses. Ignored when [collapsedTop] is
  /// set (List mode has no lane concept horizontally either).
  final double columnOffset;

  /// Where the shared text column starts/how far it stops short of the
  /// right edge — the SAME values `_DraggableTaskBlock`'s own
  /// `textColumnLeft`/`textColumnRight` resolve to, so an event's title
  /// starts at exactly the same x as every task's, regardless of lane.
  final double textColumnLeft;
  final double textColumnRight;

  /// List (collapsed) mode's own stacking-cursor position — see
  /// `ExternalEventBlock.collapsedTop`'s own doc comment (unchanged
  /// contract, carried over to this widget).
  final double? collapsedTop;
  final double? collapsedHeight;

  /// True in List (collapsed) mode — same "one line, time then title"
  /// signal `TaskCapsuleTextRow.compactInlineLayout` uses.
  final bool compactText;

  /// Mirrors `TaskCapsuleTextRow.durationVisible`'s exact contract —
  /// requested directly ("no time start end for importend tasks, like
  /// native amble tasks"): Task view's own dev-config toggle
  /// (`DevTimelineTaskDurationVisible`) decides whether the time column
  /// shows at all here too, same as a real task. Defaults true so a
  /// caller that doesn't wire it up renders unchanged from before this
  /// param existed. [compactText] (List mode) still forces the time back
  /// on regardless — see `_ExternalEventTextRow.alwaysShowTime`.
  final bool durationVisible;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final top =
        collapsedTop ??
        event.start.difference(rangeStart).inMinutes * pixelsPerMinute;
    final durationMinutes = event.end.difference(event.start).inMinutes;
    final badgeSize = theme.sizeTaskBadge;
    final rawPillHeight = math.max(
      durationMinutes * pixelsPerMinute,
      badgeSize,
    );
    final height = collapsedHeight ?? rawPillHeight;

    // Mirrors `_DraggableTaskBlock._buildSplit`'s own structure exactly:
    // ONE outer box at [left] (the day column's own left edge, i.e. the
    // hour gutter's width), with the rail and the text column positioned
    // RELATIVE to it. Both of this widget's children therefore share the
    // same origin a real task's do.
    //
    // Real bug, reported directly from a screenshot ("importent tasks are
    // not lined up with native tasks"): the outer box used to span the
    // full row (`left: 0, right: 0`) while the rail was placed at an
    // absolute [left] and the text at a bare `textColumnLeft`. The rail
    // landed correctly by coincidence, but the text lost the gutter
    // offset entirely and sat `left` px (56) too far left of every native
    // title. The earlier cross-widget alignment test missed it because it
    // passed the same `textColumnLeft` to both widgets by hand — proving
    // only that the widget honours its input, never what the caller
    // actually supplies.
    return Positioned(
      top: top,
      left: left,
      right: 0,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: collapsedTop != null ? 0 : columnOffset,
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: _DashedPillRail(
                theme: theme,
                width: badgeSize,
                height: badgeSize,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: textColumnLeft,
            right: textColumnRight,
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: _ExternalEventTextRow(
                theme: theme,
                event: event,
                timeColumnWidth: taskTimeColumnWidth(theme),
                durationColumnWidth: taskDurationColumnWidth(theme),
                compactInlineLayout: compactText,
                durationVisible: durationVisible,
                alwaysShowTime: compactText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pill rail's own visual — same badge size/corner radius as a real
/// task's category-colored rail, but a dashed outline over a faint fill
/// instead of a solid category color, plus a small calendar glyph in
/// [AmbleTheme.colorTextSecondary] (subtle, matching every other "this is
/// not a real Amble object" visual cue already established for external
/// events — see `_ZoneExternalEventRow`'s own muted-title precedent).
class _DashedPillRail extends StatelessWidget {
  const _DashedPillRail({
    required this.theme,
    required this.width,
    required this.height,
  });

  final AmbleTheme theme;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRoundedRectPainter(
        color: theme.colorTextSecondary,
        radius: theme.radiusSm,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Icon(
            Icons.calendar_today_outlined,
            size: theme.sizeTaskBadge * 0.55,
            color: theme.colorTextSecondary,
          ),
        ),
      ),
    );
  }
}

/// Draws a dashed rounded-rectangle outline — Flutter has no built-in
/// dashed border, and no dashed-border package is in this project's
/// dependencies (adding one for a single visual cue is out of scope per
/// CLAUDE.md's "no new dependency without flagging it first" rule), so
/// this is a small hand-rolled `CustomPainter` instead.
class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dashLength = 3.0;
  static const _gapLength = 2.0;
  static const _strokeWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + _dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// The text half of [ExternalEventCapsuleBlock] — mirrors
/// `TaskCapsuleTextRow`'s exact two layouts (fixed columns for Task view,
/// one inline run for List view, per `compactInlineLayout`), but reads
/// straight off [ExternalCalendarEvent] rather than a `Task`: no status,
/// no completion, no checkbox — this is read-only. Title stays in
/// [AmbleTheme.colorTextSecondary], never the bold primary color a real
/// task's title gets, matching `_ZoneExternalEventRow`'s own "must never
/// look like an editable Amble object" distinction.
class _ExternalEventTextRow extends StatelessWidget {
  const _ExternalEventTextRow({
    required this.theme,
    required this.event,
    required this.timeColumnWidth,
    required this.durationColumnWidth,
    required this.compactInlineLayout,
    required this.durationVisible,
    required this.alwaysShowTime,
  });

  final AmbleTheme theme;
  final ExternalCalendarEvent event;
  final double timeColumnWidth;
  final double durationColumnWidth;
  final bool compactInlineLayout;

  /// Mirrors `TaskCapsuleTextRow.durationVisible`'s exact contract — off
  /// hides the ENTIRE time column (not just a duration suffix), matching
  /// a real task's own Task-view behavior when the dev-config
  /// `DevTimelineTaskDurationVisible` toggle is off. Requested directly:
  /// "no time start end for importend tasks, like native amble tasks."
  final bool durationVisible;

  /// **Reversed — List mode now means the OPPOSITE of "always show."**
  /// `true` here still means List mode (mirrors
  /// `TaskCapsuleTextRow.alwaysShowTime`'s "is this List mode" contract
  /// exactly, and this widget is only ever constructed with
  /// `alwaysShowTime: compactText`), but requested directly: "no time no
  /// duration would apply to imported tasks" — List view never shows an
  /// imported event's time or duration at all now, regardless of either
  /// dev toggle. An event's "duration" is only ever a computed span
  /// (`event.end - event.start`), never a concept the user actually set,
  /// so there was nothing meaningful for the duration toggle to show here
  /// in the first place. Task view (`alwaysShowTime: false`) is unchanged
  /// — [durationVisible] alone still gates the whole time+duration line
  /// there, same as before.
  final bool alwaysShowTime;

  @override
  Widget build(BuildContext context) {
    final startTime = TimeOfDay.fromDateTime(event.start);
    final endTime = TimeOfDay.fromDateTime(event.end);
    final durationMinutes = event.end.difference(event.start).inMinutes;
    final textStyle = theme.textTaskTitle.copyWith(
      color: theme.colorTextSecondary,
    );
    final titleSpan = TextSpan(text: event.title, style: textStyle);
    final showTime = !alwaysShowTime && durationVisible;

    if (compactInlineLayout) {
      final timeLabel =
          '${startTime.format(context)} - ${endTime.format(context)}';
      return Text.rich(
        TextSpan(
          children: [
            if (showTime) TextSpan(text: '$timeLabel  ', style: textStyle),
            titleSpan,
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTime) ...[
          SizedBox(
            width: timeColumnWidth,
            child: Text(
              '${startTime.format(context)}-${endTime.format(context)}',
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: durationColumnWidth,
            child: Text(
              formatDurationLabel(durationMinutes),
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        Expanded(
          child: Text.rich(
            titleSpan,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
