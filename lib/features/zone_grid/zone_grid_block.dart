import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/zone.dart';
import '../timeline/edit_mode_wiggle.dart';
import '../timeline/resize_handle.dart';
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
/// Mirrors `ZoneBackgroundBlock`'s exact gesture/wiggle composition
/// (`EditModeWiggle` wrapping a `Stack` with a fill `GestureDetector` for
/// tap+move, plus top/bottom `ResizeHandle`s) rather than inventing a
/// parallel shape — the grid's selection/wiggle/resize story is the same
/// story, just laid out on a week instead of a single day's time axis.
class ZoneGridBlock extends StatelessWidget {
  const ZoneGridBlock({
    super.key,
    required this.theme,
    required this.zone,
    required this.top,
    required this.height,
    required this.isSelected,
    required this.wiggleEnabled,
    this.phaseOffset = 0,
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
  final double top;
  final double height;

  /// Whether this SPECIFIC zone is part of the current multi-selection —
  /// drives both the wiggle and the resize-handle visibility, mirroring
  /// `ZoneBackgroundBlock`'s own `editModeEnabled && (isSelected)` gating
  /// (this screen has no non-selection "every zone wiggles" mode — see
  /// the screen's own doc comment on why Edit Mode here is selection-only
  /// from the start).
  final bool isSelected;

  /// Whether wiggle actually animates right now — separate from
  /// [isSelected] because a just-toggled-off block should stop wiggling
  /// immediately while its resize handles are what actually gate on
  /// [isSelected] a frame later, matching `EditModeWiggle`'s own
  /// enabled/disabled transition contract.
  final bool wiggleEnabled;

  final double phaseOffset;

  /// The start/end this block would COMMIT to if the live gesture were
  /// released right now, in minutes since its own day's midnight — or
  /// null for an edge that isn't moving.
  ///
  /// Mirrors `ZoneBackgroundBlock`'s own `liveStartMinutes`/
  /// `liveEndMinutes` pair exactly, including its rule: a RESIZE sets only
  /// the edge actually moving (the other stays null), while a MOVE sets
  /// both, since they shift together. Rendered as the same accent-backed
  /// [TaskEdgeTimeLabel] the placement line, the pending-create pill and
  /// Edit Mode's wiggling tasks all already use — requested directly:
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

  /// Dragging the block SIDEWAYS extends this zone across adjacent days,
  /// creating one independent occurrence per day crossed (confirmed
  /// directly: "one separate instance per day", same start/end as this
  /// one).
  ///
  /// Deliberately the block BODY rather than left/right handles, also
  /// confirmed directly. Handles were the first instinct, but
  /// `resize_handle.dart` documents — and verified with a throwaway probe
  /// — that Flutter never hit-tests a child outside its parent's bounds,
  /// so a side handle can only grow INWARD, eating the block's own width.
  /// At seven columns on a phone a column is ~70px wide, which leaves no
  /// room for two side handles plus a grabbable middle. The body already
  /// distinguishes gestures by axis (vertical moves in time), so
  /// horizontal is free and costs no width at all.
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
      left: horizontalInset,
      right: horizontalInset,
      height: height,
      child: EditModeWiggle(
        enabled: wiggleEnabled,
        phaseOffset: phaseOffset,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onVerticalDragStart: onMoveStart,
              onVerticalDragUpdate: onMoveUpdate,
              onVerticalDragEnd: onMoveEnd,
              // Horizontal is a genuinely different intent from vertical
              // here — see [onExtendStart]. Flutter's arena picks whichever
              // axis the finger actually commits to, so the two never fire
              // for the same gesture.
              onHorizontalDragStart: onExtendStart,
              onHorizontalDragUpdate: onExtendUpdate,
              onHorizontalDragEnd: onExtendEnd,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorSurfaceSecondary,
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                  border: isSelected
                      ? Border.all(
                          color: theme.colorAccent,
                          width: theme.borderWidthHairline * 2,
                        )
                      : null,
                ),
                child: _RotatedTitle(theme: theme, title: zone.title),
              ),
            ),
            if (isSelected && onResizeTopEnd != null)
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
            if (isSelected && onResizeBottomEnd != null)
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
            // Last in this Stack so they paint ABOVE the rail and the
            // resize handles rather than under them — same ordering
            // `PendingTaskPill` uses for its own pair. Each straddles its
            // edge via a half-height `FractionalTranslation`, matching
            // `ZoneBackgroundBlock._liveZoneEdgeLabels`.
            // **Left-aligned, both of them** — requested directly. Pinned
            // by `left` ALONE, with no `right`: `TaskEdgeTimeLabel`'s own
            // Row uses `MainAxisAlignment.end`, so a box stretched
            // edge-to-edge (`left: 0, right: 0`, as these were) pushes the
            // pill to the RIGHT edge. Dropping `right` lets the Row
            // shrink-wrap its own pill, which then sits wherever `left`
            // puts it — no alignment parameter needed on the shared
            // widget, and no change to its six task-side callers.
            //
            // This is also exactly how `ZoneBackgroundBlock` already
            // positions its own pair (`Positioned(left: gutterOffset)`,
            // no `right`), so the two zone surfaces now match by
            // construction rather than by coincidence.
            if (liveStartMinutes case final startMinutes?)
              Positioned(
                top: 0,
                left: 0,
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
                left: 0,
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
/// `theme.textCaption` (the same fixed, compact size `ZoneNameLabel`
/// already uses for zone titles elsewhere — see
/// `zone_background_block.dart`) wrapped in a `FittedBox` that only
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
                style: theme.textCaption.copyWith(
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
