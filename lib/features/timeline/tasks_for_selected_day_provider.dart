import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/models/local_date.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/occurrence_store.dart';
import '../../shared/providers/task_providers.dart';
import 'selected_date_provider.dart';
import 'tasks_on_day.dart';

part 'tasks_for_selected_day_provider.g.dart';

/// Tasks scheduled on [selectedDateProvider]'s day, sorted by time. Derived
/// from [taskListProvider] (Phase 1) — reactive to both the underlying task
/// list and day navigation with no manual refresh.
@riverpod
List<Task> tasksForSelectedDay(Ref ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final allTasks = ref.watch(taskListProvider);

  // Series occurrences join the day as read-through tasks; their writes
  // route back to the series model (see `SeriesRoutingTaskRepository`).
  // Watching the store keeps the day fresh after each series command.
  ref.watch(occurrenceStoreProvider);
  return tasksScheduledOn(
    allTasks,
    ref
        .read(occurrenceStoreProvider.notifier)
        .tasksOn(LocalDate.fromDateTime(selectedDate)),
    selectedDate,
  );
}
