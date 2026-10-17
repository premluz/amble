import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/week_hour_height_setting.dart';
import '../task_detail/category_visual.dart';
import '../task_detail/task_sheet.dart';
import '../timeline/complete_task.dart';
import '../timeline/task_capsule_block.dart';

/// One task's pill in the week grid: the app's own pill (label color,
/// glyph, length shown by height), pill only. Its text is a separate
/// [WeekTaskText], so overlapping pills can pack side by side while every
/// title still shows, as on the Day screen. Read-only: a tap opens the
/// task in the side panel.
class WeekTaskPill extends ConsumerWidget {
  const WeekTaskPill({
    super.key,
    required this.task,
    this.previewStart,
    this.previewMinutes,
  });

  final Task task;

  /// While dragged: the start and length shown instead of the task's own.
  final DateTime? previewStart;
  final int? previewMinutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return SizedBox(
      width: theme.sizeTaskBadge,
      child: TaskCapsuleBlock(
        task: task,
        category: ref
            .watch(categoryListProvider)
            .where((c) => c.id == task.categoryId)
            .firstOrNull,
        pixelsPerMinute:
            ref.watch(weekHourHeightSettingProvider) / Duration.minutesPerHour,
        dragPreviewStartsAt: previewStart,
        durationMinutesOverride: previewMinutes?.toDouble(),
        tagColorStyle: ref.watch(tagColorStyleSettingProvider),
        onTap: () => showTaskSheet(context, task: task),
        splitLayout: true,
        iconsVisible: false,
        showCompletionCheckbox: false,
        swipeActionsEnabled: false,
      ),
    );
  }
}

/// A week task's title, the Day screen's own text row. No time column:
/// the pill's place on the hour grid already shows it, and a week column is
/// too narrow for both. [timeUnderTitleVisible] adds the greyed start-end
/// line under the title, as on the Day screen. The completion checkbox
/// follows the same setting as the Day screen's.
class WeekTaskText extends ConsumerWidget {
  const WeekTaskText({
    super.key,
    required this.task,
    required this.timeUnderTitleVisible,
    this.previewStart,
  });

  final Task task;
  final bool timeUnderTitleVisible;

  /// While dragged: the start the time line shows instead of the task's.
  final DateTime? previewStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final category = ref
        .watch(categoryListProvider)
        .where((c) => c.id == task.categoryId)
        .firstOrNull;
    return TaskCapsuleTextRow(
      task: task,
      labelColor: category == null
          ? null
          : resolveCategoryVisual(theme: theme, category: category).pillColor,
      timeColumnWidth: 0,
      durationColumnWidth: 0,
      durationVisible: false,
      timeUnderTitleVisible: timeUnderTitleVisible,
      dragPreviewStartsAt: previewStart,
      showCompletionCheckbox: ref.watch(showCompletionCheckboxSettingProvider),
      onToggleComplete: () => completeTask(context, ref, task),
      onTap: () => showTaskSheet(context, task: task),
    );
  }
}
