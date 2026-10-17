import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock_provider.dart';
import '../../features/timeline/tasks_on_day.dart';
import '../models/category.dart';
import '../models/external_calendar_event.dart';
import '../models/task.dart';
import '../models/zone.dart';
import '../services/assistant/assistant_backend.dart';
import '../services/assistant/assistant_task_edit.dart';
import '../models/occurrence_alert.dart';
import 'assistant_task_editor.dart';
import 'occurrence_store.dart';
import '../services/assistant/assistant_tool.dart';
import '../services/weekly_zone_schedule.dart';
import 'calendar_providers.dart';
import 'category_providers.dart';
import 'task_providers.dart';
import 'trial_providers.dart';
import 'zone_providers.dart';

/// [AssistantBackend] over the app's own providers: the same task list,
/// zones and calendar reads the screens use, so an assistant's change goes
/// through the app's validation and notifications and appears on screen at
/// once. Nothing here touches storage directly.
class AppAssistantBackend implements AssistantBackend {
  AppAssistantBackend(this._ref);

  final Ref _ref;

  @override
  DateTime now() => _ref.read(nowProvider)();

  @override
  List<Task> tasksOn(DateTime day) => _ref.read(tasksOnDayProvider(day));

  @override
  Future<List<ExternalCalendarEvent>> eventsBetween(
    DateTime from,
    DateTime to,
  ) => _ref.read(externalCalendarEventsForRangeProvider(from, to).future);

  @override
  List<Zone> zonesOn(DateTime day) =>
      zonesForDay(_ref.read(zoneListProvider), day);

  @override
  List<Category> categories() => _ref.read(categoryListProvider);

  @override
  Task? taskById(String id) {
    final key = occurrenceKeyFromPayload(id);
    if (key == null) {
      return _ref.read(taskListProvider).where((t) => t.id == id).firstOrNull;
    }
    try {
      return _ref.read(occurrenceStoreProvider.notifier).currentTask(key);
    } on StateError {
      return null; // The series it belonged to no longer exists.
    }
  }

  @override
  Future<Task> createTask({
    required String title,
    required DateTime start,
    required int durationMinutes,
    required String categoryId,
    required bool isImportant,
  }) async {
    try {
      return await _ref
          .read(taskListProvider.notifier)
          .createTask(
            title: title,
            scheduledAt: start,
            durationMinutes: durationMinutes,
            categoryId: categoryId,
            isImportant: isImportant,
          );
    } on TrialExpiredException {
      throw const AssistantToolError(
        'The Amble trial has ended, so no new tasks can be added. The person '
        'can subscribe in Amble.',
      );
    }
  }

  @override
  Future<void> moveTask(Task task, DateTime start) =>
      _ref.read(taskListProvider.notifier).rescheduleTask(task, start);

  @override
  Future<Future<void> Function()?> editTask(
    Task task,
    AssistantTaskEdit edit,
  ) => AssistantTaskEditor(_ref).apply(task, edit);

  @override
  Future<void> removeTask(Task task) =>
      _ref.read(taskListProvider.notifier).deleteTask(task.id);
}
