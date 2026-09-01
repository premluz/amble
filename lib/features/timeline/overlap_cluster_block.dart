import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_status.dart';
import '../../shared/services/overlap_cluster.dart';
import 'completion_checkbox.dart';
import 'task_category_token_mapping.dart';

/// The cluster's flat list of member tasks — title + time only, no per-row
/// card/icon/color/indentation, in chronological order (earliest first) —
/// plus a trailing completion checkbox per row, right-aligned within this
/// list panel exactly like an ordinary capsule's own checkbox is
/// right-aligned within its row. Positioned beside the cluster's member
/// pills, which render through the ordinary timeline slot loop in
/// `timeline_screen.dart` (each pinned to a fixed one-lane-per-task column
/// — see `_withClusterLanes` — so lane order always matches this list's
/// row order: leftmost pill, topmost row). The pills themselves carry no
/// checkbox of their own — confirmed directly, over an earlier pass that
/// put a checkbox next to each pill instead, since that read as if the
/// pill were its own separate task card rather than a plain positional
/// marker for the row here. See docs/DECISIONS.md for the full revision
/// history (this replaced an earlier stacked-icon-badge design).
class OverlapClusterBlock extends StatelessWidget {
  const OverlapClusterBlock({
    super.key,
    required this.cluster,
    this.onTaskTap,
    this.onToggleComplete,
    this.fadedTaskId,
  });

  final OverlapCluster cluster;

  /// Opens the same detail sheet a normal capsule block's tap does — fired
  /// with whichever row was tapped, since a cluster has no single "the
  /// task" to open.
  final ValueChanged<Task>? onTaskTap;

  /// Fired with whichever row's checkbox was tapped.
  final ValueChanged<Task>? onToggleComplete;

  /// The id of the member task currently being dragged, if any — that
  /// row fades (same treatment `TaskCapsuleBlock` already gives a dragged
  /// task's own name/time/checkbox while lifted) instead of vanishing
  /// from the list. Requested directly: the whole list used to crossfade
  /// to a shorter version the instant a drag started, which read as the
  /// row disappearing rather than the task being lifted — the structure
  /// (every original row) now holds for the whole drag.
  final String? fadedTaskId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    // No card/rounded-background wrapper, per direct feedback — the
    // rows sit directly on the timeline as plain text, not inside a
    // panel. Padding kept so rows don't sit flush against the pills.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, task) in cluster.tasks.indexed) ...[
            if (index > 0) SizedBox(height: theme.spacingXs),
            _ClusterTaskRow(
              theme: theme,
              task: task,
              onTap: onTaskTap == null ? null : () => onTaskTap!(task),
              onToggleComplete: onToggleComplete == null
                  ? null
                  : () => onToggleComplete!(task),
              isFaded: task.id == fadedTaskId,
            ),
          ],
        ],
      ),
    );
  }
}

/// The cluster's own boundary label — `min(start)` at the top,
/// `max(end)` at the bottom, styled exactly like [TaskBoundaryMarkers]'s
/// ordinary hour ticks (`textCaption`/`colorTextSecondary`) so it reads as
/// belonging to the same left gutter rather than a new label family. NOT
/// per-task times — the cluster's actual start/end span, per the settled
/// design. Unaffected by this session's visual revision.
class OverlapClusterBoundaryLabels extends StatelessWidget {
  const OverlapClusterBoundaryLabels({
    super.key,
    required this.theme,
    required this.cluster,
    required this.rangeStart,
    required this.pixelsPerMinute,
  });

  final AmbleTheme theme;
  final OverlapCluster cluster;

  /// The day view's own top edge — same coordinate space every other
  /// Positioned timeline element uses.
  final DateTime rangeStart;
  final double pixelsPerMinute;

  double _minutesSinceStart(DateTime time) =>
      time.difference(rangeStart).inMinutes.toDouble();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: _minutesSinceStart(cluster.start) * pixelsPerMinute,
          left: 0,
          child: FractionalTranslation(
            translation: const Offset(0, -0.5),
            child: Text(
              TimeOfDay.fromDateTime(cluster.start).format(context),
              style: theme.textCaption.copyWith(
                color: theme.colorTextSecondary,
              ),
            ),
          ),
        ),
        Positioned(
          top: _minutesSinceStart(cluster.end) * pixelsPerMinute,
          left: 0,
          child: FractionalTranslation(
            translation: const Offset(0, -0.5),
            child: Text(
              TimeOfDay.fromDateTime(cluster.end).format(context),
              style: theme.textCaption.copyWith(
                color: theme.colorTextSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One row inside the cluster's flat list — title + time range, plain
/// text only. No icon, no card, no color background, no proportional
/// height, no indentation, per the settled design; recurring/tracked-
/// behavior indicators are the one exception, shown inline after the
/// text when relevant.
class _ClusterTaskRow extends StatelessWidget {
  const _ClusterTaskRow({
    required this.theme,
    required this.task,
    required this.onTap,
    required this.onToggleComplete,
    required this.isFaded,
  });

  final AmbleTheme theme;
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;

  /// True while this row's task is the one being dragged — fades the row
  /// rather than removing it, matching how TaskCapsuleBlock fades a
  /// dragged task's own name/time/checkbox while lifted.
  final bool isFaded;

  @override
  Widget build(BuildContext context) {
    final start = TimeOfDay.fromDateTime(task.scheduledAt!);
    final end = TimeOfDay.fromDateTime(
      task.scheduledAt!.add(Duration(minutes: task.durationMinutes!)),
    );

    return AnimatedOpacity(
      opacity: isFaded ? 0.0 : 1.0,
      duration: theme.motionFast,
      curve: Curves.easeOut,
      child: IgnorePointer(
        ignoring: isFaded,
        child: _rowContent(context, start, end),
      ),
    );
  }

  Widget _rowContent(BuildContext context, TimeOfDay start, TimeOfDay end) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        task.title,
                        style: theme.textBody.copyWith(
                          color: theme.colorTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (task.isRecurring) ...[
                      SizedBox(width: theme.spacingXs),
                      Icon(
                        Icons.repeat_rounded,
                        size: theme.spacingSm * 2,
                        color: theme.colorTextSecondary,
                      ),
                    ],
                    if (task.isBehaviorInstance) ...[
                      SizedBox(width: theme.spacingXs),
                      Icon(
                        Icons.track_changes_rounded,
                        size: theme.spacingSm * 2,
                        color: theme.colorTextSecondary,
                      ),
                    ],
                  ],
                ),
                Text(
                  '${start.format(context)} - ${end.format(context)}',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: theme.spacingSm),
        // Right-aligned, matching where an ordinary capsule's own
        // checkbox sits within its row — the pill itself carries no
        // checkbox any more (see docs/DECISIONS.md), so this is the
        // task's only completion control while it's clustered.
        CompletionCheckbox(
          theme: theme,
          ringColor: theme.categoryIconColors[task.category.token]!,
          isCompleted: task.status == TaskStatus.completed,
          useMutedCompletedColor: true,
          onToggle: onToggleComplete,
        ),
      ],
    );
  }
}
