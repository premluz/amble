import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/task_state_tokens.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../shared/models/task.dart';
import '../task_detail/task_sheet.dart';
import 'calendar_task_style.dart';

/// One task as a standard calendar block in the week grid
/// (`WeekTaskStyle.blocks`): a tinted block the height of the task, a
/// colour rail on its left, the title and the start-end range. The
/// background is a lighter scale of the colour the pill is filled with
/// (`TaskStateTokens.blockBackground`); the rail is the accent, the same
/// colour as the pill's icon. Its size
/// comes from the parent; read-only, a tap opens the task in the side
/// panel.
class WeekTaskCard extends ConsumerWidget {
  const WeekTaskCard({
    super.key,
    required this.task,
    this.previewStart,
    this.previewMinutes,
  });

  final Task task;

  /// While dragged: the start and length the range shows instead of the
  /// task's own.
  final DateTime? previewStart;
  final int? previewMinutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final style = calendarTaskStyle(ref, theme, task);
    final accent = calendarTaskAccent(ref, theme, task);
    final from = previewStart ?? task.scheduledAt!;
    final start = TimeOfDay.fromDateTime(from);
    final end = TimeOfDay.fromDateTime(
      from.add(Duration(minutes: previewMinutes ?? task.durationMinutes!)),
    );
    final radius = BorderRadius.circular(theme.radiusSm);
    return AppPressFeedback(
      onTap: () => showTaskSheet(context, task: task),
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TaskStateTokens.blockBackground(theme, style.fill),
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: accent,
                child: const SizedBox(width: CalendarGridTokens.railWidth),
              ),
              Expanded(
                child: ClipRect(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.spacingXs,
                      vertical: theme.spacingXs / 2,
                    ),
                    // A short block clips its second line instead of
                    // overflowing.
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      maxHeight: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: style.title(
                              theme.textTaskTitle.copyWith(
                                fontWeight: TaskStateTokens.titleWeight,
                              ),
                            ),
                          ),
                          Text(
                            '${start.format(context)} - ${end.format(context)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TaskStateTokens.timeUnderTitleStyle(theme),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
