import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';

/// A full-width hairline with an accent-coloured time pill on its right
/// edge — the same visual [PlaceTaskLineLayer]'s own placement line uses
/// while dragging a new task into place, promoted here so it can be
/// reused wherever else a task's own start/end needs the identical
/// "accent bg on the right" treatment. Requested directly: "we have that
/// mechanism to show on the right time in accent color bg, we use it for
/// quick task add on long press[;] we need to use it... when quick new
/// add task is dropped and wiggly showing start and end of task... until
/// it[']s scheduled or closed[;] also in edit mode for selected (wiggly
/// tasks) we need to show it."
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

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Row(
        mainAxisSize: showLine ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showLine) ...[
            Expanded(
              child: Container(
                // Same hairline weight CurrentTimeIndicator's own line
                // uses — requested directly, matching the placement
                // line's own precedent.
                height: theme.borderWidthHairline,
                color: theme.colorAccent,
              ),
            ),
            SizedBox(width: theme.spacingSm),
          ],
          Container(
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
          ),
        ],
      ),
    );
  }
}
