import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/zone.dart';
import 'edit_mode_wiggle.dart';
import 'resize_handle.dart';
import 'task_edge_time_label.dart';

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

/// The rendering background block for one [Zone] on the Spatial Task View
/// (Timeline) — per CONSTITUTION.md's Zone section ("Zone is metadata on a
/// Task, not a container that owns it"), this widget still never owns or
/// repositions any [Task]'s rendering. It DOES support its own move/resize
/// now (**reversed 2026-09-06**, confirmed directly — "we should be able to
/// edit zones in any view ... in spatial task view also" — superseding the
/// per-view-job rule's original "Task view organizes time, Zone view
/// organizes meaning, don't blend them" read on zone editing specifically):
/// Edit Mode gates the WHOLE FILL itself (no separate header/label — an
/// earlier pass added a title+time text row here, removed per direct
/// feedback: "the addition of a title inside the zone... we didn't ask
/// for") as a whole-block tap-to-select/drag-to-MOVE target, plus two edge
/// [ResizeHandle]s, mirroring [onMoveStart]/[onResizeTopStart]/
/// [onResizeBottomStart]'s exact contract on `ZoneContainerBlock` (the Zone
/// view's own container — frozen as of 2026-09-06, no further updates
/// there), so the same shared commit path (`_commitZoneCascade` in
/// `timeline_screen.dart`) applies here too.
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
    this.previewTop,
    this.previewHeight,
    this.liveStartMinutes,
    this.liveEndMinutes,
    this.editModeEnabled = false,
    this.phaseOffset = 0,
    this.onResizeTopStart,
    this.onResizeTopUpdate,
    this.onResizeTopEnd,
    this.onResizeBottomStart,
    this.onResizeBottomUpdate,
    this.onResizeBottomEnd,
    this.onMoveStart,
    this.onMoveUpdate,
    this.onMoveEnd,
    this.onHeaderTap,
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

  /// Live drag-preview override — both null or both set, same "override
  /// pair" contract as [collapsedTop]/[collapsedHeight] but for a
  /// different reason: an in-progress move/resize renders at its
  /// CANDIDATE geometry immediately, rather than waiting for the write to
  /// land, matching every other drag surface in this codebase. Mutually
  /// exclusive with [collapsedTop]/[collapsedHeight] in practice (List
  /// mode never wires move/resize at all), but kept as its own pair rather
  /// than overloading that one — the two express genuinely different
  /// things ("this mode has no time axis at all" vs. "this is where a
  /// live drag currently sits on the real one"). [zone]'s own
  /// `startMinutes`/`endMinutes` stay UNCHANGED during a preview — only
  /// geometry updates, matching `ZoneContainerBlock`'s own live-resize
  /// precedent in Zone view (its header's displayed time range doesn't
  /// preview either, only the container's bounds do).
  final double? previewTop;
  final double? previewHeight;

  /// Live move/resize minute overrides — set together, mirroring
  /// [previewTop]/[previewHeight]'s own "both or neither" pair contract.
  /// While a move/resize is in progress, these carry the CANDIDATE
  /// `startMinutes`/`endMinutes` (matching [previewTop]/[previewHeight]'s
  /// own geometry), driving a left-pinned accent time badge over the hour
  /// gutter — the same "always on left" treatment task blocks use.
  /// Requested directly: "also should be show for zones."
  final int? liveStartMinutes;
  final int? liveEndMinutes;

  /// Edit Mode's persistent visual signal — see `edit_mode_wiggle.dart`.
  /// Applied HERE, inside the `Positioned` this widget itself returns,
  /// rather than by the caller wrapping this whole widget in
  /// `EditModeWiggle`: that widget inserts a `Transform` between its child
  /// and whatever comes after it, which breaks the `Positioned` below —
  /// `Positioned` must be a direct `Stack` child (`ZoneContainerBlock`'s own
  /// caller in `zone_day_timeline.dart` follows the same
  /// `Positioned(child: EditModeWiggle(...))` order).
  final bool editModeEnabled;
  final double phaseOffset;

  /// The TOP-edge handle's drag handlers — changes [Zone.startMinutes]
  /// only. Null callbacks mean "no handle rendered here," matching
  /// `ZoneContainerBlock.onResizeTopStart`'s own "null means not
  /// resizable" contract. Collapsed (List) mode never wires these —
  /// [collapsedTop]/[collapsedHeight] geometry has no time axis for a
  /// resize to mean anything against.
  final GestureDragStartCallback? onResizeTopStart;
  final GestureDragUpdateCallback? onResizeTopUpdate;
  final GestureDragEndCallback? onResizeTopEnd;

  /// The BOTTOM-edge handle's drag handlers — changes [Zone.endMinutes]
  /// only. See `ZoneContainerBlock.onResizeBottomStart`'s own doc comment.
  final GestureDragStartCallback? onResizeBottomStart;
  final GestureDragUpdateCallback? onResizeBottomUpdate;
  final GestureDragEndCallback? onResizeBottomEnd;

  /// Whole-block MOVE handlers — the entire fill is the drag target (no
  /// separate header strip, unlike `ZoneContainerBlock`'s own header-only
  /// touch target in Zone view, which avoids fighting a row-list scroll
  /// gesture underneath it — nothing sits underneath THIS block, so
  /// there's no equivalent reason to scope it down). Null means "not
  /// draggable here," same "null means not draggable" contract every
  /// other optional gesture in this codebase already uses.
  final GestureDragStartCallback? onMoveStart;
  final GestureDragUpdateCallback? onMoveUpdate;
  final GestureDragEndCallback? onMoveEnd;

  /// Selects this zone instead of moving it — only ever non-null under
  /// multi-task mode (`DevMultiTaskEditMode`), mirroring
  /// `_DraggableTaskBlockState._effectiveOnTap`'s exact contract. Null
  /// under ordinary (single-task) Edit Mode, where the fill is
  /// drag-to-move only — the two are mutually exclusive at any one time
  /// (see [build]'s own gesture-wiring), never offered together.
  final VoidCallback? onHeaderTap;

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
        previewTop ??
        collapsedTop ??
        zoneStart.difference(rangeStart).inMinutes * pixelsPerMinute;
    final strictHeight =
        previewHeight ??
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
      child: EditModeWiggle(
        enabled: editModeEnabled,
        phaseOffset: phaseOffset,
        // A genuinely new Stack ancestor (same discipline as
        // ZoneContainerBlock's own resize-handle wrap) so the two handles
        // can overlay this block's top/bottom edges without disturbing the
        // fill or the header's own drag detector beneath them.
        // StackFit.expand: a bare (non-Positioned) child of a Stack sizes
        // to its own intrinsic size by default (StackFit.loose), which
        // collapsed the fill below to zero — the whole reason the zone
        // background stopped rendering entirely after this Stack wrap was
        // added. expand stretches it back to the outer Positioned's own
        // tight top/left/width/height, matching what the plain DecoratedBox
        // got for free before this Stack existed.
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            // Fill — the WHOLE block is now the tap/drag target (not a
            // header strip with its own title/time label). Requested
            // directly — "What I see is the addition of a title inside the
            // zone, which we didn't ask for. Let's remove this title, and
            // let's make the zone editable on top so it wiggles" —
            // reversing the earlier header-row design (which mirrored
            // `ZoneContainerBlock`'s own header) in favor of the plain
            // fill itself being the target, with no visible label added.
            //
            // IgnorePointer wraps the GestureDetector (not the reverse) so
            // `ignoring: true` genuinely stops the detector from claiming
            // the gesture at all, letting a tap meant for a task pill or
            // the placement line underneath fall through — matches this
            // block's original purely-decorative contract whenever
            // there's nothing to select or move here (Edit Mode off, or on
            // but this isn't a draggable/selectable zone).
            IgnorePointer(
              ignoring: onMoveEnd == null && onHeaderTap == null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onHeaderTap,
                onVerticalDragStart: onMoveStart,
                onVerticalDragUpdate: onMoveUpdate,
                onVerticalDragEnd: onMoveEnd,
                child: DecoratedBox(
                  // Plain, non-colored surface — matches the Zone list
                  // row (Settings → Manage → Zones) and the Tracked
                  // behavior card, requested directly: "the zone card
                  // make the color of the card [same as] on manage...
                  // as card on tracked... non colored." Was
                  // `colorZoneBackground`, a distinct zone-tint fill.
                  decoration: BoxDecoration(
                    color: theme.colorSurfaceSecondary,
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                  ),
                ),
              ),
            ),
            if (editModeEnabled && onResizeTopEnd != null)
              Positioned(
                top: -theme.spacingXs,
                left: 0,
                right: 0,
                child: ResizeHandle(
                  theme: theme,
                  onDragStart: onResizeTopStart,
                  onDragUpdate: onResizeTopUpdate,
                  onDragEnd: onResizeTopEnd,
                ),
              ),
            if (editModeEnabled && onResizeBottomEnd != null)
              Positioned(
                bottom: -theme.spacingXs,
                left: 0,
                right: 0,
                child: ResizeHandle(
                  theme: theme,
                  onDragStart: onResizeBottomStart,
                  onDragUpdate: onResizeBottomUpdate,
                  onDragEnd: onResizeBottomEnd,
                ),
              ),
            // Live move/resize time badges, pinned over the hour gutter
            // on the LEFT — same "always on left" treatment
            // `_DraggableTaskBlock` uses for tasks, extended to zones:
            // "also should be show for zones." `-(left - gutterWidth's
            // own offset)` walks this Positioned back from the block's
            // local origin (`left - zoneBackgroundOffset`, this widget's
            // own outer `Positioned.left`) to the day column's true x=0.
            // Each edge renders independently — a resize sets only the
            // edge that's actually moving (the other stays null), while
            // a move sets both (they shift together).
            ..._liveZoneEdgeLabels(
              gutterOffset: -(left - zoneBackgroundOffset),
              height: strictHeight - zoneBackgroundGap,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _liveZoneEdgeLabels({
    required double gutterOffset,
    required double height,
  }) {
    return [
      if (liveStartMinutes != null)
        Positioned(
          top: 0,
          left: gutterOffset,
          child: FractionalTranslation(
            translation: const Offset(0, -0.5),
            child: TaskEdgeTimeLabel(
              theme: theme,
              time: TimeOfDay.fromDateTime(
                DateTime(
                  day.year,
                  day.month,
                  day.day,
                ).add(Duration(minutes: liveStartMinutes!)),
              ),
              showLine: false,
            ),
          ),
        ),
      if (liveEndMinutes != null)
        Positioned(
          top: height,
          left: gutterOffset,
          child: FractionalTranslation(
            translation: const Offset(0, -0.5),
            child: TaskEdgeTimeLabel(
              theme: theme,
              time: TimeOfDay.fromDateTime(
                DateTime(
                  day.year,
                  day.month,
                  day.day,
                ).add(Duration(minutes: liveEndMinutes!)),
              ),
              showLine: false,
            ),
          ),
        ),
    ];
  }
}

/// The zone's name, rotated 90° and pinned to the RIGHT edge of the day
/// column, spanning the zone's own vertical extent.
///
/// Requested directly ("can't see vertical zone name on task view"), and
/// styled to match the hour labels on the opposite edge — `textCaption`.
/// **2026-09-12**: color moved to `colorTextTertiary`, subtler than
/// `colorTextSecondary` — requested directly ("make zone names even
/// subtler color"), so the two read as the same class of ambient
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
              style: theme.textCaption.copyWith(color: theme.colorTextTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
