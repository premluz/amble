import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_status.dart';
import 'task_category_token_mapping.dart';

/// The capsule-shaped timeline task block — the product's signature visual
/// component. Two columns: a narrow left rail (the category icon badge,
/// connected downward by a thin, subtle-gray connector line sized by
/// duration), and a right column on the surface background carrying the
/// scheduled time (secondary/muted) above the title (bold, primary text
/// color). Consumes only Tier 2 ([AmbleTheme]) — zero hardcoded values.
///
/// Status is reflected visually without shame-coding (design principle 1 —
/// no red "failure" styling for anything but what it literally is):
/// `completed` shows a small checkmark badge and slightly dims the title;
/// `skipped` mutes the badge/connector color; `rescheduled` shows a small
/// neutral "moved" indicator, not a color change. Tapping the block opens
/// [onTap] (the detail sheet); tapping the badge itself toggles completion
/// via [onToggleComplete], kept separate so a quick "done" tap doesn't
/// require opening the full sheet.
///
/// [pixelsPerMinute] controls the connector's height; callers size this
/// against whatever timeline scale is in effect.
class TaskCapsuleBlock extends StatelessWidget {
  const TaskCapsuleBlock({
    super.key,
    required this.task,
    this.pixelsPerMinute = 1.5,
    this.onTap,
    this.onToggleComplete,
  });

  final Task task;
  final double pixelsPerMinute;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;

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
    final connectorWidth = theme.borderWidthHairline;
    final minConnectorHeight = theme.spacingLg;
    final connectorHeight = math.max(
      task.durationMinutes * pixelsPerMinute,
      minConnectorHeight,
    );

    final timeOfDay = TimeOfDay.fromDateTime(task.scheduledAt);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: badgeSize,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: onToggleComplete,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: badgeSize,
                          height: badgeSize,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
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
                            bottom: -theme.spacingXs,
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
                  Container(
                    width: connectorWidth,
                    height: connectorHeight,
                    decoration: BoxDecoration(
                      color: theme.colorBorder,
                      borderRadius: BorderRadius.circular(theme.radiusCard),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: theme.spacingSm),
            Expanded(
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
          ],
        ),
      ),
    );
  }
}
