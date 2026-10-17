import '../../models/task.dart';
import 'assistant_activity.dart';
import 'assistant_args.dart';
import 'assistant_backend.dart';
import 'assistant_categories.dart';
import 'assistant_edit_tool.dart';
import 'assistant_json.dart';
import 'assistant_tool.dart';

/// The tools that change the plan. Offered only with
/// [AssistantPermission.readWrite]. Deliberately narrow: add one task, move
/// one task. No deleting, no series or zone edits.
List<AssistantTool> assistantWriteTools(
  AssistantBackend backend,
  AssistantActivityLog activity,
) {
  final writes = _Writes(backend, activity);
  return [
    AssistantTool(
      name: 'add_task',
      writes: true,
      description:
          'Add one task to Amble at a local start time. Check free time with '
          'get_availability first and confirm with the person before adding '
          'several. If the person has only let Claude see their plan, this '
          'says how to allow changes. Duration '
          '${AssistantLimits.minTaskMinutes}-'
          '${AssistantLimits.maxTaskMinutes} minutes. category is a name '
          'from list_categories; leave it out for none.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'start': {'type': 'string', 'description': 'YYYY-MM-DDTHH:MM local'},
          'duration_minutes': {'type': 'integer'},
          'category': {'type': 'string'},
          'important': {'type': 'boolean'},
        },
        'required': ['title', 'start', 'duration_minutes'],
      },
      run: writes.addTask,
    ),
    AssistantTool(
      name: 'move_task',
      writes: true,
      description:
          'Move one existing task to a new local start time, keeping its '
          'duration. Use the id from get_day or list_tasks. For repeating '
          'tasks use edit_task instead.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'task_id': {'type': 'string'},
          'start': {'type': 'string', 'description': 'YYYY-MM-DDTHH:MM local'},
        },
        'required': ['task_id', 'start'],
      },
      run: writes.moveTask,
    ),
    assistantEditTool(backend, activity),
  ];
}

class _Writes {
  _Writes(this.backend, this.activity);

  final AssistantBackend backend;
  final AssistantActivityLog activity;

  Future<AssistantToolResult> addTask(AssistantArgs args) async {
    final title = args.requireString('title');
    if (title.length > AssistantLimits.maxTitleLength) {
      throw const AssistantToolError(
        'The title is too long (${AssistantLimits.maxTitleLength} characters '
        'at most).',
      );
    }
    final start = _futureStart(args);
    final task = await backend.createTask(
      title: title,
      start: start,
      durationMinutes: args.intOr(
        'duration_minutes',
        AssistantLimits.defaultSlotMinutes,
        min: AssistantLimits.minTaskMinutes,
        max: AssistantLimits.maxTaskMinutes,
      ),
      categoryId: resolveCategoryId(backend, args.optionalString('category')),
      isImportant: args.boolOr('important', false),
    );
    final summary = 'Added "${task.title}", ${friendlyTime(start)}.';
    activity.record(summary, undo: () => backend.removeTask(task));
    return AssistantToolResult(summary: summary, data: _json(task));
  }

  Future<AssistantToolResult> moveTask(AssistantArgs args) async {
    final task = backend.taskById(args.requireString('task_id'));
    if (task == null || !task.isScheduled) {
      throw const AssistantToolError(
        'No scheduled task has that id. Use get_day or list_tasks for ids.',
      );
    }
    if (task.isRecurring) {
      throw const AssistantToolError(
        'That task repeats. Use edit_task with a new start (and scope '
        '"this_and_following" to move the whole series).',
      );
    }
    final from = task.scheduledStart;
    final start = _futureStart(args);
    await backend.moveTask(task, start);
    final summary =
        'Moved "${task.title}" from ${friendlyTime(from)} to '
        '${friendlyTime(start)}.';
    activity.record(summary, undo: () => backend.moveTask(task, from));
    return AssistantToolResult(summary: summary, data: _json(task));
  }

  DateTime _futureStart(AssistantArgs args) {
    final start = args.requireLocalDateTime('start');
    if (start.isBefore(backend.now())) {
      throw const AssistantToolError('That time has already passed.');
    }
    return start;
  }

  Map<String, Object?> _json(Task task) =>
      taskJson(task, {for (final c in backend.categories()) c.id: c});
}
