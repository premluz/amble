import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';

/// Which end of the row [TaskEdgeTimeLabel]'s accent pill sits at. See
/// docs/DESIGN_SYSTEM.md's "hour/time indicator" entry — [start] (the
/// left, in this app's LTR-only layout) is the canonical side for every
/// current and future caller; [end] exists only for the one legacy
/// full-width-hairline caller ([PlaceTaskLineLayer]'s placement line, kept
/// visually unchanged apart from the pill's own side) mid-migration.
enum TaskEdgeTimeLabelAlignment { start, end }

/// A full-width hairline with an accent-coloured time pill at one edge —
/// the same visual [PlaceTaskLineLayer]'s own placement line uses while
/// dragging a new task into place, promoted here so it can be reused
/// wherever else a task's own start/end needs the identical "accent bg
/// time pill" treatment. Requested directly: "we have that mechanism to
/// show on the right time in accent color bg, we use it for quick task
/// add on long press[;] we need to use it... when quick new add task is
/// dropped and wiggly showing start and end of task... until it[']s
/// scheduled or closed[;] also in edit mode for selected (wiggly tasks)
/// we need to show it."
///
/// **The pill is always LEFT-aligned** ([TaskEdgeTimeLabelAlignment.start],
/// the default) as of the design-system consolidation pass — every
/// current caller except the placement line already achieved this by
/// dropping `right:` from its own `Positioned` box so this widget's Row
/// shrink-wraps; the placement line is the one caller whose full-width
/// hairline still needs the whole box, so it passes `pillAlignment:
/// start` explicitly instead. See docs/DESIGN_SYSTEM.md.
///
/// Purely visual (`IgnorePointer`-wrapped) — the caller positions this
/// widget (typically via `Positioned` at a block's own top/bottom edge)
/// and owns every gesture underneath it, exactly like the placement
/// line's own contract.
class TaskEdgeTimeLabel extends StatelessWidget {
  const TaskEdgeTimeLabel({
    super.key,
    required this.theme,
    required this.time,
    this.showLine = true,
    this.pillAlignment = TaskEdgeTimeLabelAlignment.start,
  });

  final AmbleTheme theme;
  final TimeOfDay time;

  /// Whether the full-width hairline renders alongside the time pill.
  /// Defaults to true, matching the placement line's own original look
  /// (marking exactly where a NEW task would land on empty background,
  /// where a line usefully draws the eye across the whole row). Reported
  /// directly as wrong for the two later uses (the pending draft pill and
  /// Edit Mode's wiggling task): those sit ON an existing, already-visible
  /// block, so a second full-width line reads as visual noise rather than
  /// a placement aid — just the accent time badge is enough there.
  final bool showLine;

  /// See [TaskEdgeTimeLabelAlignment]. Only meaningfully different from
  /// the default when [showLine] is true — a `showLine: false` caller
  /// already controls its side entirely via its own `Positioned`
  /// constraints (shrink-wrap vs. stretch), since this widget's Row has
  /// nothing else to align within once there's no hairline filling the
  /// rest of the box.
  final TaskEdgeTimeLabelAlignment pillAlignment;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacingSm,
        vertical: theme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: theme.colorAccent,
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Text(
        time.format(context),
        style: theme.textCaption.copyWith(
          color: theme.colorSurfacePrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (!showLine) {
      return IgnorePointer(
        child: Row(mainAxisSize: MainAxisSize.min, children: [pill]),
      );
    }

    final hairline = Expanded(
      child: Container(
        // Same hairline weight CurrentTimeIndicator's own line uses —
        // requested directly, matching the placement line's own
        // precedent.
        height: theme.borderWidthHairline,
        color: theme.colorAccent,
      ),
    );
    final gap = SizedBox(width: theme.spacingSm);

    return IgnorePointer(
      child: Row(
        children: pillAlignment == TaskEdgeTimeLabelAlignment.start
            ? [pill, gap, hairline]
            : [hairline, gap, pill],
      ),
    );
  }
}
