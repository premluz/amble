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
  });

  final AmbleTheme theme;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;

  /// Overrides the handle's default `spacingMd` hit height.
  ///
  /// Exists for one case: a block short enough that two default-height
  /// handles would consume its entire height, leaving no move-only band
  /// between them. At the 5-minute floor a pill is `sizeTaskBadge` (24px)
  /// tall while two handles claim 16px each — 32px of handle in 24px of
  /// block, so the whole thing is grab-to-resize and it cannot be moved
  /// at all. Callers pass a smaller value there; see
  /// [resizeHandleHeightFor].
  final double? height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: onDragStart,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height ?? theme.spacingMd,
        alignment: Alignment.center,
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
