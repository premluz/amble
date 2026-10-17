import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/services/assistant/assistant_activity.dart';
import 'package:amble/shared/services/assistant/assistant_tool.dart';
import 'package:amble/shared/services/assistant/assistant_toolbox.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_assistant_backend.dart';

// Monday 12 Oct 2026, 08:00.
final _now = DateTime(2026, 10, 12, 8);

void main() {
  late FakeAssistantBackend backend;
  late AssistantActivityLog activity;
  late AssistantPermission permission;
  late AssistantToolbox toolbox;

  setUp(() {
    backend = FakeAssistantBackend(clock: _now);
    activity = AssistantActivityLog(() => _now);
    permission = AssistantPermission.read;
    toolbox = AssistantToolbox(
      backend: backend,
      activity: activity,
      permission: () => permission,
    );
  });

  Task seed(String title, DateTime start, {bool important = false}) {
    final task = Task.create(
      title: title,
      scheduledAt: start,
      durationMinutes: 60,
      categoryId: BuiltInCategoryIds.work,
      isImportant: important,
    );
    backend.tasks.add(task);
    return task;
  }

  group('what the assistant is offered', () {
    test('every tool is offered whatever the permission, so the list '
        'never goes stale in Claude; no delete tool exists', () {
      const all = [
        'get_day',
        'list_tasks',
        'get_availability',
        'list_zones',
        'list_categories',
        'add_task',
        'move_task',
        'edit_task',
      ];
      expect([for (final t in toolbox.available) t.name], all);
      permission = AssistantPermission.readWrite;
      expect([for (final t in toolbox.available) t.name], all);
    });

    test('every tool has a description and an object schema', () {
      permission = AssistantPermission.readWrite;
      for (final tool in toolbox.available) {
        expect(tool.description, isNotEmpty, reason: tool.name);
        expect(tool.inputSchema['type'], 'object', reason: tool.name);
      }
    });
  });

  group('reads', () {
    test('get_availability finds the four one-hour slots', () async {
      for (var day = 12; day <= 16; day++) {
        seed('Morning block', DateTime(2026, 10, day, 7));
        backend.tasks.last.durationMinutes = 300; // 07:00-12:00
      }
      final result = await toolbox.call('get_availability', {
        'from': '2026-10-12',
        'to': '2026-10-16',
        'min_minutes': 60,
      });
      expect(result.isError, isFalse, reason: result.summary);
      final free = (result.data! as Map)['free'] as List;
      expect(free.length, greaterThanOrEqualTo(4));
      expect((free.first as Map)['start'], '2026-10-12T12:00');
    });

    test('get_day lists tasks, zones and free time', () async {
      seed('Standup', DateTime(2026, 10, 12, 9));
      backend.zones.add(
        Zone(id: 'z', title: 'Focus', startMinutes: 600, endMinutes: 720),
      );
      final result = await toolbox.call('get_day', {'date': '2026-10-12'});
      final data = result.data! as Map;
      expect((data['tasks'] as List).single, containsPair('title', 'Standup'));
      expect((data['zones'] as List).single, containsPair('name', 'Focus'));
      expect(data['free'], isNotEmpty);
    });

    test('list_tasks important_only', () async {
      seed('Small', DateTime(2026, 10, 12, 9));
      seed('Big', DateTime(2026, 10, 13, 9), important: true);
      final result = await toolbox.call('list_tasks', {
        'from': '2026-10-12',
        'to': '2026-10-18',
        'important_only': true,
      });
      final tasks = (result.data! as Map)['tasks'] as List;
      expect(tasks.single, containsPair('title', 'Big'));
    });

    test('a range over 31 days is refused in plain words', () async {
      final result = await toolbox.call('list_tasks', {
        'from': '2026-10-01',
        'to': '2026-12-01',
      });
      expect(result.isError, isTrue);
      expect(result.summary, contains('31 days'));
    });

    test('an unknown tool is an error result, not a crash', () async {
      final result = await toolbox.call('delete_everything', {});
      expect(result.isError, isTrue);
    });
  });

  group('writes', () {
    test('refused while the permission is read-only', () async {
      final result = await toolbox.call('add_task', {
        'title': 'Deep work',
        'start': '2026-10-13T10:00',
        'duration_minutes': 60,
      });
      expect(result.isError, isTrue);
      expect(result.summary, contains('See and update my plan'));
      expect(backend.tasks, isEmpty);
    });

    group('with permission', () {
      setUp(() => permission = AssistantPermission.readWrite);

      test('add_task adds, records activity, and undo removes it', () async {
        final result = await toolbox.call('add_task', {
          'title': 'Deep work',
          'start': '2026-10-13T10:00',
          'duration_minutes': 60,
          'category': 'work',
        });
        expect(result.isError, isFalse, reason: result.summary);
        final task = backend.tasks.single;
        expect(task.categoryId, BuiltInCategoryIds.work);
        expect(task.scheduledAt, DateTime(2026, 10, 13, 10));
        expect(activity.entries.single.summary, contains('Deep work'));

        await activity.undo(activity.entries.single);
        expect(backend.tasks, isEmpty);
        expect(
          () => activity.undo(activity.entries.single),
          throwsStateError,
          reason: 'an undo runs once',
        );
      });

      test('add_task with no category uses General', () async {
        await toolbox.call('add_task', {
          'title': 'Call mum',
          'start': '2026-10-13T18:00',
          'duration_minutes': 15,
        });
        expect(backend.tasks.single.categoryId, BuiltInCategoryIds.general);
      });

      test('an unknown category lists the choices', () async {
        final result = await toolbox.call('add_task', {
          'title': 'X',
          'start': '2026-10-13T18:00',
          'duration_minutes': 15,
          'category': 'Gardening',
        });
        expect(result.isError, isTrue);
        expect(result.summary, contains('General, Work'));
      });

      test(
        'a past time, a time zone suffix and a bad duration are refused',
        () async {
          for (final args in [
            {'start': '2026-10-11T10:00', 'duration_minutes': 30},
            {'start': '2026-10-13T10:00Z', 'duration_minutes': 30},
            {'start': '2026-10-13T10:00+02:00', 'duration_minutes': 30},
            {'start': '2026-10-13T10:00', 'duration_minutes': 1},
          ]) {
            final result = await toolbox.call('add_task', {
              'title': 'X',
              ...args,
            });
            expect(result.isError, isTrue, reason: '$args');
          }
          expect(backend.tasks, isEmpty);
        },
      );

      test('the app refusing (trial ended) reaches the assistant', () async {
        backend.trialExpired = true;
        final result = await toolbox.call('add_task', {
          'title': 'X',
          'start': '2026-10-13T10:00',
          'duration_minutes': 30,
        });
        expect(result.summary, contains('trial'));
      });

      test('move_task moves, and undo moves it back', () async {
        final task = seed('Review', DateTime(2026, 10, 13, 15));
        final result = await toolbox.call('move_task', {
          'task_id': task.id,
          'start': '2026-10-14T09:00',
        });
        expect(result.isError, isFalse, reason: result.summary);
        expect(task.scheduledAt, DateTime(2026, 10, 14, 9));

        await activity.undo(activity.entries.single);
        expect(task.scheduledAt, DateTime(2026, 10, 13, 15));
      });

      test('move_task refuses repeating and unknown tasks', () async {
        final repeating = seed('Gym', DateTime(2026, 10, 13, 7))
          ..recurrenceId = 'series';
        for (final id in [repeating.id, 'nope']) {
          final result = await toolbox.call('move_task', {
            'task_id': id,
            'start': '2026-10-14T09:00',
          });
          expect(result.isError, isTrue, reason: id);
        }
        expect(repeating.scheduledAt, DateTime(2026, 10, 13, 7));
      });
    });
  });
}
