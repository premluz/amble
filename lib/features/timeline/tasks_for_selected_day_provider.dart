import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import 'selected_date_provider.dart';

part 'tasks_for_selected_day_provider.g.dart';

/// Tasks scheduled on [selectedDateProvider]'s day, sorted by time. Derived
/// from [taskListProvider] (Phase 1) — reactive to both the underlying task
/// list and day navigation with no manual refresh.
@riverpod
List<Task> tasksForSelectedDay(Ref ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final allTasks = ref.watch(taskListProvider);

  final tasksForDay = allTasks.where((task) {
    final scheduledAt = task.scheduledAt;
    return scheduledAt.year == selectedDate.year &&
        scheduledAt.month == selectedDate.month &&
        scheduledAt.day == selectedDate.day;
  }).toList();

  tasksForDay.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return tasksForDay;
}
