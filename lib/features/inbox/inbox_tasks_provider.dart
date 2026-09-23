import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import 'inbox_section_filter_provider.dart';

part 'inbox_tasks_provider.g.dart';

/// Unscheduled tasks — captured but not yet moved onto the Timeline. Derived
/// from [taskListProvider] (Phase 1), reactive with no manual refresh.
///
/// **2026-09-21 — sorted by [Task.createdAt], newest first**, requested
/// directly ("notes in inbox should have created timestamp if not have
/// already... and recent should be on top"). Replaces the previous
/// stand-in (reversing [HiveTaskRepository.getTasks]'s own Hive
/// insertion order, back when [Task] had no real timestamp field at
/// all) with an explicit sort by the real field — insertion order only
/// ever coincided with creation order by accident, e.g. never after an
/// edit rewrote a row in place. A decorate-sort-undecorate pass, not a
/// bare `List.sort`, since Dart's own `List.sort` is NOT guaranteed
/// stable and two tasks created in the same millisecond (e.g. voice
/// capture's `submit()` looping over several segments) should keep a
/// deterministic relative order across rebuilds.
@riverpod
List<Task> inboxTasks(Ref ref) {
  final allTasks = ref.watch(taskListProvider);
  final unscheduled =
      allTasks.indexed.where((entry) => !entry.$2.isScheduled).toList()
        ..sort((a, b) {
          final byDate = b.$2.createdAt.compareTo(a.$2.createdAt);
          // Tie-break on original list index (reversed, so a later-appended
          // same-instant task still sorts above an earlier one) rather than
          // leaving equal-timestamp tasks in whatever order `sort` happens
          // to leave them in.
          return byDate != 0 ? byDate : b.$1.compareTo(a.$1);
        });
  return [for (final entry in unscheduled) entry.$2];
}

/// [inboxTasks], narrowed by the Inbox's own Section tab row
/// (`inbox_section_filter_provider.dart`) — "All" (the default) returns
/// [inboxTasks] unchanged, "Unfiled" keeps only tasks with no
/// `Task.sectionId`, and a real Section keeps only tasks filed into it.
/// Client-side filtering over the same small in-memory list every other
/// Inbox derivation already uses, not a second repository query.
@riverpod
List<Task> filteredInboxTasks(Ref ref) {
  final tasks = ref.watch(inboxTasksProvider);
  final filter = ref.watch(inboxSectionFilterStateProvider);
  return tasks.where((task) => filter.matches(task.sectionId)).toList();
}
