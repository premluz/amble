import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/local_date.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/occurrence_store.dart';
import '../../shared/providers/task_providers.dart';

/// The tasks on [day], by start time: stored tasks scheduled that day plus
/// the series [occurrences] for it. One definition for every view that shows
/// a day — the Day screen, and the wide layout's week and month grids.
List<Task> tasksScheduledOn(
  Iterable<Task> stored,
  Iterable<Task> occurrences,
  DateTime day,
) {
  final tasks = stored.where((task) {
    final at = task.scheduledAt;
    return at != null &&
        at.year == day.year &&
        at.month == day.month &&
        at.day == day.day;
  }).toList()..addAll(occurrences);
  tasks.sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
  return tasks;
}

/// [tasksScheduledOn] for any date (time of day ignored), kept fresh by the
/// task list and the occurrence store.
final tasksOnDayProvider = Provider.family<List<Task>, DateTime>((ref, day) {
  final stored = ref.watch(taskListProvider);
  ref.watch(occurrenceStoreProvider);
  final occurrences = ref
      .read(occurrenceStoreProvider.notifier)
      .tasksOn(LocalDate.fromDateTime(day));
  return tasksScheduledOn(stored, occurrences, day);
});
