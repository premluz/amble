import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/current_day_provider.dart';
import '../../core/timeline_clock.dart';
import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/type_primitives.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../shared/models/task.dart';
import '../task_detail/task_sheet.dart';
import '../timeline/tasks_on_day.dart';
import 'calendar_span.dart';
import 'calendar_task_style.dart';
import 'week_view.dart' show openDay;

/// One day of the month grid: its date, then its tasks by time (no zones,
/// no time axis). Days outside the month are quiet. The date, or "+N more",
/// opens the day in Day view; a task opens in the side panel.
class MonthDayCell extends ConsumerWidget {
  const MonthDayCell({super.key, required this.day, required this.inMonth});

  final DateTime day;
  final bool inMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final tasks = ref
        .watch(tasksOnDayProvider(day))
        .where((t) => t.scheduledAt != null)
        .toList();
    final shown = tasks.take(CalendarGridTokens.monthVisibleTasks);
    final hidden = tasks.length - shown.length;
    return Padding(
      padding: EdgeInsets.all(theme.spacingXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _DayNumber(day: day, inMonth: inMonth),
          ),
          for (final task in shown) _MonthTaskRow(task: task),
          if (hidden > 0)
            AppPressFeedback(
              ripple: false,
              onTap: () => openDay(ref, day),
              child: Text(
                '+$hidden more',
                style: theme.textCaption.copyWith(
                  color: theme.colorTextSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayNumber extends ConsumerWidget {
  const _DayNumber({required this.day, required this.inMonth});

  final DateTime day;
  final bool inMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final today = isSameDay(day, ref.watch(currentDayProvider));
    final size = theme.sizeButtonXs;
    return AppPressFeedback(
      ripple: false,
      shape: BoxShape.circle,
      onTap: () => openDay(ref, day),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: today
            ? BoxDecoration(color: theme.colorAccent, shape: BoxShape.circle)
            : null,
        child: Text(
          '${day.day}',
          style: theme.textCaption.copyWith(
            fontWeight: today ? TypePrimitives.weightSemibold : null,
            color: today
                ? theme.colorSurfacePrimary
                : inMonth
                ? theme.colorTextSecondary
                : theme.colorTextTertiary,
          ),
        ),
      ),
    );
  }
}

class _MonthTaskRow extends ConsumerWidget {
  const _MonthTaskRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final style = calendarTaskStyle(ref, theme, task);
    final time = timelineClock(
      context,
      TimeOfDay.fromDateTime(task.scheduledAt!),
    );
    return AppPressFeedback(
      onTap: () => showTaskSheet(context, task: task),
      borderRadius: BorderRadius.circular(theme.radiusSm),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacingXs / 2),
        child: Row(
          children: [
            CalendarTaskRail(color: style.fill, height: theme.spacingMd),
            SizedBox(width: theme.spacingXs),
            Text(
              time,
              style: theme.textCaptionMono.copyWith(
                color: theme.colorTextSecondary,
              ),
            ),
            SizedBox(width: theme.spacingXs),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.title(theme.textCaption),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
