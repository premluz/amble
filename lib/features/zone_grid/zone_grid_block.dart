import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import 'zone_body_gesture.dart';
import '../../core/widgets/selected_pill_border.dart';
import '../../shared/models/zone.dart';
import '../timeline/resize_handle.dart';
import '../../core/widgets/resize_handle_dot.dart';
import '../timeline/task_edge_time_label.dart';

/// One zone occurrence's block on the Weekly Zone Authoring Grid — a
/// vertical block spanning [zone]'s start/end time within its day's
/// column, labeled with rotated (vertical) title text.
///
/// **No color coding (confirmed directly)** — a flat `colorSurfaceSecondary`
/// fill regardless of which zone this is, matching how zones render
/// everywhere else in the app (`ZoneBackgroundBlock`'s own current fill,
/// `ZoneContainerBlock`'s card). Distinguished by label text only.
///
/// Mirrors `ZoneBackgroundBlock`'s exact gesture/selection composition
/// (a `Stack` with a fill `GestureDetector` for tap+move, plus top/bottom
/// `ResizeHandle`s, `SelectedPillBorder` marking the selected block)
/// rather than inventing a parallel shape — the grid's selection/resize
/// story is the same story, just laid out on a week instead of a single
/// day's time axis.
class ZoneGridBlock extends StatelessWidget {
  const ZoneGridBlock({
    super.key,
    required this.theme,
    required this.zone,
    required this.top,
    required this.height,
    required this.isSelected,
    required this.dayColumnLeft,
    this.horizontalOffset = 0,
    this.extending = false,
    this.liveStartMinutes,
    this.liveEndMinutes,
    required this.onTap,
    this.onMoveStart,
    this.onMoveUpdate,
    this.onMoveEnd,
    this.onResizeTopStart,
    this.onResizeTopUpdate,
    this.onResizeTopEnd,
    this.onResizeBottomStart,
    this.onResizeBottomUpdate,
    this.onResizeBottomEnd,
    this.onExtendStart,
    this.onExtendUpdate,
    this.onExtendEnd,
  });

  final AmbleTheme theme;
  final Zone zone;

  /// Pixel position within this day's column — already resolved by the
  /// caller from [Zone.startMinutes]/[Zone.endMinutes] against the grid's
  /// own pixelsPerMinute, same "caller resolves geometry" contract every
  /// other Timeline block already uses.
  final bool extending;
  final double horizontalOffset;
  final double top;
  final double height;

  /// This zone's own DAY COLUMN's outer `left` within the grid's shared
  /// Stack (`_axisWidth + (day - 1) * columnWidth` at the caller) — needed
  /// to walk the live edge labels below back to the grid's own hour-axis
  /// x, since this block's own local coordinate space starts at the
  /// column's left edge, not the grid's true x=0. See
  /// [liveStartMinutes]/[liveEndMinutes]'s own `Positioned` for the exact
  /// formula.
  final double dayColumnLeft;

  /// Whether this SPECIFIC zone is part of the current multi-selection —
  /// drives both the selection ring and the resize-handle visibility,
  /// mirroring `ZoneBackgroundBlock`'s own `editModeEnabled` gating (this
  /// screen has no non-selection "every zone shows a ring" mode — see the
  /// screen's own doc comment on why Edit Mode here is selection-only
  /// from the start).
  final bool isSelected;

  /// The start/end this block would COMMIT to if the live gesture were
  /// released right now, in minutes since its own day's midnight — or
  /// null for an edge that isn't moving.
  ///
  /// Mirrors `ZoneBackgroundBlock`'s own `liveStartMinutes`/
  /// `liveEndMinutes` pair exactly, including its rule: a RESIZE sets only
  /// the edge actually moving (the other stays null), while a MOVE sets
  /// both, since they shift together. Rendered as the same accent-backed
  /// [TaskEdgeTimeLabel] the placement line, the pending-create pill and
  /// Edit Mode's selected tasks all already use — requested directly:
  /// "we also should see start end time when resizing and moving on
  /// accent bg same as with tasks on edit mode."
  ///
  /// Deliberately the SNAPPED value, not the raw finger position: the
  /// block itself follows the finger continuously, but the number shown
  /// must be what a release would actually save, or the label and the
  /// committed time visibly disagree at drop (the same contract
  /// `_DraggableTaskBlock._previewStartsAt` documents for tasks).
  final int? liveStartMinutes;
  final int? liveEndMinutes;

  final VoidCallback onTap;

  final GestureDragStartCallback? onMoveStart;
  final GestureDragUpdateCallback? onMoveUpdate;
  final GestureDragEndCallback? onMoveEnd;

  final GestureDragStartCallback? onResizeTopStart;
  final GestureDragUpdateCallback? onResizeTopUpdate;
  final GestureDragEndCallback? onResizeTopEnd;

  final GestureDragStartCallback? onResizeBottomStart;
  final GestureDragUpdateCallback? onResizeBottomUpdate;
  final GestureDragEndCallback? onResizeBottomEnd;

  /// Side handles extend the placement across days; the body moves it.
  final GestureDragStartCallback? onExtendStart;
  final GestureDragUpdateCallback? onExtendUpdate;
  final GestureDragEndCallback? onExtendEnd;

  @override
  Widget build(BuildContext context) {
    // Inset from both lane edges so the block reads as narrower than its
    // own lane — requested directly ("width of the zones should be
    // smaller than lanes between lines") rather than filling the full
    // column width the way the lane dividers themselves span.
    final horizontalInset = theme.spacingXs;
    return Positioned(
      top: top,
      left: horizontalInset + horizontalOffset,
      right: horizontalInset - horizontalOffset,
      height: height,
      child: Opacity(
        opacity: extending ? 0 : 1,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            ZoneBodyGesture(
              onTap: onTap,
              onStart: onMoveStart,
              onUpdate: onMoveUpdate,
              onEnd: onMoveEnd,
              child: isSelected
                  ? SelectedPillBorder(
                      theme: theme,
                      // radiusSm — Weekly Zone Authoring Grid EXCEPTION,
                      // requested directly (2026-09-21, superseding the
                      // radiusXl unification below): this dense authoring
                      // surface reads better with the smallest rung on the
                      // scale, not the "zone pane" radiusXl every other
                      // zone-rendering surface uses. See
                      // docs/DESIGN_SYSTEM.md's "Zone pane indicator"
                      // section for the exception and its own reasoning.
                      contentRadius: BorderRadius.circular(theme.radiusSm),
                      fillColor: theme.colorSurfaceSecondary,
                      child: _RotatedTitle(theme: theme, title: zone.title),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorSurfaceSecondary,
                        // radiusSm — see this block's own doc comment above.
                        borderRadius: BorderRadius.circular(theme.radiusSm),
                      ),
                      child: _RotatedTitle(theme: theme, title: zone.title),
                    ),
            ),
            if (isSelected && onResizeTopEnd != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ResizeHandle(
                  theme: theme,
                  // `barAlignment`/`outwardShiftFactor` wired here too —
                  // this call had neither, so the default
                  // `Alignment.center` made `ResizeHandle`'s own outward
                  // push (keyed off `barAlignment.y.sign`) a no-op,
                  // leaving the dot at this box's MIDDLE — the same
                  // "still inside, not outside" gap fixed on
                  // `ZoneContainerBlock`'s equivalent handles. No
                  // clipping ancestor here (this `Stack` is
                  // `Clip.none`, same as that container's), so it gets
                  // the same full `1.5` push.
                  barAlignment: Alignment.topCenter,
                  onDragStart: onResizeTopStart,
                  onDragUpdate: onResizeTopUpdate,
                  onDragEnd: onResizeTopEnd,
                ),
              ),
            if (isSelected && onResizeBottomEnd != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ResizeHandle(
                  theme: theme,
                  barAlignment: Alignment.bottomCenter,
                  onDragStart: onResizeBottomStart,
                  onDragUpdate: onResizeBottomUpdate,
                  onDragEnd: onResizeBottomEnd,
                ),
              ),
            if (isSelected && onExtendEnd != null)
              for (final side in [Alignment.centerLeft, Alignment.centerRight])
                Align(
                  alignment: side,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: onExtendStart,
                    onHorizontalDragUpdate: onExtendUpdate,
                    onHorizontalDragEnd: onExtendEnd,
                    child: SizedBox(
                      width: theme.spacingMd,
                      height: theme.spacingMinTapTarget,
                      child: Align(
                        alignment: side,
                        child: Transform.translate(
                          offset: Offset(
                            side.x *
                                (theme.spacingSm / 2 -
                                    ResizeHandleDot.edgeInset(theme)),
                            0,
                          ),
                          child: ResizeHandleDot(theme: theme),
                        ),
                      ),
                    ),
                  ),
                ),
            // Last in this Stack so they paint ABOVE the rail and the
            // resize handles rather than under them — same ordering
            // `PendingTaskPill` uses for its own pair. Each straddles its
            // edge via a half-height `FractionalTranslation`, matching
            // `ZoneBackgroundBlock._liveZoneEdgeLabels`.
            //
            // Pinned INSIDE the grid's own hour-axis column — corrected
            // directly: "zones also blue time from to on the left." A
            // bare `left: 0` here only reached this DAY COLUMN's own local
            // x=0 (`horizontalInset` past its own left edge), which in the
            // grid's shared, absolute coordinate space landed at
            // `dayColumnLeft + horizontalInset` — day 1's block sat right
            // at the axis's own right edge, later days far to its right,
            // nowhere near the actual hour-tick text. `-(dayColumnLeft +
            // horizontalInset) + theme.spacingSm` walks back to the grid's
            // true x=0, then forward to `theme.spacingSm` — the SAME x the
            // hour-axis labels themselves use (see `zone_grid_screen.dart`'s
            // own `Positioned(left: theme.spacingSm, ...)` for the "HH:00"
            // ticks). Matches the identical fix already applied to
            // `ZoneBackgroundBlock`'s own pair on the spatial Timeline.
            if (liveStartMinutes case final startMinutes?)
              Positioned(
                top: 0,
                left:
                    -(dayColumnLeft + horizontalInset + horizontalOffset) +
                    theme.spacingSm,
                child: FractionalTranslation(
                  translation: const Offset(0, -0.5),
                  child: TaskEdgeTimeLabel(
                    theme: theme,
                    time: _timeOfDayFromMinutes(startMinutes),
                    showLine: false,
                  ),
                ),
              ),
            if (liveEndMinutes case final endMinutes?)
              Positioned(
                bottom: 0,
                left:
                    -(dayColumnLeft + horizontalInset + horizontalOffset) +
                    theme.spacingSm,
                child: FractionalTranslation(
                  translation: const Offset(0, 0.5),
                  child: TaskEdgeTimeLabel(
                    theme: theme,
                    time: _timeOfDayFromMinutes(endMinutes),
                    showLine: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Minutes-since-midnight to a [TimeOfDay], clamped into a single day.
///
/// A zone's `endMinutes` may legitimately be exactly 1440 (midnight at the
/// END of its day — see `Zone.endMinutes`' own assert, which allows it),
/// and `TimeOfDay(hour: 24)` is not a valid value. Rendering that edge as
/// `12:00 AM` is the honest reading: it IS midnight, just the closing one.
TimeOfDay _timeOfDayFromMinutes(int minutes) {
  final clamped = minutes.clamp(0, 24 * 60) % (24 * 60);
  return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
}

/// The zone's title, rotated to read top-to-bottom inside its block —
/// per the reviewed mockup.
///
/// **Deliberately NOT stretched to fill the block's height** — the
/// reviewed mockup's own bug, flagged directly in the work order to avoid
/// repeating: a naive `RotatedBox` wrapping a `Text` with no size
/// constraint of its own will happily stretch a short title's letters
/// apart to fill a tall block, since `Center`+unconstrained `Text` inside
/// a rotated axis has nothing telling it to stay compact. This renders at
/// `theme.textZoneName` (the shared compact zone-name style used by the
/// spatial Timeline too) wrapped in a `FittedBox` that only
/// SHRINKS (`BoxFit.scaleDown`) when a block is too short for even the
/// compact size, never grows past it.
class _RotatedTitle extends StatelessWidget {
  const _RotatedTitle({required this.theme, required this.title});

  final AmbleTheme theme;
  final String title;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacingXs),
        child: Center(
          child: RotatedBox(
            quarterTurns: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // textZoneName is shared with the spatial Timeline's
                // rotated zone label and stays compact/monospace.
                style: theme.textZoneName.copyWith(
                  color: theme.colorTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
