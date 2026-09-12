import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';

/// The shared visual/gesture shape for every Edit Mode resize handle — a
/// small, always-tappable-looking bar with a generous invisible touch
/// area around it, matching the touch-target-vs-visual-size split every
/// other small control in this codebase already uses (e.g.
/// `CompletionCheckbox`'s own ring vs. its tap target).
///
/// Used by both `TaskCapsuleBlock` (one bottom handle) and
/// `ZoneContainerBlock` (one top, one bottom handle) — a single
/// definition rather than two near-identical private copies.
class ResizeHandle extends StatelessWidget {
  const ResizeHandle({
    super.key,
    required this.theme,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.height,
    this.barAlignment = Alignment.center,
  });

  final AmbleTheme theme;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;

  /// Overrides the handle's default `spacingMd` hit height.
  ///
  /// **2026-09-12 — no longer used to SHRINK a handle on a short pill.**
  /// Handles now grow strictly OUTWARD from the pill's edge (see
  /// [resizeHandleOutwardInset]), so they never consume the move band and
  /// never need to be clamped by the block's own height. Kept as an
  /// override for callers that genuinely want a different size —
  /// `ZoneContainerBlock`, whose containers are large and whose own
  /// handles sit inside its padding rather than overhanging.
  final double? height;

  /// Where the visible bar sits within the handle's own hit height.
  ///
  /// The hit area cannot extend past the pill's own bounds — Flutter does
  /// not hit-test a child outside its parent, `Clip.none` or not
  /// (confirmed with a throwaway probe widget test before this was
  /// built: both a vertically- and a horizontally-overhanging gesture box
  /// painted correctly and received no taps at all). So "grow the handle
  /// outward" is only achievable by growing it INWARD and pinning the bar
  /// to the outer edge: the target gets bigger, the bar stays visually
  /// where the user expects to grab, and the growth eats the pill's
  /// interior rather than empty timeline.
  ///
  /// [Alignment.topCenter] for a top handle, [Alignment.bottomCenter] for
  /// a bottom one.
  final Alignment barAlignment;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: onDragStart,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height ?? theme.spacingMd,
        alignment: barAlignment,
        child: Container(
          width: theme.spacingLg,
          height: 3,
          decoration: BoxDecoration(
            color: theme.colorTextPrimary.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(theme.radiusSm),
          ),
        ),
      ),
    );
  }
}

/// The hit height for a TASK pill's resize handle on a block of
/// [blockHeight] pixels.
///
/// Requested directly: "handle hit/active area should be larger outward
/// (but not inward, bear in mind smallest pill size has also drag as move
/// the entire pill interaction so we need affordance for all resize and
/// move 3 different interactive hotspots)... and sides also difficult to
/// catch at the moment."
///
/// **Outward is not physically available.** A gesture box positioned past
/// the pill's own bounds paints (the Stack is `Clip.none`) but never
/// receives a pointer — Flutter does not hit-test outside a parent's
/// bounds. Verified with a throwaway probe widget test covering both the
/// vertical and horizontal cases before settling on this. So every pixel
/// of target has to come from the pill's interior, and the real design
/// question is how to divide it between the three hotspots.
///
/// The split, in priority order:
/// - **Tall pill** (the common case): both handles take [_generousHandle],
///   a genuinely comfortable target, and move keeps everything between.
///   This is the "larger" the request is really asking for — the old
///   `spacingMd` (16px) was the cramped part.
/// - **Short pill**: handles give way to move rather than the reverse.
///   Move is the only interaction with no alternative (duration is also
///   editable from the detail sheet; position is not), and two handles
///   that have eaten the whole block leave a task that cannot be
///   rescheduled by dragging at all.
///
/// The bar is pinned to each handle's OUTER edge by the caller (see
/// [ResizeHandle.barAlignment]), so a taller hit area grows toward the
/// pill's middle while the grab affordance stays visually at the edge.
double taskResizeHandleHeightFor({
  required AmbleTheme theme,
  required double blockHeight,
}) {
  final generous = _generousHandle(theme);
  final minMoveBand = theme.spacingLg;
  if (blockHeight - generous * 2 >= minMoveBand) return generous;
  final fitted = (blockHeight - minMoveBand) / 2;
  return math.max(_minHandleHeight, math.min(generous, fitted));
}

/// A comfortable resize target on a pill with room for one — `spacingLg`
/// (24px) rather than the previous `spacingMd` (16px). Not the full ~44px
/// platform guidance: two 44px handles plus a move band would need a
/// ~110px pill (a ~2-hour task at the default scale), so this is the
/// largest value that still leaves most real tasks a usable move band.
double _generousHandle(AmbleTheme theme) => theme.spacingLg;

/// The handle height to use on a block of [blockHeight] pixels, so that a
/// top and bottom handle together always leave a move-only band in
/// between.
///
/// Returns the default `spacingMd` whenever the block is tall enough to
/// afford it, and otherwise shrinks both handles to whatever still leaves
/// [minMoveBand] pixels of grabbable middle — down to [_minHandleHeight],
/// below which a handle stops being reliably hittable and it is better to
/// have a too-small move band than two unusable handles.
///
/// Fixes a real edge, flagged during the top-handle work: at the 5-minute
/// duration floor a pill is 24px tall and two default handles claim 32px,
/// so the block was entirely handle and could not be dragged to a new
/// time at all.
double resizeHandleHeightFor({
  required AmbleTheme theme,
  required double blockHeight,
  double minMoveBand = 12.0,
}) {
  final byDefault = theme.spacingMd;
  if (blockHeight - byDefault * 2 >= minMoveBand) return byDefault;
  final fitted = (blockHeight - minMoveBand) / 2;
  return math.max(_minHandleHeight, math.min(byDefault, fitted));
}

/// Below this a handle is too small to hit reliably on a real device.
const _minHandleHeight = 8.0;
