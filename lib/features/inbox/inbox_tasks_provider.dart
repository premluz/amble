import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';

part 'inbox_tasks_provider.g.dart';

/// Unscheduled tasks — captured but not yet moved onto the Timeline. Derived
/// from [taskListProvider] (Phase 1), reactive with no manual refresh.
@riverpod
List<Task> inboxTasks(Ref ref) {
  final allTasks = ref.watch(taskListProvider);
  return allTasks.where((task) => !task.isScheduled).toList();
}
