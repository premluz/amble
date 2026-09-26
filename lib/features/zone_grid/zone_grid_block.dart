import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
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
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          _AxisLockedMoveExtendDetector(
            onTap: onTap,
            onMoveStart: onMoveStart,
            onMoveUpdate: onMoveUpdate,
            onMoveEnd: onMoveEnd,
            onExtendStart: onExtendStart,
            onExtendUpdate: onExtendUpdate,
            onExtendEnd: onExtendEnd,
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
              left: -(dayColumnLeft + horizontalInset) + theme.spacingSm,
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
              left: -(dayColumnLeft + horizontalInset) + theme.spacingSm,
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

/// Wraps a single [GestureDetector] wiring BOTH move (vertical) and extend
/// (horizontal) so the two axis-specific recognizers hold ONE gesture each
/// to axis-lock, instead of Flutter's own per-axis recognizers
/// re-arbitrating the gesture arena on every frame.
///
/// **2026-09-23 — real bug, fixed.** A bare `GestureDetector` with both
/// `onVerticalDrag*` and `onHorizontalDrag*` set creates two independent
/// recognizers that compete for the SAME pointer; Flutter's own doc
/// comment on this class in `zone_grid_screen.dart`'s call site claimed
/// "the arena picks whichever axis the finger actually commits to," which
/// is only true for the FIRST few pixels of movement. Reported directly:
/// dragging a selected zone sideways to extend it across days worked "one
/// by one" instead of as a single continuous motion, requiring repeated
/// tap-move-release cycles — unlike vertical resize (top/bottom), which
/// already behaved as one continuous drag. The cause: over a long drag
/// spanning several day-columns, the finger's natural vertical drift was
/// enough for the vertical recognizer to occasionally win a
/// re-arbitration mid-gesture, cancelling the horizontal one and forcing
/// the user to lift and restart.
///
/// Fixed by latching which axis committed on the FIRST `*DragStart` this
/// widget sees, and refusing to let the other axis's callbacks fire again
/// until the gesture ends — the same "pick one axis and hold it for the
/// whole gesture" guarantee `_MarqueeResizeHandle` (`zone_grid_screen
/// .dart`) already gets for free, because each of its handles wires only
/// ONE axis's callbacks to begin with. This widget exists specifically
/// because [ZoneGridBlock]'s move/extend gesture can't split into two
/// handles the way marquee resize can (see [ZoneGridBlock.onExtendStart]'s
/// own doc comment on why a side handle isn't viable here).
class _AxisLockedMoveExtendDetector extends StatefulWidget {
  const _AxisLockedMoveExtendDetector({
    required this.onTap,
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onMoveEnd,
    required this.onExtendStart,
    required this.onExtendUpdate,
    required this.onExtendEnd,
    required this.child,
  });

  final VoidCallback onTap;
  final GestureDragStartCallback? onMoveStart;
  final GestureDragUpdateCallback? onMoveUpdate;
  final GestureDragEndCallback? onMoveEnd;
  final GestureDragStartCallback? onExtendStart;
  final GestureDragUpdateCallback? onExtendUpdate;
  final GestureDragEndCallback? onExtendEnd;
  final Widget child;

  @override
  State<_AxisLockedMoveExtendDetector> createState() =>
      _AxisLockedMoveExtendDetectorState();
}

enum _LockedAxis { vertical, horizontal }

class _AxisLockedMoveExtendDetectorState
    extends State<_AxisLockedMoveExtendDetector> {
  /// Which axis committed for the gesture currently in flight, or null
  /// between gestures. Set on the first `*DragStart` either axis reports
  /// and cleared on that SAME axis's own `*DragEnd`/`*DragCancel` — never
  /// by the other axis, which is the whole point: once one axis has
  /// started, the other's start/update/end callbacks are refused until
  /// this one says the gesture is over.
  _LockedAxis? _lockedAxis;

  void _onVerticalStart(DragStartDetails details) {
    if (_lockedAxis != null) return;
    _lockedAxis = _LockedAxis.vertical;
    widget.onMoveStart?.call(details);
  }

  void _onVerticalUpdate(DragUpdateDetails details) {
    if (_lockedAxis != _LockedAxis.vertical) return;
    widget.onMoveUpdate?.call(details);
  }

  void _onVerticalEnd(DragEndDetails details) {
    if (_lockedAxis != _LockedAxis.vertical) return;
    _lockedAxis = null;
    widget.onMoveEnd?.call(details);
  }

  void _onVerticalCancel() {
    if (_lockedAxis != _LockedAxis.vertical) return;
    _lockedAxis = null;
  }

  void _onHorizontalStart(DragStartDetails details) {
    if (_lockedAxis != null) return;
    _lockedAxis = _LockedAxis.horizontal;
    widget.onExtendStart?.call(details);
  }

  void _onHorizontalUpdate(DragUpdateDetails details) {
    if (_lockedAxis != _LockedAxis.horizontal) return;
    widget.onExtendUpdate?.call(details);
  }

  void _onHorizontalEnd(DragEndDetails details) {
    if (_lockedAxis != _LockedAxis.horizontal) return;
    _lockedAxis = null;
    widget.onExtendEnd?.call(details);
  }

  void _onHorizontalCancel() {
    if (_lockedAxis != _LockedAxis.horizontal) return;
    _lockedAxis = null;
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(debugOwner: this),
              (instance) => instance.onTap = widget.onTap,
            ),
        VerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
              () => VerticalDragGestureRecognizer(debugOwner: this),
              (instance) => instance
                ..onStart = widget.onMoveStart == null ? null : _onVerticalStart
                ..onUpdate = widget.onMoveUpdate == null
                    ? null
                    : _onVerticalUpdate
                ..onEnd = widget.onMoveEnd == null ? null : _onVerticalEnd
                ..onCancel = widget.onMoveEnd == null
                    ? null
                    : _onVerticalCancel,
            ),
        // **2026-09-23 — an EAGER horizontal recognizer, via
        // `RawGestureDetector`.** The block sits inside the grid's own
        // vertical `SingleChildScrollView`, and that scrollable competes
        // for every drag. A plain `GestureDetector`'s horizontal
        // recognizer only wins the arena if the finger's motion is
        // decisively horizontal from the first frames; a real finger
        // sweeping across day columns drifts vertically enough that the
        // SCROLLABLE won instead, so the grid scrolled and the extend
        // never started at all. Reported directly: dragging sideways
        // "grabs/scrolls instead," needing repeated tap-move-release
        // attempts to land one column at a time.
        //
        // The screen's own `physics: NeverScrollableScrollPhysics` guard
        // could not prevent this — it keys off `_fillSource != null`,
        // which is set by `onExtendStart`, which only fires once this
        // recognizer has ALREADY won. The guard suppresses scrolling for
        // the REST of a fill that managed to start; it cannot help the
        // gesture win in the first place, which is where the drag was
        // actually being lost.
        //
        // `resolve(GestureDisposition.accepted)` on start claims the
        // pointer outright the moment this recognizer is satisfied,
        // rather than waiting for the arena to sweep — so the scrollable
        // is rejected and the whole continuous drag belongs to the
        // extend. Vertical deliberately stays a plain, non-eager
        // recognizer: a vertical drag on a zone SHOULD still be able to
        // lose to the scroll view, which is the long-standing "normal
        // vertical swipe scrolls rather than moving" behaviour this
        // screen has always had.
        _EagerHorizontalDragRecognizer:
            GestureRecognizerFactoryWithHandlers<
              _EagerHorizontalDragRecognizer
            >(
              () => _EagerHorizontalDragRecognizer(debugOwner: this),
              (instance) => instance
                ..onStart = widget.onExtendStart == null
                    ? null
                    : _onHorizontalStart
                ..onUpdate = widget.onExtendUpdate == null
                    ? null
                    : _onHorizontalUpdate
                ..onEnd = widget.onExtendEnd == null ? null : _onHorizontalEnd
                ..onCancel = widget.onExtendEnd == null
                    ? null
                    : _onHorizontalCancel,
            ),
      },
      child: widget.child,
    );
  }
}

/// A [HorizontalDragGestureRecognizer] that claims the gesture arena as
/// soon as it recognises a horizontal drag, instead of waiting for the
/// arena to resolve normally.
///
/// Exists so a sideways extend on [ZoneGridBlock] beats the grid's own
/// enclosing vertical scrollable — see the call site's own comment for
/// the full reasoning and the bug this fixes. Without this, the
/// scrollable wins any drag whose first frames carry enough vertical
/// component, which a real finger sweeping across columns almost always
/// does.
class _EagerHorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  _EagerHorizontalDragRecognizer({super.debugOwner});

  /// How much earlier than the enclosing scrollable this recognizer
  /// commits, as a fraction of the platform touch slop.
  ///
  /// `DragGestureRecognizer` already resolves the arena as soon as its own
  /// axis passes slop (see `handleEvent`'s `_DragState.possible` branch in
  /// Flutter's `monodrag.dart`) — so "be eager" is not about resolving
  /// sooner in the abstract, it is about crossing the threshold BEFORE the
  /// scroll view's own vertical recognizer crosses its. Both race on the
  /// same pointer stream; whichever axis passes slop first takes the
  /// gesture. A finger sweeping across day columns produces a mostly-
  /// horizontal path with real vertical drift, and at equal thresholds the
  /// vertical recognizer frequently won.
  ///
  /// Halving the threshold means a decisively horizontal movement is
  /// claimed while the vertical component is still short of ITS slop,
  /// which is what makes the extend win the whole continuous drag. A
  /// genuinely vertical drag is unaffected: its horizontal component never
  /// approaches even this reduced threshold, so the scrollable still wins
  /// and "normal vertical swipe scrolls" behaviour is preserved.
  static const double _slopFraction = 0.5;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    final slop = computeHitSlop(pointerDeviceKind, gestureSettings);
    return globalDistanceMoved.abs() > slop * _slopFraction;
  }
}
