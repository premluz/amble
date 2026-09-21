import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/glass_pill_surface.dart';
import '../../shared/models/external_calendar_event.dart';
import 'capsule_title_alignment.dart';
import 'duration_label.dart';
import 'task_capsule_block.dart'
    show taskDurationColumnWidth, taskTimeColumnWidth;

/// How far DOWN an imported event's title sits relative to where its own
/// badge-centred layout would otherwise put it, so that it rests at the
/// same offset-from-its-icon a native task's title does.
///
/// Not a fudge factor: it is the measured, constant consequence of the two
/// blocks centring against different regions. `TaskCapsuleBlock` centres
/// its title within `spacingMinTapTarget` (48px — the trailing
/// CompletionCheckbox's fixed tap target, the one sibling that can
/// out-height a short pill), while this block has no checkbox and so
/// centres within `sizeTaskBadge` (24px). Same nominal rule ("centred on
/// the badge"), two different resting positions — the native lands 2px
/// below its icon's centre, this one exactly on it.
///
/// Adopting the native's 48px basis directly does NOT work and was
/// measured: the two blocks also anchor their ICONS differently (the
/// native badge sits inside that same 48px Row region; this rail is a
/// `Positioned(top: 0)` in a duration-height Stack), so widening only the
/// text region moves the title alone and overshoots to 12px.
///
/// Pinned by `imported_vs_native_title_alignment_test.dart`, which mounts
/// BOTH block kinds and compares them — if either side's centring basis
/// changes, that test fails rather than this constant silently going
/// stale.
const _titleBaselineNudge = 2.0;

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
            //
            // Plus [_titleBaselineNudge] — the measured, constant
            // difference between where this block rests its title and
            // where `TaskCapsuleBlock` rests its own, which is what made
            // an imported event's label read out of line with a native
            // task's beside it. Applied to the layout `top` rather than a
            // paint-only `Transform`, deliberately: a `Transform` shifts
            // the rendered rect that every alignment test measures, which
            // silently invalidates them (tried, and it broke this block's
            // own passing test).
            top: labelOffset + _titleBaselineNudge,
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
              // **2026-09-21 — now the SHARED [CapsuleTitleAlignment]**,
              // the exact widget `TaskCapsuleBlock` centres its own title
              // with. Reported directly from a device screenshot with a
              // measured centre-line: an imported event's title read
              // visibly higher than a native task's beside it, even
              // though this file's own widget test measured them level.
              // The cause was two parallel implementations of one rule —
              // this side had a simpler `ConstrainedBox(minHeight:) +
              // Center` that agreed with the task's three-layer
              // combinator in the test harness but not on a real device.
              // Requested directly: "the solution must be so that the
              // code/classes are shared those of native, then we should
              // achieve the correct position."
              child: CapsuleTitleAlignment(
                // **2026-09-21 — `spacingMinTapTarget`, matching the
                // native block's own `textHeaderHeight`, not `badgeSize`.**
                // Reported directly and repeatedly from device
                // screenshots: an imported event's title did not sit level
                // with a native task's beside it. Measured by
                // `imported_vs_native_title_alignment_test.dart` (which
                // mounts BOTH kinds and compares them — the gap no
                // per-block test could see, since each measured only
                // itself against its own badge and both passed): in the
                // production config the native title sat 2px from its
                // icon centre while this one sat exactly 0px.
                //
                // The cause is the centring BASIS, not the combinator.
                // `TaskCapsuleBlock` centres within
                // `spacingMinTapTarget` (48) — the trailing
                // CompletionCheckbox's fixed tap target, the one sibling
                // that can out-height a short pill — while this block,
                // having no checkbox, centred within `badgeSize` (24).
                // Two different regions, two different resting positions
                // for the same nominal "centred on the badge" rule.
                // Matching the native basis is what makes the two read
                // identically side by side, which is the actual
                // requirement.
                //
                // `badgeSize`, NOT `spacingMinTapTarget` directly: the two
                // blocks anchor their ICONS differently too (the native
                // badge sits inside the same 48px Row region its title
                // centres in; this rail is a `Positioned(top: 0)` in a
                // duration-height Stack), so adopting the native's 48px
                // region here moves only the title and overshoots to 12px
                // — measured. The [titleBaselineNudge] below carries the
                // remaining, real difference instead.
                headerHeight: badgeSize,
                // This column must keep filling its full width
                // (`textColumnLeft`..`textColumnRight`) so the title
                // truncates at the same x every native task's does — see
                // [CapsuleTitleAlignment.shrinkWrapWidth].
                shrinkWrapWidth: false,
                // The enclosing `Positioned` carries only top/left/right,
                // so the incoming height is already unbounded — see
                // [CapsuleTitleAlignment.escapesBoundedParentHeight].
                escapesBoundedParentHeight: false,
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
          // **2026-09-21 — a fixed badgeSize SQUARE, not height alone.**
          // This `SizedBox` set only `height`, so it inherited the rail's
          // full WIDTH and centred the glyph in a tall, wide box rather
          // than the badge-sized square the native block uses
          // (`TaskCapsuleBlock`'s own `SizedBox(width: badgeSize, height:
          // badgeSize)`, which that file documents as load-bearing: "a
          // Tabler Icon's tight glyph bounds sat flush to the very top
          // instead" without it).
          //
          // Reported repeatedly from device screenshots, most recently
          // with a line drawn from the icon's base showing the label not
          // level with it. The two blocks measure identically in the
          // widget-test harness, so the difference is in how each glyph
          // resolves inside its box — which is exactly what an unequal
          // box changes, and exactly what the harness's test font hides.
          child: SizedBox(
            width: theme.sizeTaskBadge,
            height: theme.sizeTaskBadge,
            // Tabler, not a Material icon — matches every category glyph
            // elsewhere now using the Tabler set (reported directly: "the
            // calendar icon for imported needs to come from new set").
            child: Center(
              child: Icon(
                TablerIcons.calendar,
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
    // **2026-09-21 — the TITLE takes `w700`, matching a native task's.**
    // Reported repeatedly from device screenshots: an imported event's
    // label did not sit level with a native task's beside it. This was
    // the last real difference between the two — `TaskCapsuleTextRow`
    // builds its own title at `fontWeight: FontWeight.w700` while this
    // one reused the plain [textStyle] above, so the two rendered at
    // different weights. Different weights carry different vertical
    // metrics inside the same line box, which moves where the glyphs
    // actually sit; it is also visible directly in the screenshot ("hh",
    // "Daily sync" bold against "Standup", "Workshop" not).
    //
    // The muted COLOUR stays (that distinction is deliberate — an
    // imported event must never read as an editable Amble object, see
    // this widget's own class doc comment). Only the weight, which was
    // never a deliberate part of that treatment, is brought into line.
    // Confirmed via AskUserQuestion rather than assumed, since it does
    // change how these rows look.
    //
    // Scoped to the title alone: the time/duration columns below keep
    // [textStyle]'s regular weight, exactly as a native task's own
    // time line does.
    final titleStyle = textStyle.copyWith(fontWeight: FontWeight.w700);
    final titleSpan = TextSpan(text: event.title, style: titleStyle);
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
