import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/zone.dart';

/// How far a rendered [ZoneBackgroundBlock] extends to the LEFT of the
/// pill column it sits behind, creating the appearance of padding around
/// whatever tasks fall within the zone's time range — WITHOUT the block
/// being a real padding/layout container: tasks are positioned entirely
/// independently (see `timeline_screen.dart`'s own task-layout code) and
/// know nothing about zones. Purely a visual inset on the block itself.
///
/// Matches `SpacingPrimitives.space2` (4.0). Named here as its own
/// constant (not read off `theme` at each use site) so a future change to
/// a general spacing token can't silently move every zone block on the
/// Timeline.
///
/// Reduced from 12 to 4 — requested directly: "reduce padding so that it's
/// minimal 4px so that a task that starts at the same time as a zone is
/// actually not too much lower, otherwise the perception will be that it's
/// starting later." This value is ALSO the top inset a task starting
/// exactly at its zone's start gets (`_zoneTaskTopInset` in
/// `timeline_screen.dart`), and on the Task view's 1.5px-per-minute scale
/// a 12px inset read as roughly eight minutes late — a real misreading of
/// the schedule, not just a spacing preference. At 4px it is under three
/// minutes.
///
/// Deliberately HORIZONTAL-only for the BAND itself. It used to apply on
/// the vertical axis too — the block started 12px above its own start time
/// — which is what made a zone read as ending well before its real end
/// time. Reported directly: "zone is 4:00-5:00 but it looks like it ends
/// before 5:00 ... we need to make that cusp precise but retain gap
/// between zones". A block's top edge now lands exactly on its own start
/// time; only the TASK is inset.
const zoneBackgroundOffset = 4.0;

/// Visual gap kept between two zone blocks whose times are exactly
/// back-to-back (one's `endMinutes` equals the next's `startMinutes`) —
/// requested directly: "there should always be a gap between zones even if
/// one starts the time the other ends", and reaffirmed alongside the
/// cusp-precision fix ("we need to make that cusp precise but retain gap
/// between zones").
///
/// Taken entirely off a block's BOTTOM edge, never its top: every block's
/// top lands exactly on its own start time, so the earlier zone yields the
/// whole gap and the later one still starts precisely on the shared
/// boundary.
///
/// Purely cosmetic, matching [zoneBackgroundOffset]'s own "display-only"
/// scope — zones are still allowed to be SAVED back-to-back
/// (`zonesOverlap`'s half-open-interval rule is unchanged); this only
/// stops their rendered blocks from visually touching. Matches
/// `theme.spacingXs` (`SpacingPrimitives.space2`, 4.0).
const zoneBackgroundGap = 4.0;

/// The rendering-only background block for one [Zone] on the Spatial Task
/// View (Timeline) — per CONSTITUTION.md's Zone section ("Zone is metadata
/// on a Task, not a container that owns it") and the per-view-job design
/// rule, this widget is PURELY decorative. It does not reposition, resize,
/// or otherwise affect any [Task]'s rendering — the Spatial Zone View
/// (where a Zone genuinely acts as a layout container) is separate,
/// out-of-scope future work.
///
/// Positioned using the exact same time-to-pixel math the Timeline already
/// uses for tasks ([pixelsPerMinute] against [rangeStart]), so it is
/// genuinely aligned to the same time scale a task capsule is — just
/// nudged by [zoneBackgroundOffset] on both axes to read as "padding
/// around" rather than "starting exactly at."
class ZoneBackgroundBlock extends StatelessWidget {
  const ZoneBackgroundBlock({
    super.key,
    required this.theme,
    required this.zone,
    required this.day,
    required this.rangeStart,
    required this.pixelsPerMinute,
    required this.left,
    required this.width,
    this.collapsedTop,
    this.collapsedHeight,
  });

  final AmbleTheme theme;
  final Zone zone;

  /// The calendar day being viewed — [Zone.startMinutes]/[endMinutes] are
  /// time-of-day only, with no date of their own, so this resolves them
  /// onto a real [DateTime] comparable to [rangeStart].
  final DateTime day;

  /// The Timeline's own visible-range start — same value every other
  /// time-positioned Timeline element (`TaskBoundaryMarkers`,
  /// `FreeWindowBlock`, task capsules) is measured against, so this block
  /// shares their exact coordinate space rather than a parallel one.
  final DateTime rangeStart;
  final double pixelsPerMinute;

  /// Horizontal extent — the caller passes the same left/width every other
  /// full-width Timeline background element uses (see `FreeWindowBlock`'s
  /// own `left`), so a zone block spans the same horizontal band.
  final double left;
  final double width;

  /// List (collapsed) mode override — both null or both set, same contract
  /// as `ExternalEventBlock.collapsedTop`/`collapsedHeight`. List mode's
  /// task tops come from a gap-collapsing stack cursor, not real elapsed
  /// time, so this block's own `zoneStart`/`rangeStart`/`pixelsPerMinute`
  /// math has no relationship to where its member tasks actually render
  /// there — the caller (`timeline_screen.dart`'s zone-band geometry,
  /// derived from wrapping the collapsed tops of the zone's own member
  /// tasks) supplies the real answer instead. Null in Task view, where the
  /// existing time-to-pixel math is already correct.
  final double? collapsedTop;
  final double? collapsedHeight;

  @override
  Widget build(BuildContext context) {
    final zoneStart = DateTime(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: zone.startMinutes));
    final zoneEnd = DateTime(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: zone.endMinutes));

    final strictTop =
        collapsedTop ??
        zoneStart.difference(rangeStart).inMinutes * pixelsPerMinute;
    final strictHeight =
        collapsedHeight ??
        zoneEnd.difference(zoneStart).inMinutes * pixelsPerMinute;

    return Positioned(
      // VERTICALLY: the block's top edge lands EXACTLY on its own start
      // time — confirmed directly over the alternative of extending
      // slightly above it. A 4:00-5:00 zone now visibly starts at 4:00 and
      // ends at 5:00 minus the inter-zone gap, rather than the previous
      // 12px-early / 16px-short arithmetic that made it read as ending
      // well before its real end. The whole gap between two back-to-back
      // zones is taken off this block's BOTTOM (zoneBackgroundGap), so the
      // next zone's own top edge is still free to land exactly on the
      // shared boundary. Neither block needs to know the other exists.
      //
      // A task starting at exactly this zone's start time therefore sits
      // flush with the band's top edge; the small gap it needs comes from
      // insetting the TASK (see `_zoneTaskTopInset` in
      // `timeline_screen.dart`), not from moving the band off its time.
      //
      // HORIZONTALLY: still extended left by zoneBackgroundOffset, so the
      // band reads as padding around the pill column. Only the vertical
      // axis changed here.
      top: strictTop,
      left: left - zoneBackgroundOffset,
      width: width - zoneBackgroundGap,
      // The inter-zone gap only matters for the real-time cusp-precision
      // problem this constant was introduced for — two REAL back-to-back
      // zones whose blocks would otherwise visually touch. In List mode
      // (`collapsedHeight` set), the caller already derives `strictHeight`
      // by wrapping this zone's own member tasks' collapsed tops with its
      // own padding (see `timeline_screen.dart`'s zone-band geometry) —
      // rows there never touch by construction, so subtracting the gap
      // again here would just shave a few extra, unaccounted-for pixels
      // off a value that's already correct.
      height: collapsedHeight ?? strictHeight - zoneBackgroundGap,
      child: IgnorePointer(
        // Purely decorative — never intercepts a tap meant for a task
        // pill, the placement line, or anything else already on the
        // Timeline. Matches how `FreeWindowBlock` stays tappable (it
        // isn't `IgnorePointer`) for a different, deliberate reason (it
        // opens create-task); a Zone block has no interaction of its own
        // this session, per the explicit "display-only" scope.
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorZoneBackground,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
        ),
      ),
    );
  }
}

/// The zone's name, rotated 90° and pinned to the RIGHT edge of the day
/// column, spanning the zone's own vertical extent.
///
/// Requested directly ("can't see vertical zone name on task view"), and
/// styled to match the hour labels on the opposite edge — `textCaption` in
/// `colorTextSecondary` — so the two read as the same class of ambient
/// annotation framing the day rather than as content.
///
/// A separate widget from [ZoneBackgroundBlock] rather than a child of it:
/// that block now hugs the pill column (it is deliberately narrow), while
/// this label belongs at the far right of the screen. Both are positioned
/// from the same time math, so they still describe the same band.
///
/// Purely decorative, like the block itself — `IgnorePointer`ed so it can
/// never take a tap meant for a task.
class ZoneNameLabel extends StatelessWidget {
  const ZoneNameLabel({
    super.key,
    required this.theme,
    required this.zone,
    required this.day,
    required this.rangeStart,
    required this.pixelsPerMinute,
    required this.width,
    this.collapsedTop,
    this.collapsedHeight,
  });

  final AmbleTheme theme;
  final Zone zone;

  /// See [ZoneBackgroundBlock.day].
  final DateTime day;

  /// See [ZoneBackgroundBlock.rangeStart].
  final DateTime rangeStart;
  final double pixelsPerMinute;

  /// How much horizontal room the rotated label gets. Rotation swaps the
  /// axes, so this becomes the text's own line HEIGHT — it only needs to
  /// fit one line of `textCaption`.
  final double width;

  /// List (collapsed) mode override — see
  /// [ZoneBackgroundBlock.collapsedTop]/[ZoneBackgroundBlock.
  /// collapsedHeight]. Pass the SAME padded band values given to this
  /// zone's own [ZoneBackgroundBlock] (not the raw zone start/end), so the
  /// label spans exactly the band it names.
  final double? collapsedTop;
  final double? collapsedHeight;

  @override
  Widget build(BuildContext context) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final zoneStart = dayStart.add(Duration(minutes: zone.startMinutes));
    final zoneEnd = dayStart.add(Duration(minutes: zone.endMinutes));

    final top =
        collapsedTop ??
        zoneStart.difference(rangeStart).inMinutes * pixelsPerMinute;
    final height =
        collapsedHeight ??
        zoneEnd.difference(zoneStart).inMinutes * pixelsPerMinute;

    return Positioned(
      top: top,
      right: 0,
      width: width,
      height: height,
      child: IgnorePointer(
        // quarterTurns: 1 reads top-to-bottom down the right edge, matching
        // the design. The inner Center keeps the name centered along the
        // zone's span rather than pinned to its start, so a tall zone's
        // label sits beside the middle of the band it names.
        child: RotatedBox(
          quarterTurns: 1,
          child: Center(
            child: Text(
              zone.title,
              style: theme.textCaption.copyWith(
                color: theme.colorTextSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
