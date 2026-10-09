import 'package:amble/core/app_intents/app_intent_service.dart';
import 'package:amble/core/app_intents/intent_task_queries.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/local_date.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/occurrence_store.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/services/quick_capture_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import 'intent_test_store.dart';

void main() {
  late IntentTestStore store;
  late AppIntentService service;
  late DateTime now;
  setUp(() async {
    store = IntentTestStore();
    await store.open();
    now = DateTime.now();
    service = AppIntentService(store.container, now: () => now);
  });
  tearDown(() => store.close());

  test(
    'Add Task uses live categories and the existing complete parser result',
    () async {
      final category = Category.create(
        name: 'Study',
        colorToken: 2,
        emoji: '📚',
      );
      await store.categories.put(category.id, category);
      const input = 'Study Read tomorrow at 9am for 45 mins daily';
      final parsed = parseQuickCapture(input, now: now, categories: [category]);
      await service.handle('addTask', {'text': input});

      // A repeating task is a series: nothing in the task store, and its
      // first occurrence carries the parsed fields.
      expect(store.tasks.values, isEmpty);
      final first = store.container
          .read(occurrenceStoreProvider.notifier)
          .tasksOn(LocalDate.fromDateTime(parsed.scheduledAt!))
          .single;
      expect(first.title, parsed.title);
      expect(first.scheduledAt, parsed.scheduledAt);
      expect(first.durationMinutes, parsed.durationMinutes);
      expect(first.categoryId, category.id);
    },
  );

  test(
    'uncertain Add Task follows Quick Capture fallback without losing text',
    () async {
      final message = await service.handle('addTask', {
        'text': 'Walk every morning',
      });
      expect(message, contains('as a note'));
      final task = store.tasks.values.single;
      expect(task.title, 'Walk every morning');
      expect(task.scheduledAt, isNull);
      expect(task.recurrenceRule, isNull);
    },
  );

  test(
    'Add Note bypasses parsing, persists across reopen, and refreshes UI state',
    () async {
      expect(store.container.read(taskListProvider), isEmpty);
      const input = 'Walk tomorrow at 9am for 30 mins';
      await service.handle('addNote', {'text': input});
      expect(store.container.read(taskListProvider).single.title, input);
      await store.tasks.close();
      store.tasks = await Hive.openBox<Task>('tasks');
      final saved = store.tasks.values.single;
      expect(saved.title, input);
      expect(saved.scheduledAt, isNull);
      expect(saved.durationMinutes, isNull);
      expect(saved.categoryId, isNull);
    },
  );

  test(
    'blank input and invalid parsed duration do not save anything',
    () async {
      await expectLater(
        service.handle('addNote', {'text': '  '}),
        throwsA(isA<AppIntentFailure>()),
      );
      await expectLater(
        service.handle('addTask', {'text': 'Walk tomorrow for 0 mins'}),
        throwsA(isA<AppIntentFailure>()),
      );
      expect(store.tasks.values, isEmpty);
    },
  );

  test(
    'Remove Task cancels just that occurrence of a repeating task',
    () async {
      await service.handle('addTask', {'text': 'Walk tomorrow at 9am daily'});
      final found = await service.handle('findTasks', {'query': 'Walk'});
      final candidates = (found as List).cast<Map<String, Object>>();
      expect(candidates, hasLength(intentTaskWindowDays - 1));

      await service.handle('removeTask', candidates.first);

      final again = await service.handle('findTasks', {'query': 'Walk'});
      expect(again as List, hasLength(candidates.length - 1));
      expect(
        again.map((t) => (t as Map)['id']),
        isNot(contains(candidates.first['id'])),
      );
    },
  );

  test(
    'stale disambiguation selection cannot delete a changed or missing task',
    () async {
      await service.handle('addTask', {'text': 'Walk tomorrow at 9am'});
      final task = store.tasks.values.single;
      final selection = intentTaskData(task);
      task.title = 'Renamed';
      await store.tasks.put(task.id, task);
      await expectLater(
        service.handle('removeTask', selection),
        throwsA(isA<AppIntentFailure>()),
      );
      expect(store.tasks.length, 1);
      await store.tasks.delete(task.id);
      await expectLater(
        service.handle('removeTask', selection),
        throwsA(isA<AppIntentFailure>()),
      );
    },
  );

  test('entity lookup returns exact results and filters saved IDs by current window', () async {
    final today = DateTime(now.year, now.month, now.day, 9);
    for (final entry in [
      ('Walk', today),
      ('Walk dog', today),
      ('Old', DateTime(now.year, now.month, now.day - 1)),
    ]) {
      final task = Task.create(
        title: entry.$1,
        scheduledAt: entry.$2,
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.general,
      );
      await store.tasks.put(task.id, task);
    }
    final found = await service.handle('findTasks', {'query': 'walk'}) as List;
    expect(found, hasLength(1));
    expect((found.single as Map)['title'], 'Walk');
    final all = await service.handle('findTasks', {
      'ids': store.tasks.keys.toList(),
    }) as List;
    expect(all, hasLength(2));
  });

  // Requested directly: "lock behind 21 day trial ability to add new
  // tasks via any route" — the native App Intents are one of those
  // routes. Neither has a widget tree to present a paywall from, so the
  // OS just surfaces why nothing was added — see AppIntentFailure and
  // TaskList.createTask/captureTask's own doc comments.
  group('trial gate', () {
    late IntentTestStore expiredStore;
    late AppIntentService expiredService;

    setUp(() async {
      expiredStore = IntentTestStore();
      await expiredStore.open(
        installDate: DateTime.now().subtract(const Duration(days: 30)),
      );
      expiredService = AppIntentService(expiredStore.container, now: () => now);
    });
    tearDown(() => expiredStore.close());

    test('addTask surfaces AppIntentFailure once the trial has ended, and '
        'creates nothing', () async {
      await expectLater(
        expiredService.handle('addTask', {
          'text': 'Study tomorrow at 9am for 45 mins',
        }),
        throwsA(isA<AppIntentFailure>()),
      );
      expect(expiredStore.container.read(taskListProvider), isEmpty);
    });

    test('addNote surfaces AppIntentFailure once the trial has ended, and '
        'creates nothing', () async {
      await expectLater(
        expiredService.handle('addNote', {'text': 'A note'}),
        throwsA(isA<AppIntentFailure>()),
      );
      expect(expiredStore.container.read(taskListProvider), isEmpty);
    });

    test('addTask succeeds once panta_pro is active despite the trial being '
        'over', () async {
      await expiredStore.close();
      expiredStore = IntentTestStore();
      await expiredStore.open(
        installDate: DateTime.now().subtract(const Duration(days: 30)),
        isPantaPro: true,
      );
      expiredService = AppIntentService(expiredStore.container, now: () => now);

      final message = await expiredService.handle('addTask', {
        'text': 'Walk every morning',
      });
      expect(message, contains('as a note'));
      expect(expiredStore.container.read(taskListProvider), hasLength(1));
    });
  });
}
