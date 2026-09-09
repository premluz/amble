import 'package:flutter/material.dart';

import '../../core/dev_config.dart' show TimelineTaskTextLayout;
import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/external_calendar_event.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_status.dart';
import '../../shared/services/overlap_cluster.dart';
import 'completion_checkbox.dart';
import 'duration_label.dart';
import 'external_event_block.dart' show showExternalCalendarEventInfo;

/// The cluster's flat list of members — title + time only, no icon, no
/// per-row card/color/indentation, per the settled design (a category
/// emoji was tried here directly, then reverted: it overflowed the row's
/// fixed height and, per direct feedback, belongs on the cluster's own
/// PILL markers instead — see [TaskCapsuleBlock]'s own `contentHidden`
/// handling for where that now happens) — plus a trailing completion
/// checkbox per TASK row (an event row has no completion state, so it
/// renders no checkbox — see [_ClusterEventRow]), in a fixed color no
/// longer tied to the task's own category (see `CompletionCheckbox`'s own
/// doc comment), right-aligned within this list panel exactly like an
/// ordinary capsule's own checkbox is right-aligned within its row.
/// Positioned beside the cluster's member pills, which render through the
/// ordinary timeline slot loop in `timeline_screen.dart` (each pinned to a
/// fixed one-lane-per-member column — see `_withClusterLanes` — so lane
/// order always matches this list's row order: leftmost pill, topmost
/// row). The pills themselves carry no checkbox of their own — confirmed
/// directly, over an earlier pass that put a checkbox next to each pill
/// instead, since that read as if the pill were its own separate task
/// card rather than a plain positional marker for the row here. See
/// docs/DECISIONS.md for the full revision history (this replaced an
/// earlier stacked-icon-badge design).
///
/// **A run can mix real tasks and imported [ExternalCalendarEvent]s as of
/// 2026-09-07** (confirmed directly: "the imported tasks should also
/// stack in the same way as native tasks... otherwise exactly the same,
/// with different styling") — [cluster.blocks] is the authoritative
/// member list this widget iterates, branching per member on its runtime
/// type: a [Task] gets the full [_ClusterTaskRow] (tap opens the detail
/// sheet, checkbox toggles completion, drag/complete callbacks apply); an
/// [ExternalCalendarEvent] gets [_ClusterEventRow] — same title+time
/// shape and row height, but read-only (tap opens the same info sheet
/// every other event display uses, no checkbox at all, muted title color
/// matching every other "this is not an editable Amble object" cue this
/// codebase already establishes for events).
class OverlapClusterBlock extends StatelessWidget {
  const OverlapClusterBlock({
    super.key,
    required this.cluster,
    this.onTaskTap,
    this.onToggleComplete,
    this.fadedTaskId,
    this.compactText = false,
    this.durationVisible = true,
    this.alwaysShowTime = false,
    this.textLayout = TimelineTaskTextLayout.stacked,
    this.showCompletionCheckbox = true,
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

  /// True in List (collapsed) mode — matches [TaskCapsuleBlock.compactText]
  /// exactly: no longer affects font size (List view tracks the same
  /// global "Task size" setting as Task/Zone view), only forces the
  /// inline (time+title, one line) row layout. Defaults to false.
  final bool compactText;

  /// Dev-only toggle (`DevTimelineTaskDurationVisibleProvider`) — matches
  /// [TaskCapsuleBlock.durationVisible] exactly. A real parity gap fixed
  /// here, reported directly: a clustered task's row showed only its time
  /// range, never the `(45m)`-style duration suffix an ordinary
  /// (non-clustered) capsule already shows in the same mode. Defaults to
  /// true (current shipped behavior for a caller that doesn't wire this
  /// up).
  final bool durationVisible;

  /// List mode's own override: forces the time range visible regardless
  /// of [durationVisible], since List mode has no timeline axis at all and
  /// the time is the only place a task's schedule reads — same rule and
  /// same reasoning as [TaskCapsuleTextRow.alwaysShowTime] (the
  /// non-clustered row's equivalent), applied here since a clustered
  /// task's row is a fully separate rendering path that doesn't reuse that
  /// widget. Requested directly, reported as time missing "on list mode."
  /// Defaults to false, so [durationVisible]'s existing Task-view meaning
  /// (hide time entirely) is unchanged for a caller that doesn't wire this
  /// up.
  final bool alwaysShowTime;

  /// Dev-only layout toggle (`DevTimelineTaskTextLayout`) — matches
  /// [TaskCapsuleBlock.textLayout] exactly. Real gap, reported directly:
  /// with `inline` set, an ordinary capsule put time+title on one line
  /// while a clustered row beside it stayed stacked, because this block
  /// never received the setting at all. [compactText] (List mode) still
  /// forces inline regardless of this, exactly as `TaskCapsuleBlock` does.
  final TimelineTaskTextLayout textLayout;

  /// Whether each row's trailing [CompletionCheckbox] renders at all
  /// (`ShowCompletionCheckboxSetting`) — see
  /// [TaskCapsuleBlock.showCompletionCheckbox]. Defaults to true.
  final bool showCompletionCheckbox;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    // List mode previously read a separate, smaller textTaskTitleCompact
    // style here — confirmed directly that List view should track the
    // same global "Task size" setting Task/Zone view do instead, with no
    // relative step.
    final titleTextStyle = theme.textTaskTitle;
    // List mode forces inline; otherwise the dev toggle decides — the same
    // `effectiveTextLayout` rule TaskCapsuleBlock applies to itself.
    final isInline = compactText || textLayout == TimelineTaskTextLayout.inline;

    // No card/rounded-background wrapper, per direct feedback — the
    // rows sit directly on the timeline as plain text, not inside a
    // panel. Padding kept so rows don't sit flush against the pills.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, block) in cluster.blocks.indexed) ...[
            if (index > 0) SizedBox(height: theme.spacingXs),
            if (block case final Task task)
              _ClusterTaskRow(
                theme: theme,
                titleTextStyle: titleTextStyle,
                isInline: isInline,
                durationVisible: durationVisible,
                alwaysShowTime: alwaysShowTime,
                showCompletionCheckbox: showCompletionCheckbox,
                task: task,
                onTap: onTaskTap == null ? null : () => onTaskTap!(task),
                onToggleComplete: onToggleComplete == null
                    ? null
                    : () => onToggleComplete!(task),
                isFaded: task.id == fadedTaskId,
              )
            else if (block case final ExternalCalendarEvent event)
              _ClusterEventRow(
                theme: theme,
                titleTextStyle: titleTextStyle,
                isInline: isInline,
                durationVisible: durationVisible,
                alwaysShowTime: alwaysShowTime,
                event: event,
              ),
          ],
        ],
      ),
    );
  }
}

/// One row inside the cluster's flat list — title + time range, plain
/// text only. No icon, no card, no color background, no proportional
/// height, no indentation, per the settled design (see
/// `OverlapClusterBlock`'s own doc comment for the emoji-tried-then-
/// reverted history); recurring/tracked-behavior indicators are the one
/// exception, shown inline after the title when relevant.
class _ClusterTaskRow extends StatelessWidget {
  const _ClusterTaskRow({
    required this.theme,
    required this.titleTextStyle,
    required this.task,
    required this.onTap,
    required this.onToggleComplete,
    required this.isFaded,
    this.isInline = false,
    this.durationVisible = true,
    this.alwaysShowTime = false,
    this.showCompletionCheckbox = true,
  });

  final AmbleTheme theme;

  /// [OverlapClusterBlock]'s own resolved base/compact title style — see
  /// its `compactText` doc comment.
  final TextStyle titleTextStyle;

  /// Whether this row puts time+title on ONE line rather than
  /// title-then-time-below (2 lines) — true in List mode
  /// ([OverlapClusterBlock.compactText]) and whenever the dev layout
  /// toggle ([OverlapClusterBlock.textLayout]) is `inline`, matching
  /// [TaskCapsuleBlock]'s own `effectiveTextLayout` rule. Requested
  /// directly: "still need to make time and name sit in one line atm it
  /// sits in 2 lines."
  final bool isInline;

  /// See [OverlapClusterBlock.durationVisible].
  final bool durationVisible;

  /// See [OverlapClusterBlock.alwaysShowTime].
  final bool alwaysShowTime;

  /// See [OverlapClusterBlock.showCompletionCheckbox].
  final bool showCompletionCheckbox;
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
    // `durationVisible: false` drops the time ENTIRELY here, not just the
    // `(45m)` suffix — corrected directly ("cluster mode time from-to
    // should also react to setting so not showing if disabled"). Matches
    // the Task view's own split-layout row, which hides its whole
    // time+duration columns under the same setting; leaving the range
    // behind meant a clustered task still showed "04:00 - 05:00" beside
    // an ordinary capsule showing no time at all.
    //
    // `alwaysShowTime` (List mode only — see its own doc comment) forces
    // the time range back on regardless, WITHOUT the `(45m)` suffix, which
    // still depends on `durationVisible` alone — matching
    // `TaskCapsuleTextRow.alwaysShowTime`'s identical split.
    final timeRange = '${start.format(context)} - ${end.format(context)}';
    final withSuffix =
        '$timeRange (${formatDurationLabel(task.durationMinutes!)})';
    final timeLabel = !alwaysShowTime && !durationVisible
        ? null
        : durationVisible
        ? withSuffix
        : timeRange;
    final indicatorIcons = [
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
    ];

    // Time+title on ONE line — in List (collapsed) mode always, and in
    // Task/Zone view whenever the dev layout toggle is `inline`, matching
    // TaskCapsuleBlock's own rule. Requested directly: "still need to make
    // time and name sit in one line atm it sits in 2 lines", then again
    // for the Task view specifically ("clustered tasks ... in task view
    // render in 2 lines"). Otherwise the stacked (title, then time below)
    // 2-line layout below.
    final content = isInline
        ? Row(
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (timeLabel != null)
                        TextSpan(
                          text: '$timeLabel  ',
                          style: titleTextStyle.copyWith(
                            color: theme.colorTextSecondary,
                          ),
                        ),
                      TextSpan(
                        text: task.title,
                        style: titleTextStyle.copyWith(
                          color: theme.colorTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...indicatorIcons,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      task.title,
                      style: titleTextStyle.copyWith(
                        color: theme.colorTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...indicatorIcons,
                ],
              ),
              if (timeLabel != null)
                Text(
                  timeLabel,
                  style: titleTextStyle.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: content,
          ),
        ),
        // Right-aligned, matching where an ordinary capsule's own
        // checkbox sits within its row — the pill itself carries no
        // checkbox any more (see docs/DECISIONS.md), so this is the
        // task's only completion control while it's clustered.
        //
        // Dropped from the Row entirely (not just faded, unlike
        // TaskCapsuleBlock's own copy) when hidden — these rows own no
        // drag gesture, so there's no in-flight hit-testing to preserve,
        // and reclaiming the space keeps the row's text full-width.
        if (showCompletionCheckbox) ...[
          SizedBox(width: theme.spacingSm),
          CompletionCheckbox(
            theme: theme,
            // Fixed color (CompletionCheckbox's own default), not the
            // category's — see task_capsule_block.dart's own copy of this
            // reasoning.
            isCompleted: task.status == TaskStatus.completed,
            onToggle: onToggleComplete,
          ),
        ],
      ],
    );
  }
}

/// The read-only counterpart to [_ClusterTaskRow] for one
/// [ExternalCalendarEvent] pulled into a cluster's flat list — same
/// title+time shape and row height as a task row, so a glance down the
/// merged list reads as one consistent list, but strictly read-only: no
/// completion checkbox, no recurring/tracked-behavior indicators (neither
/// concept applies to an event), tapping only opens the same read-only
/// info sheet [ExternalEventBlock]/`_ZoneExternalEventRow` already use
/// elsewhere ([showExternalCalendarEventInfo]). Title stays in
/// [AmbleTheme.colorTextSecondary], never the bold primary color a real
/// task's title gets — the same "must never look like an editable Amble
/// object" distinction this codebase already makes visually for every
/// other event display.
class _ClusterEventRow extends StatelessWidget {
  const _ClusterEventRow({
    required this.theme,
    required this.titleTextStyle,
    required this.event,
    this.isInline = false,
    this.durationVisible = true,
    this.alwaysShowTime = false,
  });

  final AmbleTheme theme;

  /// [OverlapClusterBlock]'s own resolved base/compact title style — see
  /// its `compactText` doc comment.
  final TextStyle titleTextStyle;

  /// See [_ClusterTaskRow.isInline].
  final bool isInline;

  /// See [OverlapClusterBlock.durationVisible].
  final bool durationVisible;

  /// See [OverlapClusterBlock.alwaysShowTime].
  final bool alwaysShowTime;

  final ExternalCalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final start = TimeOfDay.fromDateTime(event.start);
    final end = TimeOfDay.fromDateTime(event.end);

    // Same durationVisible/alwaysShowTime split as _ClusterTaskRow — see
    // that row's own doc comment for the full reasoning.
    final timeRange = '${start.format(context)} - ${end.format(context)}';
    final durationMinutes = event.end.difference(event.start).inMinutes;
    final withSuffix = '$timeRange (${formatDurationLabel(durationMinutes)})';
    final timeLabel = !alwaysShowTime && !durationVisible
        ? null
        : durationVisible
        ? withSuffix
        : timeRange;

    final content = isInline
        ? Text.rich(
            TextSpan(
              children: [
                if (timeLabel != null)
                  TextSpan(
                    text: '$timeLabel  ',
                    style: titleTextStyle.copyWith(
                      color: theme.colorTextSecondary,
                    ),
                  ),
                TextSpan(
                  text: event.title,
                  style: titleTextStyle.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: titleTextStyle.copyWith(color: theme.colorTextSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (timeLabel != null)
                Text(
                  timeLabel,
                  style: titleTextStyle.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          );

    return GestureDetector(
      onTap: () => showExternalCalendarEventInfo(
        context: context,
        theme: theme,
        event: event,
      ),
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}
