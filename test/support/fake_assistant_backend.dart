import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/services/assistant/assistant_backend.dart';
import 'package:amble/shared/services/assistant/assistant_task_edit.dart';
import 'package:amble/shared/services/assistant/assistant_tool.dart';

/// In-memory [AssistantBackend]: plain lists a test seeds directly.
class FakeAssistantBackend implements AssistantBackend {
  FakeAssistantBackend({required this.clock});

  DateTime clock;
  final tasks = <Task>[];
  final events = <ExternalCalendarEvent>[];

  /// Zones that apply every day.
  final zones = <Zone>[];
  final categoryList = <Category>[
    Category(
      id: BuiltInCategoryIds.general,
      name: 'General',
      colorToken: 0,
      emoji: '',
    ),
    Category(
      id: BuiltInCategoryIds.work,
      name: 'Work',
      colorToken: 1,
      emoji: '',
    ),
  ];
  bool trialExpired = false;

  @override
  DateTime now() => clock;

  @override
  List<Task> tasksOn(DateTime day) => [
    for (final t in tasks)
      if (t.isScheduled &&
          t.scheduledStart.year == day.year &&
          t.scheduledStart.month == day.month &&
          t.scheduledStart.day == day.day)
        t,
  ];

  @override
  Future<List<ExternalCalendarEvent>> eventsBetween(
    DateTime from,
    DateTime to,
  ) async => [
    for (final e in events)
      if (e.start.isBefore(to) && e.end.isAfter(from)) e,
  ];

  @override
  List<Zone> zonesOn(DateTime day) => zones;

  @override
  List<Category> categories() => categoryList;

  @override
  Task? taskById(String id) => tasks.where((t) => t.id == id).firstOrNull;

  @override
  Future<Task> createTask({
    required String title,
    required DateTime start,
    required int durationMinutes,
    required String categoryId,
    required bool isImportant,
  }) async {
    if (trialExpired) {
      throw const AssistantToolError('Your Amble trial has ended.');
    }
    final task = Task.create(
      title: title,
      scheduledAt: start,
      durationMinutes: durationMinutes,
      categoryId: categoryId,
      isImportant: isImportant,
    );
    tasks.add(task);
    return task;
  }

  @override
  Future<void> moveTask(Task task, DateTime start) async =>
      task.scheduledAt = start;

  @override
  Future<void> removeTask(Task task) async => tasks.remove(task);

  /// Every edit received, for tests to inspect.
  final edits = <AssistantTaskEdit>[];

  /// Applies plain field edits in memory; repeat and scope are recorded only
  /// (the real series paths are tested against the real providers).
  @override
  Future<Future<void> Function()?> editTask(
    Task task,
    AssistantTaskEdit edit,
  ) async {
    edits.add(edit);
    final before = Task.fromJson(task.toJson());
    task
      ..title = edit.title ?? task.title
      ..scheduledAt = edit.start ?? task.scheduledAt
      ..durationMinutes = edit.durationMinutes ?? task.durationMinutes
      ..categoryId = edit.categoryId ?? task.categoryId
      ..isImportant = edit.important ?? task.isImportant;
    if (edit.done != null) {
      task.status = edit.done! ? TaskStatus.completed : TaskStatus.pending;
    }
    return () async {
      tasks
        ..remove(task)
        ..add(before);
    };
  }
}
