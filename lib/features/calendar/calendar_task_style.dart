import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/tokens/task_state_tokens.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/category_providers.dart';
import '../task_detail/category_visual.dart';
import '../timeline/task_state_style.dart';

/// A task's look in the week and month grids: its label color run through
/// the same [TaskStateStyle] every other task row uses, so done, skipped,
/// important and unlabeled read the same here as on the Day screen.
TaskStateStyle calendarTaskStyle(WidgetRef ref, AmbleTheme theme, Task task) {
  final category = ref
      .watch(categoryListProvider)
      .where((c) => c.id == task.categoryId)
      .firstOrNull;
  final label = category == null
      ? TaskStateTokens.unlabeledFill(theme)
      : resolveCategoryVisual(theme: theme, category: category).pillColor;
  return TaskStateStyle.resolve(theme: theme, task: task, labelColor: label);
}

/// The thin rounded label rail at the left of a week block or month row.
class CalendarTaskRail extends StatelessWidget {
  const CalendarTaskRail({super.key, required this.color, this.height});

  final Color color;

  /// Null stretches to the parent's height.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Container(
      width: CalendarGridTokens.railWidth,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(theme.radiusSm),
      ),
    );
  }
}
