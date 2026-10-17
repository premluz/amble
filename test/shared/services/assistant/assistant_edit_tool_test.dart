import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/services/assistant/assistant_activity.dart';
import 'package:amble/shared/services/assistant/assistant_task_edit.dart';
import 'package:amble/shared/services/assistant/assistant_tool.dart';
import 'package:amble/shared/services/assistant/assistant_toolbox.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_assistant_backend.dart';

final _now = DateTime(2026, 10, 12, 8);

void main() {
  late FakeAssistantBackend backend;
  late AssistantActivityLog activity;
  late AssistantPermission permission;
  late AssistantToolbox toolbox;
  late Task task;

  setUp(() {
    backend = FakeAssistantBackend(clock: _now);
    activity = AssistantActivityLog(() => _now);
    permission = AssistantPermission.readWrite;
    toolbox = AssistantToolbox(
      backend: backend,
      activity: activity,
      permission: () => permission,
    );
    task = Task.create(
      title: 'Gym',
      scheduledAt: DateTime(2026, 10, 13, 7),
      durationMinutes: 60,
      categoryId: BuiltInCategoryIds.general,
    );
    backend.tasks.add(task);
  });

  Future<AssistantToolResult> edit(Map<String, Object?> args) =>
      toolbox.call('edit_task', {'task_id': task.id, ...args});

  group('parseRepeat', () {
    test('words and day lists', () {
      expect(parseRepeat('never'), isEmpty);
      expect(parseRepeat('daily'), hasLength(7));
      expect(parseRepeat('weekdays'), {1, 2, 3, 4, 5});
      expect(parseRepeat('weekends'), {6, 7});
      expect(parseRepeat(['mon', 'Wednesday', 'FRI']), {1, 3, 5});
      expect(parseRepeat('mon, thu'), {1, 4});
      expect(describeRepeat({1, 3, 5}), 'Mon, Wed, Fri');
      expect(describeRepeat(parseRepeat('daily')), 'every day');
    });

    test('a bad day is a plain error', () {
      expect(
        () => parseRepeat(['someday']),
        throwsA(isA<AssistantToolError>()),
      );
    });
  });

  test('changes several fields, records an undoable activity', () async {
    final result = await edit({
      'title': 'Gym, legs',
      'start': '2026-10-13T18:00',
      'duration_minutes': 45,
      'category': 'Work',
      'important': true,
      'done': true,
    });
    expect(result.isError, isFalse, reason: result.summary);
    final changed = backend.tasks.single;
    expect(changed.title, 'Gym, legs');
    expect(changed.scheduledAt, DateTime(2026, 10, 13, 18));
    expect(changed.durationMinutes, 45);
    expect(changed.categoryId, BuiltInCategoryIds.work);
    expect(changed.isImportant, isTrue);
    expect(changed.status, TaskStatus.completed);
    expect(result.summary, contains('renamed to "Gym, legs"'));
    expect(result.summary, contains('now Tue 13 Oct, 18:00'));

    await activity.undo(activity.entries.single);
    expect(backend.tasks.single.title, 'Gym');
  });

  test('repeat and scope reach the backend as asked', () async {
    await edit({
      'repeat': ['mon', 'wed'],
      'scope': 'this_and_following',
    });
    final asked = backend.edits.single;
    expect(asked.repeatDays, {DateTime.monday, DateTime.wednesday});
    expect(asked.scope, AssistantEditScope.thisAndFollowing);
  });

  test('notes may be cleared with empty text', () async {
    await edit({'notes': ''});
    expect(backend.edits.single.notes, '');
  });

  test('nothing to change, a past time, an unknown task, a bad scope and '
      'read-only are all refused in plain words', () async {
    final cases = <Map<String, Object?>>[
      {},
      {'start': '2026-10-01T09:00'},
      {'task_id': 'nope', 'title': 'X'},
      {'title': 'X', 'scope': 'everything'},
    ];
    for (final args in cases) {
      final result = await edit(args);
      expect(result.isError, isTrue, reason: '$args');
    }
    permission = AssistantPermission.read;
    final refused = await edit({'title': 'X'});
    expect(refused.summary, contains('See and update my plan'));
    expect(backend.edits, isEmpty);
  });
}
