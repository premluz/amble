import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/throwing_notification_service.dart';

void main() {
  late Box<Task> box;
  late ProviderContainer container;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_providers');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Task>(
      'test_tasks_${DateTime.now().microsecondsSinceEpoch}',
    );

    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await box.deleteFromDisk();
  });

  test('taskListProvider starts empty', () {
    expect(container.read(taskListProvider), isEmpty);
  });

  test(
    'createTask persists via Task.create and appears in taskListProvider',
    () async {
      await container
          .read(taskListProvider.notifier)
          .createTask(
            title: 'Walk',
            scheduledAt: DateTime(2026, 8, 20, 9),
            durationMinutes: 30,
            categoryId: BuiltInCategoryIds.health,
          );

      final tasks = container.read(taskListProvider);
      expect(tasks, hasLength(1));
      expect(tasks.single.title, 'Walk');
      expect(tasks.single.id, isNotEmpty);
      expect(tasks.single.status, TaskStatus.pending);
    },
  );

  test(
    'updateTask persists the change and taskListProvider reflects it',
    () async {
      final notifier = container.read(taskListProvider.notifier);
      await notifier.createTask(
        title: 'Original title',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );

      final created = container.read(taskListProvider).single;
      created.title = 'Updated title';
      created.status = TaskStatus.completed;
      created.completedAt = DateTime(2026, 8, 20, 9, 15);
      await notifier.updateTask(created);

      final updated = container.read(taskListProvider).single;
      expect(updated.title, 'Updated title');
      expect(updated.status, TaskStatus.completed);
      expect(updated.completedAt, DateTime(2026, 8, 20, 9, 15));

      final repository = container.read(taskRepositoryProvider);
      expect(repository.getTaskById(created.id)!.title, 'Updated title');
    },
  );

  test('deleteTask removes it from persistence and taskListProvider', () async {
    final notifier = container.read(taskListProvider.notifier);
    await notifier.createTask(
      title: 'Ephemeral',
      scheduledAt: DateTime(2026, 8, 20),
      durationMinutes: 10,
      categoryId: BuiltInCategoryIds.admin,
    );
    final id = container.read(taskListProvider).single.id;

    await notifier.deleteTask(id);

    expect(container.read(taskListProvider), isEmpty);
    final repository = container.read(taskRepositoryProvider);
    expect(repository.getTaskById(id), isNull);
  });

  test('taskByIdProvider reflects state without a manual refresh', () async {
    final notifier = container.read(taskListProvider.notifier);
    await notifier.createTask(
      title: 'Findable',
      scheduledAt: DateTime(2026, 8, 20),
      durationMinutes: 20,
      categoryId: BuiltInCategoryIds.personal,
    );
    final id = container.read(taskListProvider).single.id;

    expect(container.read(taskByIdProvider(id))?.title, 'Findable');

    final task = container.read(taskByIdProvider(id))!;
    task.title = 'Renamed';
    await notifier.updateTask(task);

    expect(container.read(taskByIdProvider(id))?.title, 'Renamed');
  });

  test('taskListProvider propagates create/update/delete to a listener without manual refresh', () async {
    final seen = <List<Task>>[];
    container.listen<List<Task>>(
      taskListProvider,
      (previous, next) => seen.add(next),
      fireImmediately: true,
    );

    final notifier = container.read(taskListProvider.notifier);
    await notifier.createTask(
      title: 'Watched',
      scheduledAt: DateTime(2026, 8, 20),
      durationMinutes: 5,
      categoryId: BuiltInCategoryIds.health,
    );
    final id = container.read(taskListProvider).single.id;

    final task = container.read(taskListProvider).single;
    task.status = TaskStatus.skipped;
    await notifier.updateTask(task);

    await notifier.deleteTask(id);

    expect(seen.length, greaterThanOrEqualTo(4));
    expect(seen.first, isEmpty);
    expect(seen[1].single.title, 'Watched');
    expect(seen[2].single.status, TaskStatus.skipped);
    expect(seen.last, isEmpty);
  });

  group('importTasks', () {
    test('writes new tasks (ids not previously seen) and counts them '
        'imported', () async {
      final notifier = container.read(taskListProvider.notifier);
      final incoming = [
        Task.create(
          title: 'Imported A',
          scheduledAt: DateTime(2026, 8, 20, 9),
          durationMinutes: 30,
          categoryId: BuiltInCategoryIds.work,
        ),
        Task.captured(title: 'Imported B'),
      ];

      final result = await notifier.importTasks(incoming);

      expect(result.imported, 2);
      expect(result.alreadyPresent, 0);
      expect(result.conflicts, 0);
      expect(container.read(taskListProvider), hasLength(2));
    });

    test('skips (without rewriting) a task whose id and fields exactly match '
        'an existing local task, counting it as alreadyPresent', () async {
      final notifier = container.read(taskListProvider.notifier);
      await notifier.createTask(
        title: 'Existing',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.personal,
      );
      final existing = container.read(taskListProvider).single;
      final identicalCopy = Task(
        id: existing.id,
        title: existing.title,
        notes: existing.notes,
        scheduledAt: existing.scheduledAt,
        durationMinutes: existing.durationMinutes,
        originalScheduledAt: existing.originalScheduledAt,
        status: existing.status,
        completedAt: existing.completedAt,
        categoryId: existing.categoryId,
        schemaVersion: existing.schemaVersion,
      );

      final result = await notifier.importTasks([identicalCopy]);

      expect(result.imported, 0);
      expect(result.alreadyPresent, 1);
      expect(result.conflicts, 0);
      expect(container.read(taskListProvider), hasLength(1));
      expect(container.read(taskListProvider).single.title, 'Existing');
    });

    test('never overwrites a local task whose id matches but fields differ — '
        'counts it as a conflict and leaves local data untouched', () async {
      final notifier = container.read(taskListProvider.notifier);
      await notifier.createTask(
        title: 'Local version',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.personal,
      );
      final existing = container.read(taskListProvider).single;
      final conflicting = Task(
        id: existing.id,
        title: 'Imported version — different title',
        categoryId: BuiltInCategoryIds.work,
      );

      final result = await notifier.importTasks([conflicting]);

      expect(result.imported, 0);
      expect(result.alreadyPresent, 0);
      expect(result.conflicts, 1);
      final stillLocal = container.read(taskListProvider).single;
      expect(stillLocal.title, 'Local version');
      expect(stillLocal.categoryId, BuiltInCategoryIds.personal);
    });

    test('a mixed batch reports each outcome correctly', () async {
      final notifier = container.read(taskListProvider.notifier);
      await notifier.createTask(
        title: 'Unchanged locally',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.admin,
      );
      final unchanged = container.read(taskListProvider).single;
      final identicalCopy = Task(
        id: unchanged.id,
        title: unchanged.title,
        notes: unchanged.notes,
        scheduledAt: unchanged.scheduledAt,
        durationMinutes: unchanged.durationMinutes,
        originalScheduledAt: unchanged.originalScheduledAt,
        status: unchanged.status,
        completedAt: unchanged.completedAt,
        categoryId: unchanged.categoryId,
        schemaVersion: unchanged.schemaVersion,
      );
      final brandNew = Task.captured(title: 'Brand new import');

      // Exercise "identical" and "new" in one importTasks call, then
      // "conflict" in a second — a real conflict needs a *different*
      // second task sharing an id with something already local, which
      // identicalCopy's id already covers above.
      final firstResult = await notifier.importTasks([identicalCopy, brandNew]);
      expect(firstResult.alreadyPresent, 1);
      expect(firstResult.imported, 1);

      final differentContentSameId = Task(
        id: unchanged.id,
        title: 'Edited elsewhere',
        categoryId: BuiltInCategoryIds.health,
      );
      final secondResult = await notifier.importTasks([differentContentSameId]);
      expect(secondResult.conflicts, 1);
      expect(secondResult.imported, 0);
      expect(secondResult.alreadyPresent, 0);
    });
  });

  group('notification sync failures never block the task write', () {
    late ProviderContainer throwingContainer;

    setUp(() {
      throwingContainer = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
          notificationServiceProvider.overrideWithValue(
            ThrowingNotificationService(),
          ),
        ],
      );
    });

    tearDown(() => throwingContainer.dispose());

    // Regression test for "tap Continue, nothing happens" — an earlier
    // version let a syncForTask exception propagate out of these mutators
    // uncaught, which meant _save() in the UI never reached its
    // Navigator.pop() call. See docs/ERROR_LOG.md.
    test('createTask still persists when notification sync throws', () async {
      await throwingContainer
          .read(taskListProvider.notifier)
          .createTask(
            title: 'New task',
            scheduledAt: DateTime(2026, 8, 20, 9),
            durationMinutes: 30,
            categoryId: BuiltInCategoryIds.work,
          );

      final tasks = throwingContainer.read(taskListProvider);
      expect(tasks, hasLength(1));
      expect(tasks.single.title, 'New task');
    });

    test('updateTask still persists when notification sync throws', () async {
      final notifier = throwingContainer.read(taskListProvider.notifier);
      await notifier.createTask(
        title: 'Original',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );

      final task = throwingContainer.read(taskListProvider).single;
      task.title = 'Edited';
      await notifier.updateTask(task);

      expect(throwingContainer.read(taskListProvider).single.title, 'Edited');
    });

    test('deleteTask still persists when notification cancel throws', () async {
      final notifier = throwingContainer.read(taskListProvider.notifier);
      await notifier.createTask(
        title: 'To delete',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );
      final id = throwingContainer.read(taskListProvider).single.id;

      await notifier.deleteTask(id);

      expect(throwingContainer.read(taskListProvider), isEmpty);
    });
  });

  group('editing recurrence from Task Detail', () {
    test('updateTaskWithNewRecurrence on a previously-plain task materializes '
        'future instances immediately', () async {
      final notifier = container.read(taskListProvider.notifier);
      final task = await notifier.createTask(
        title: 'Stretch',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.health,
      );
      expect(task.isRecurring, isFalse);

      await notifier.updateTaskWithNewRecurrence(
        task,
        RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );

      final tasks = container.read(taskListProvider);
      expect(task.isRecurring, isTrue);
      expect(task.isRecurrenceTemplate, isTrue);
      // The template itself plus real materialized future instances —
      // more than just the one row that existed before this call.
      expect(tasks.length, greaterThan(1));
      expect(
        tasks.where((t) => t.recurrenceId == task.recurrenceId).length,
        greaterThan(1),
      );
    });

    test('updateTaskWithChangedRecurrence narrowing daily down to 5 weekdays '
        'removes the now-excluded untouched future instances', () async {
      final notifier = container.read(taskListProvider.notifier);
      // Anchored to the REAL current day, not a fixed past date —
      // _deleteUntouchedFutureInstances filters on real DateTime.now(),
      // not an injected reference time (unlike the pure generator), so
      // a hardcoded past anchor would make every instance "already in
      // the past" and never a deletion candidate, masking the exact
      // bug this test exists to catch.
      final today = DateTime.now();
      final anchor = DateTime(today.year, today.month, today.day, 8);
      final template = await notifier.createTask(
        title: 'Journal',
        scheduledAt: anchor,
        durationMinutes: 10,
        categoryId: BuiltInCategoryIds.personal,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );

      final beforeChange = container.read(taskListProvider);
      final weekendInstancesBefore = beforeChange.where(
        (t) =>
            t.recurrenceId == template.recurrenceId &&
            (t.scheduledAt!.weekday == DateTime.saturday ||
                t.scheduledAt!.weekday == DateTime.sunday),
      );
      expect(
        weekendInstancesBefore,
        isNotEmpty,
        reason:
            'sanity check: the daily series really did generate '
            'weekend instances before the change',
      );

      await notifier.updateTaskWithChangedRecurrence(
        template,
        RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          daysOfWeek: [1, 2, 3, 4, 5],
        ),
      );

      final afterChange = container.read(taskListProvider);
      final weekendInstancesAfter = afterChange.where(
        (t) =>
            t.recurrenceId == template.recurrenceId &&
            (t.scheduledAt!.weekday == DateTime.saturday ||
                t.scheduledAt!.weekday == DateTime.sunday),
      );
      expect(weekendInstancesAfter, isEmpty);

      // Weekday instances should still exist (regenerated under the new
      // rule), so the series isn't just empty.
      final weekdayInstancesAfter = afterChange.where(
        (t) =>
            t.recurrenceId == template.recurrenceId &&
            t.scheduledAt!.weekday >= DateTime.monday &&
            t.scheduledAt!.weekday <= DateTime.friday,
      );
      expect(weekdayInstancesAfter, isNotEmpty);
    });

    test('updateTaskWithChangedRecurrence updates the TEMPLATE\'s own rule, '
        'not just the edited instance\'s row', () async {
      final notifier = container.read(taskListProvider.notifier);
      final template = await notifier.createTask(
        title: 'Journal',
        scheduledAt: DateTime(2026, 8, 20, 8),
        durationMinutes: 10,
        categoryId: BuiltInCategoryIds.personal,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );

      // Edit from a materialized INSTANCE, not the template itself —
      // this is the common real path (opening a later occurrence from
      // the Timeline, not necessarily the first one).
      final anInstance = container
          .read(taskListProvider)
          .firstWhere(
            (t) =>
                t.recurrenceId == template.recurrenceId && t.id != template.id,
          );

      await notifier.updateTaskWithChangedRecurrence(
        anInstance,
        RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          daysOfWeek: [1, 3, 5],
        ),
      );

      final refreshedTemplate = container
          .read(taskListProvider)
          .firstWhere((t) => t.id == template.id);
      expect(
        refreshedTemplate.recurrenceRule?.frequency,
        RecurrenceFrequency.weekly,
      );
      expect(refreshedTemplate.recurrenceRule?.daysOfWeek, [1, 3, 5]);
    });
  });
}
