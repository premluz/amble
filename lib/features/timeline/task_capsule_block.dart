import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_status.dart';
import 'task_category_token_mapping.dart';

/// The capsule-shaped timeline task block — the product's signature visual
/// component. Two columns: a narrow left rail (a tall rounded pill in the
/// category color, stretching for the task's full duration, category icon
/// near its top) and a right column on the surface background carrying the
/// scheduled time (secondary/muted) above the title (bold, primary text
/// color). Consumes only Tier 2 ([AmbleTheme]) — zero hardcoded values.
///
/// Status is reflected visually without shame-coding (design principle 1 —
/// no red "failure" styling for anything but what it literally is):
/// `completed` shows a small checkmark badge and slightly dims the title;
/// `skipped` mutes the pill color; `rescheduled` shows a small neutral
/// "moved" indicator, not a color change. Tapping the block opens [onTap]
/// (the detail sheet); tapping the pill itself toggles completion via
/// [onToggleComplete], kept separate so a quick "done" tap doesn't require
/// opening the full sheet.
///
/// [pixelsPerMinute] controls the pill's height; callers size this against
/// whatever timeline scale is in effect. The pill's top edge represents the
/// task's start time — callers positioning this block should align to the
/// top, not the center, of the rendered height.
///
/// Requires a scheduled [task] (`task.isScheduled == true`) — this renders
/// the Timeline, not the Inbox, so `scheduledAt`/`durationMinutes` are
/// assumed present.
class TaskCapsuleBlock extends StatelessWidget {
  const TaskCapsuleBlock({
    super.key,
    required this.task,
    this.pixelsPerMinute = 1.5,
    this.onTap,
    this.onToggleComplete,
    this.dragPreviewStartsAt,
    this.maxTextWidth,
  });

  final Task task;
  final double pixelsPerMinute;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;

  /// While a drag is in progress, the start time the task would land on if
  /// released now. Non-null only mid-drag: the block then shows that start
  /// time above the pill and the matching end time (start + duration) below
  /// it, so the user can see exactly which slot they're dropping into
  /// rather than eyeballing it against the hour markers.
  final DateTime? dragPreviewStartsAt;

  /// Caps the time/title column's width so a task that shares its slot
  /// with an overlapping neighbour truncates rather than running its text
  /// under the next column's pill. Null means "take the remaining width",
  /// which is correct whenever the task overlaps nothing.
  final double? maxTextWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categoryColor = theme.categoryColors[task.category.token]!;
    final isSkipped = task.status == TaskStatus.skipped;
    final isCompleted = task.status == TaskStatus.completed;
    final isRescheduled = task.status == TaskStatus.rescheduled;

    final badgeColor = isSkipped
        ? theme.colorTaskSkipped
        : isCompleted
        ? theme.colorTaskCompleted
        : categoryColor;

    final badgeSize = theme.spacingXl * 1.5;
    final pillHeight = math.max(
      task.durationMinutes! * pixelsPerMinute,
      badgeSize,
    );

    final timeOfDay = TimeOfDay.fromDateTime(task.scheduledAt!);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggleComplete,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (dragPreviewStartsAt != null) ...[
                    _DragTimeLabel(
                      theme: theme,
                      time: dragPreviewStartsAt!,
                      // Sits just above the pill's top edge — the moment
                      // the task would start.
                      bottom: pillHeight + theme.spacingXs,
                      width: badgeSize,
                    ),
                    _DragTimeLabel(
                      theme: theme,
                      time: dragPreviewStartsAt!.add(
                        Duration(minutes: task.durationMinutes!),
                      ),
                      // Sits just below the pill's base — the moment it
                      // would end, derived from the task's duration.
                      top: pillHeight + theme.spacingXs,
                      width: badgeSize,
                    ),
                  ],
                  Container(
                    width: badgeSize,
                    height: pillHeight,
                    alignment: Alignment.topCenter,
                    padding: EdgeInsets.only(top: theme.spacingXs),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(theme.radiusTaskPill),
                    ),
                    child: Icon(
                      task.category.icon,
                      size: badgeSize * 0.55,
                      color: theme.colorSurfacePrimary,
                    ),
                  ),
                  if (isCompleted)
                    Positioned(
                      right: -theme.spacingXs,
                      top: badgeSize - theme.spacingMd,
                      child: Container(
                        padding: EdgeInsets.all(theme.spacingXs / 2),
                        decoration: BoxDecoration(
                          color: theme.colorTaskCompleted,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorSurfacePrimary,
                            width: theme.borderWidthHairline,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: theme.spacingSm,
                          color: theme.colorSurfacePrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: theme.spacingSm),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxTextWidth ?? double.infinity,
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: theme.spacingXs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            timeOfDay.format(context),
                            style: theme.textCaption.copyWith(
                              color: theme.colorTextSecondary,
                            ),
                          ),
                          if (isRescheduled) ...[
                            SizedBox(width: theme.spacingXs),
                            Icon(
                              Icons.update_rounded,
                              size: theme.spacingSm,
                              color: theme.colorTextSecondary,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        task.title,
                        style: theme.textBody.copyWith(
                          color: isCompleted
                              ? theme.colorTextSecondary
                              : theme.colorTextPrimary,
                          fontWeight: FontWeight.w700,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: theme.colorTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small time chip shown above/below the pill while a task is being
/// dragged, so the drop target's start and end times are readable directly
/// on the block instead of inferred from the hour markers behind it.
class _DragTimeLabel extends StatelessWidget {
  const _DragTimeLabel({
    required this.theme,
    required this.time,
    required this.width,
    this.top,
    this.bottom,
  });

  final AmbleTheme theme;
  final DateTime time;
  final double width;
  final double? top;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      child: SizedBox(
        width: width,
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacingXs,
              vertical: theme.spacingXs / 2,
            ),
            decoration: BoxDecoration(
              color: theme.colorTextPrimary,
              borderRadius: BorderRadius.circular(theme.radiusTaskPill),
            ),
            child: Text(
              TimeOfDay.fromDateTime(time).format(context),
              style: theme.textCaption.copyWith(
                color: theme.colorSurfacePrimary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}
