import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/glass_pill_surface.dart';
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
    this.labelOffset = 0,
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

  /// How far this event's title sits BELOW its own rail's top — zero when
  /// nothing collides (so the title stays level with the rail's icon),
  /// positive when a neighbouring block's label pushed it down. Mirrors
  /// `TaskCapsuleBlock.labelOffset`'s contract exactly, and is fed from
  /// the SAME `computeLabelTops` collision sweep tasks already use.
  ///
  /// Real bug, reported directly from a screenshot showing an imported
  /// event's title printed on top of a native task's ("Walky sync",
  /// "hhnch"): event slots used to be excluded from that sweep outright,
  /// on the reasoning that an event "has no label-push mechanism at all"
  /// — which was circular, since this parameter is that mechanism. A task
  /// and an event sharing a time window each got their own LANE for the
  /// rail (the lane pipeline was always generic over `ScheduledBlock`, and
  /// measured correct), but only the task's TITLE was ever nudged clear,
  /// so the two titles landed at the identical x and y.
  final double labelOffset;

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
              // `height`, not `badgeSize` — corrected directly: "imported
              // tasks on timeline (spatial view) should also adopt length
              // of pill to their duration, at the moment they are the same
              // minimal size." The duration-derived height was already
              // being computed for the outer box (see `height` above) but
              // the visible rail was pinned to a flat `badgeSize`, so a
              // 15-minute and a 4-hour event drew identical 24px pills
              // while every native task beside them scaled properly.
              // Matches `TaskCapsuleBlock`'s own rail exactly, which is
              // `width: badgeSize, height: pillHeight`.
              child: DashedPillRail(
                theme: theme,
                width: badgeSize,
                height: height,
              ),
            ),
          ),
          Positioned(
            // Pushed down only when a neighbouring label would collide —
            // see [labelOffset]. The enclosing Stack is `Clip.none`, so a
            // label nudged past this box's own (duration-derived) height
            // still renders in full, exactly as a task's does.
            top: labelOffset,
            left: textColumnLeft,
            right: textColumnRight,
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              // Centred against the BADGE's own height, not pinned to its
              // top — corrected directly from a screenshot annotated "text
              // too high, should be middle", comparing this view against
              // Zone view (whose fixed-height rows centre their content by
              // default). Measured before fixing: the title's centre sat a
              // consistent 4px above the icon's at every duration, because
              // a 16px title top-aligned inside the 24px badge span.
              //
              // `minHeight`, not a fixed height: a title that ever wraps
              // taller than the badge grows instead of being clipped — the
              // same reasoning `TaskCapsuleBlock`'s own equivalent
              // centring uses (see `textHeaderHeight` there).
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: badgeSize),
                // No `widthFactor` — this column must keep filling its
                // full width (`textColumnLeft`..`textColumnRight`) so the
                // title truncates at the same x every native task's does;
                // only the VERTICAL centring is wanted here.
                child: Center(
                  heightFactor: 1,
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
            ),
          ),
        ],
      ),
    );
  }
}

/// An imported calendar event's badge — same size/corner radius as a real
/// task's category-colored rail, but a dashed outline instead of a solid
/// category fill, plus a small calendar glyph in
/// [AmbleTheme.colorTextSecondary] (subtle, matching every other "this is
/// not a real Amble object" visual cue already established for external
/// events).
///
/// Public, and shared: Zone view's own imported-event rows
/// (`_ZoneExternalEventRow`) render this exact badge too, requested
/// directly — "on the zone view, the imported items from calendar should
/// be rendered in the same way as other events, other tasks, so with the
/// circle, and icon inside the circle is dotted, same as in the timeline
/// view." Zone view previously showed a bare muted title with no badge at
/// all, which is what made the two views read as different kinds of
/// object.
/// **No longer dashed** (the name is kept so the many existing call sites
/// and tests that reference it keep working): the outline was removed
/// entirely per a direct instruction — "no dotted line, no line at all" —
/// and replaced by a flat gray fill via the shared [GlassPillSurface].
/// That is deliberately the FLAT material, not the frosted one the
/// quick-create draft placeholder uses: a draft is airborne and
/// provisional, while an imported event is a real thing on the calendar.
class DashedPillRail extends StatelessWidget {
  const DashedPillRail({
    super.key,
    required this.theme,
    required this.width,
    required this.height,
  });

  final AmbleTheme theme;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    // A FLAT gray fill, no outline — requested directly: "the imported
    // should have fill also but just gray not the same glassy / and no
    // dotted line, no line at all." This was a dashed outline over
    // nothing; it is now the shared `GlassPillSurface` in its flat
    // material, which is deliberately NOT the frosted one the quick-create
    // draft uses (that one is airborne and provisional; an imported event
    // is a real thing on the calendar, just not an Amble task).
    //
    // Still corners at `theme.radiusPill` — the active "Pill shape" rung —
    // via that widget, so this rail keeps echoing a real task's own rail
    // exactly as the dashed version did.
    return GlassPillSurface(
      theme: theme,
      material: GlassPillMaterial.flat,
      width: width,
      height: height,
      child: SizedBox(
        width: width,
        height: height,
        // The glyph sits in the rail's own TOP square, not the middle of
        // however tall the rail runs — matching `TaskCapsuleBlock`'s own
        // `alignment: Alignment.topCenter`. Once the rail started scaling
        // with duration, a centred glyph would drift to the middle of a
        // long event and lose its alignment with the title beside it
        // (which stays level with the icon, by design — see
        // `external_event_title_alignment_test.dart`).
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: theme.sizeTaskBadge,
            child: Center(
              child: Icon(
                Icons.calendar_today_outlined,
                size: theme.sizeTaskBadge * 0.55,
                color: theme.colorTextSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
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
