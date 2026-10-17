import '../../models/task.dart';
import 'assistant_activity.dart';
import 'assistant_args.dart';
import 'assistant_backend.dart';
import 'assistant_categories.dart';
import 'assistant_json.dart';
import 'assistant_task_edit.dart';
import 'assistant_tool.dart';

/// `edit_task`: every change Amble's own task editor can make, except
/// deleting. Writes go through the same save paths as the editor, so a
/// repeating task behaves exactly as it does when edited by hand.
AssistantTool assistantEditTool(
  AssistantBackend backend,
  AssistantActivityLog activity,
) => AssistantTool(
  name: 'edit_task',
  writes: true,
  description:
      'Change an existing task: title, start time, duration, category, '
      'important, notes, reminder, done, or how it repeats. Give the id from '
      'get_day or list_tasks and only the fields to change. repeat is '
      '"never", "daily", "weekdays", "weekends" or a list of days like '
      '["mon","wed"]; turning repeat on makes the task a series from its own '
      'day. For a repeating task, scope "this" (default) changes only this '
      'occurrence and "this_and_following" changes it and every later one; '
      'changing the repeat days always applies from this occurrence on. '
      'Confirm with the person before changing a whole series. If the person '
      'has only let Claude see their plan, this says how to allow changes.',
  inputSchema: {
    'type': 'object',
    'properties': {
      'task_id': {'type': 'string'},
      'title': {'type': 'string'},
      'start': {'type': 'string', 'description': 'YYYY-MM-DDTHH:MM local'},
      'duration_minutes': {'type': 'integer'},
      'category': {'type': 'string', 'description': 'From list_categories.'},
      'important': {'type': 'boolean'},
      'notes': {'type': 'string', 'description': 'Empty text clears them.'},
      'reminder': {'type': 'boolean'},
      'done': {'type': 'boolean'},
      'repeat': {
        'description': '"never", "daily", "weekdays", "weekends" or days.',
        'anyOf': [
          {'type': 'string'},
          {
            'type': 'array',
            'items': {'type': 'string'},
          },
        ],
      },
      'scope': {
        'type': 'string',
        'enum': ['this', 'this_and_following'],
      },
    },
    'required': ['task_id'],
  },
  run: (args) => _edit(backend, activity, args),
);

Future<AssistantToolResult> _edit(
  AssistantBackend backend,
  AssistantActivityLog activity,
  AssistantArgs args,
) async {
  final task = backend.taskById(args.requireString('task_id'));
  if (task == null || !task.isScheduled) {
    throw const AssistantToolError(
      'No scheduled task has that id. Use get_day or list_tasks for ids.',
    );
  }
  final edit = _readEdit(backend, args);
  if (edit.isEmpty) {
    throw const AssistantToolError('Say what to change about the task.');
  }
  final title = task.title;
  final undo = await backend.editTask(task, edit);
  final summary = 'Updated "$title": ${_describe(edit, task)}.';
  activity.record(summary, undo: undo);
  final updated = backend.taskById(task.id);
  return AssistantToolResult(
    summary: summary,
    data: updated == null
        ? null
        : taskJson(updated, {for (final c in backend.categories()) c.id: c}),
  );
}

AssistantTaskEdit _readEdit(AssistantBackend backend, AssistantArgs args) {
  final title = args.optionalString('title');
  if (title != null && title.length > AssistantLimits.maxTitleLength) {
    throw const AssistantToolError(
      'The title is too long (${AssistantLimits.maxTitleLength} characters '
      'at most).',
    );
  }
  final start = args['start'] == null
      ? null
      : args.requireLocalDateTime('start');
  if (start != null && start.isBefore(backend.now())) {
    throw const AssistantToolError('That time has already passed.');
  }
  final category = args.optionalString('category');
  return AssistantTaskEdit(
    title: title,
    start: start,
    durationMinutes: args['duration_minutes'] == null
        ? null
        : args.intOr(
            'duration_minutes',
            AssistantLimits.defaultSlotMinutes,
            min: AssistantLimits.minTaskMinutes,
            max: AssistantLimits.maxTaskMinutes,
          ),
    categoryId: category == null ? null : resolveCategoryId(backend, category),
    important: _optionalBool(args, 'important'),
    notes: _notes(args),
    reminder: _optionalBool(args, 'reminder'),
    done: _optionalBool(args, 'done'),
    repeatDays: args['repeat'] == null ? null : parseRepeat(args['repeat']),
    scope: switch (args.optionalString('scope')) {
      null || 'this' => AssistantEditScope.thisOnly,
      'this_and_following' => AssistantEditScope.thisAndFollowing,
      final other => throw AssistantToolError(
        '"scope" must be "this" or "this_and_following", not "$other".',
      ),
    },
  );
}

/// Notes may be empty (that clears them), unlike other text fields.
String? _notes(AssistantArgs args) {
  final value = args['notes'];
  if (value == null) return null;
  if (value is String) return value.trim();
  throw const AssistantToolError('"notes" must be text.');
}

bool? _optionalBool(AssistantArgs args, String key) =>
    args[key] == null ? null : args.boolOr(key, false);

/// What changed, in the words the activity list and Undo toast show.
String _describe(AssistantTaskEdit edit, Task task) {
  final changes = [
    if (edit.title != null) 'renamed to "${edit.title}"',
    if (edit.start != null) 'now ${friendlyTime(edit.start!)}',
    if (edit.durationMinutes != null) '${edit.durationMinutes} min',
    if (edit.categoryId != null) 'new category',
    if (edit.important != null)
      edit.important! ? 'marked important' : 'no longer important',
    if (edit.notes != null) edit.notes!.isEmpty ? 'notes cleared' : 'notes',
    if (edit.reminder != null) edit.reminder! ? 'reminder on' : 'reminder off',
    if (edit.done != null) edit.done! ? 'done' : 'not done',
    if (edit.repeatDays != null)
      edit.repeatDays!.isEmpty
          ? 'no longer repeats'
          : 'repeats ${describeRepeat(edit.repeatDays!)}',
  ];
  final reach =
      task.isRecurring && edit.scope == AssistantEditScope.thisAndFollowing
      ? ' (this and later ones)'
      : '';
  return '${changes.join(', ')}$reach';
}
