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

    // Regression test for a real bug, reported directly: "still having
    // duplicate created in the same day if editing task that has not
    // repeat on that day, and will save it with repeat on that day..
    // should not create duplicate it's just future days of that select."
    // Anchored to the REAL current day (not a fixed past date, like the
    // test above) — _materializeSeries's window starts from
    // DateTime.now() internally, so a hardcoded past anchor wouldn't
    // exercise "today" at all and could mask this exact bug.
    test('turning on weekly repeat (including today\'s own weekday) for a '
        'task already scheduled TODAY does not create a second task on '
        'that same day', () async {
      final notifier = container.read(taskListProvider.notifier);
      final now = DateTime.now();
      final todayAt9 = DateTime(now.year, now.month, now.day, 9);
      final task = await notifier.createTask(
        title: 'Standup',
        scheduledAt: todayAt9,
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.health,
      );
      expect(task.isRecurring, isFalse);

      await notifier.updateTaskWithNewRecurrence(
        task,
        RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          daysOfWeek: [todayAt9.weekday],
        ),
      );

      final tasks = container.read(taskListProvider);
      final onToday = tasks.where(
        (t) =>
            t.scheduledAt != null &&
            t.scheduledAt!.year == todayAt9.year &&
            t.scheduledAt!.month == todayAt9.month &&
            t.scheduledAt!.day == todayAt9.day,
      );
      expect(
        onToday.length,
        1,
        reason:
            'Exactly the original (now-template) task should occupy '
            'today\'s slot — a second row for the same day is the '
            'reported duplicate.',
      );
      expect(onToday.single.id, task.id);
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

    test('updateTaskWithChangedRecurrence on a FUTURE instance keeps that '
        'instance\'s own field edits (category, duration) instead of '
        'silently discarding them', () async {
      // Real bug, reported directly: editing a future (non-template)
      // instance's category never took effect, and duration edits
      // appeared to revert too. Root cause was
      // _deleteUntouchedFutureInstances deleting the very row just
      // edited (it's still "untouched" by ITS OWN pending/
      // originalScheduledAt-null definition) and _materializeSeries
      // regenerating a fresh copy from the template's OLD values right
      // after — same rule in, same rule out, so nothing about a rule
      // CHANGE was needed to trigger it, just editing a plain field.
      final notifier = container.read(taskListProvider.notifier);
      final today = DateTime.now();
      final anchor = DateTime(today.year, today.month, today.day, 8);
      final template = await notifier.createTask(
        title: 'Journal',
        scheduledAt: anchor,
        durationMinutes: 10,
        categoryId: BuiltInCategoryIds.personal,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      final rule = template.recurrenceRule!;

      final futureInstance = container
          .read(taskListProvider)
          .firstWhere(
            (t) =>
                t.recurrenceId == template.recurrenceId &&
                t.id != template.id &&
                t.scheduledAt!.isAfter(DateTime.now()),
          );
      final editedId = futureInstance.id;

      futureInstance.categoryId = BuiltInCategoryIds.work;
      futureInstance.durationMinutes = 45;
      await notifier.updateTaskWithChangedRecurrence(futureInstance, rule);

      final refreshed = container
          .read(taskListProvider)
          .firstWhere((t) => t.scheduledAt == futureInstance.scheduledAt);
      expect(
        refreshed.id,
        editedId,
        reason:
            'the edited row must survive under its own id, not be '
            'deleted and replaced by a freshly generated one',
      );
      expect(refreshed.categoryId, BuiltInCategoryIds.work);
      expect(refreshed.durationMinutes, 45);

      final refreshedTemplate = container
          .read(taskListProvider)
          .firstWhere((t) => t.id == template.id);
      // Category stays LOCAL to the edited instance — only time and
      // duration are series-level fields under "all future occurrences".
      expect(refreshedTemplate.categoryId, BuiltInCategoryIds.personal);
      // DURATION propagates to the template — updated 2026-09-07, per the
      // confirmed rule: "unless changed time or duration with option
      // 'update all future occurences' [they] would remain as originally
      // set". This assertion previously expected 10 (the template keeping
      // its own duration), which is the behavior that let a duration/time
      // edit silently fail to reach the series at all — the same missing
      // re-anchor that produced the duplicate-series bug. See
      // `updateTaskWithChangedRecurrence`'s own doc comment.
      expect(refreshedTemplate.durationMinutes, 45);
    });

    test('updateTaskThisInstanceOnly saves only the edited instance — the '
        'series template and every other instance are untouched', () async {
      // The "just this occurrence" half of the recurring-edit scope
      // choice — see docs/CONSTITUTION.md's reversal and
      // updateTaskWithChangedRecurrence's own tests above for the
      // "this and future" half, which already ran this same cascade
      // for every recurring field edit before this method existed.
      final notifier = container.read(taskListProvider.notifier);
      final today = DateTime.now();
      final anchor = DateTime(today.year, today.month, today.day, 8);
      final template = await notifier.createTask(
        title: 'Journal',
        scheduledAt: anchor,
        durationMinutes: 10,
        categoryId: BuiltInCategoryIds.personal,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );

      final beforeEdit = container.read(taskListProvider);
      final futureInstance = beforeEdit.firstWhere(
        (t) =>
            t.recurrenceId == template.recurrenceId &&
            t.id != template.id &&
            t.scheduledAt!.isAfter(DateTime.now()),
      );
      final otherFutureInstanceIds = beforeEdit
          .where(
            (t) =>
                t.recurrenceId == template.recurrenceId &&
                t.id != template.id &&
                t.id != futureInstance.id,
          )
          .map((t) => t.id)
          .toSet();
      expect(
        otherFutureInstanceIds,
        isNotEmpty,
        reason:
            'sanity check: the daily series really did generate more '
            'than one future instance to prove untouched',
      );

      final newTime = futureInstance.scheduledAt!.add(const Duration(hours: 2));
      futureInstance.scheduledAt = newTime;
      futureInstance.durationMinutes = 45;
      await notifier.updateTaskThisInstanceOnly(futureInstance);

      final afterEdit = container.read(taskListProvider);
      final refreshed = afterEdit.firstWhere((t) => t.id == futureInstance.id);
      expect(refreshed.scheduledAt, newTime);
      expect(refreshed.durationMinutes, 45);

      // Marked as touched, same signal a drag-reschedule already sets —
      // this is what spares it from a later rule change's prune pass.
      expect(refreshed.originalScheduledAt, isNotNull);

      // The template and every other instance survive under their own,
      // unregenerated ids — no prune, no re-materialize.
      final refreshedTemplate = afterEdit.firstWhere(
        (t) => t.id == template.id,
      );
      expect(refreshedTemplate.durationMinutes, 10);
      final afterEditIds = afterEdit.map((t) => t.id).toSet();
      expect(afterEditIds.containsAll(otherFutureInstanceIds), isTrue);
    });

    test('updateTaskThisInstanceOnly does not overwrite an already-set '
        'originalScheduledAt with the just-moved value', () async {
      final notifier = container.read(taskListProvider.notifier);
      final today = DateTime.now();
      final anchor = DateTime(today.year, today.month, today.day, 8);
      final template = await notifier.createTask(
        title: 'Journal',
        scheduledAt: anchor,
        durationMinutes: 10,
        categoryId: BuiltInCategoryIds.personal,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      final futureInstance = container
          .read(taskListProvider)
          .firstWhere(
            (t) =>
                t.recurrenceId == template.recurrenceId &&
                t.id != template.id &&
                t.scheduledAt!.isAfter(DateTime.now()),
          );
      final firstMoveOriginal = futureInstance.scheduledAt;
      futureInstance.originalScheduledAt = firstMoveOriginal;
      futureInstance.scheduledAt = firstMoveOriginal!.add(
        const Duration(hours: 1),
      );
      await notifier.updateTaskThisInstanceOnly(futureInstance);

      // A second edit, moving it again — originalScheduledAt must keep
      // recording the FIRST real slot, not the intermediate one.
      futureInstance.scheduledAt = firstMoveOriginal.add(
        const Duration(hours: 3),
      );
      await notifier.updateTaskThisInstanceOnly(futureInstance);

      final refreshed = container
          .read(taskListProvider)
          .firstWhere((t) => t.id == futureInstance.id);
      expect(refreshed.originalScheduledAt, firstMoveOriginal);
    });

    test('updateTaskWithChangedRecurrence on TODAY\'s own instance, with its '
        'hour changed in the same save, does not leave a second instance '
        'behind at the series\' original hour', () async {
      final notifier = container.read(taskListProvider.notifier);
      final now = DateTime.now();
      final anchor = DateTime(now.year, now.month, now.day, 8);
      final template = await notifier.createTask(
        title: 'Journal',
        scheduledAt: anchor,
        durationMinutes: 10,
        categoryId: BuiltInCategoryIds.personal,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      final rule = template.recurrenceRule!;

      // The template IS today's own instance here — mirrors editing the
      // series' first/anchor row and moving its hour later the same day,
      // e.g. via the detail form's time wheel, while leaving Repeats on.
      template.scheduledAt = DateTime(now.year, now.month, now.day, 10);
      await notifier.updateTaskWithChangedRecurrence(template, rule);

      final todayRows = container
          .read(taskListProvider)
          .where(
            (t) =>
                t.recurrenceId == template.recurrenceId &&
                t.scheduledAt != null &&
                t.scheduledAt!.year == now.year &&
                t.scheduledAt!.month == now.month &&
                t.scheduledAt!.day == now.day,
          )
          .toList();

      expect(
        todayRows.length,
        1,
        reason:
            'moving the anchor/template instance\'s own hour must not leave '
            'a stray regenerated row behind at the OLD (8am) slot — got: '
            '${todayRows.map((t) => t.scheduledAt).toList()}',
      );
    });

    test('moving a DAILY instance onto the NEXT day\'s own occurrence slot '
        'does not materialize a duplicate into the slot it vacated', () async {
      final notifier = container.read(taskListProvider.notifier);
      final now = DateTime.now();
      final anchor = DateTime(now.year, now.month, now.day, 8);
      final template = await notifier.createTask(
        title: 'Journal',
        scheduledAt: anchor,
        durationMinutes: 10,
        categoryId: BuiltInCategoryIds.personal,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      final rule = template.recurrenceRule!;

      // A future instance, moved by exactly one day so it lands ON the
      // slot the series already generates for the following day. Its
      // originalScheduledAt records the slot it VACATED, mirroring what
      // the detail form now does.
      final instance = container
          .read(taskListProvider)
          .firstWhere(
            (t) =>
                t.recurrenceId == template.recurrenceId && t.id != template.id,
          );
      final vacated = instance.scheduledAt!;
      instance.originalScheduledAt ??= instance.scheduledAt;
      instance.scheduledAt = vacated.add(const Duration(days: 1));
      await notifier.updateTaskWithChangedRecurrence(instance, rule);

      final all = container.read(taskListProvider);
      final perSlot = <String, int>{};
      for (final t in all) {
        final d = t.scheduledAt!;
        final key = '${d.year}-${d.month}-${d.day} ${d.hour}:${d.minute}';
        perSlot[key] = (perSlot[key] ?? 0) + 1;
      }
      final doubled = perSlot.entries.where((e) => e.value > 1).toList();
      expect(
        doubled,
        isEmpty,
        reason: 'two rows landed on the same exact slot: $doubled',
      );
    });

    test(
      'updateTaskWithChangedRecurrence on a NON-template instance, with '
      'its own hour changed in the same save, does not leave a second '
      'instance behind at the series\' anchor hour that same day '
      '(originalScheduledAt set, matching the real edit-form call site)',
      () async {
        final notifier = container.read(taskListProvider.notifier);
        final now = DateTime.now();
        final anchor = DateTime(now.year, now.month, now.day, 8);
        final template = await notifier.createTask(
          title: 'Journal',
          scheduledAt: anchor,
          durationMinutes: 10,
          categoryId: BuiltInCategoryIds.personal,
          recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
        );
        final rule = template.recurrenceRule!;

        // Edit a DIFFERENT (future) row of the series, not the template
        // itself, moving that row's own hour — but keep it scheduled on
        // the SAME calendar day the template's own anchor hour would also
        // generate an occurrence for tomorrow's materialization pass.
        // originalScheduledAt is set here to mirror exactly what
        // _TaskDetailFlowState._save now does before overwriting
        // scheduledAt on a recurring instance — see the real fix's comment
        // at that call site.
        final otherInstance = container
            .read(taskListProvider)
            .firstWhere(
              (t) =>
                  t.recurrenceId == template.recurrenceId &&
                  t.id != template.id,
            );
        final originalDay = otherInstance.scheduledAt!;
        otherInstance.originalScheduledAt ??= otherInstance.scheduledAt;
        otherInstance.scheduledAt = DateTime(
          originalDay.year,
          originalDay.month,
          originalDay.day,
          14,
        );
        await notifier.updateTaskWithChangedRecurrence(otherInstance, rule);

        final sameDayRows = container
            .read(taskListProvider)
            .where(
              (t) =>
                  t.recurrenceId == template.recurrenceId &&
                  t.scheduledAt != null &&
                  t.scheduledAt!.year == originalDay.year &&
                  t.scheduledAt!.month == originalDay.month &&
                  t.scheduledAt!.day == originalDay.day,
            )
            .toList();

        expect(
          sameDayRows.length,
          1,
          reason:
              'moving a non-template instance\'s own hour must not leave a '
              'stray regenerated row behind at the template\'s anchor hour '
              'for the same day — got: '
              '${sameDayRows.map((t) => t.scheduledAt).toList()}',
        );
      },
    );

    test('saving an ALREADY all-days-recurring task with only a category '
        'change does not create a second parallel series — one row per '
        'day, not two', () async {
      final notifier = container.read(taskListProvider.notifier);
      final now = DateTime.now();
      final anchor = DateTime(now.year, now.month, now.day, 8);
      final template = await notifier.createTask(
        title: 'Journal',
        scheduledAt: anchor,
        durationMinutes: 10,
        categoryId: BuiltInCategoryIds.personal,
        recurrenceRule: RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
        ),
      );
      final rule = template.recurrenceRule!;

      final beforeCount = container
          .read(taskListProvider)
          .where((t) => t.recurrenceId == template.recurrenceId)
          .length;

      // The reported flow: open the task, change ONLY the category, save.
      // Nothing about the schedule or the repeat rule changes.
      template.categoryId = BuiltInCategoryIds.work;
      await notifier.updateTaskWithChangedRecurrence(template, rule);

      final all = container.read(taskListProvider);
      final afterCount = all
          .where((t) => t.recurrenceId == template.recurrenceId)
          .length;

      expect(
        all.map((t) => t.recurrenceId).toSet().length,
        1,
        reason:
            'a second recurrenceId means a whole parallel series was '
            'minted alongside the original',
      );
      expect(
        afterCount,
        beforeCount,
        reason:
            'a no-op rule save must be idempotent — got $afterCount '
            'rows, was $beforeCount',
      );

      // And concretely: no single day carries two rows.
      final perDay = <String, int>{};
      for (final t in all) {
        final d = t.scheduledAt!;
        final key = '${d.year}-${d.month}-${d.day}';
        perDay[key] = (perDay[key] ?? 0) + 1;
      }
      final doubled = perDay.entries.where((e) => e.value > 1).toList();
      expect(
        doubled,
        isEmpty,
        reason: 'these days ended up with more than one row: $doubled',
      );
    });

    test('deleting the TEMPLATE as a single occurrence promotes a successor '
        'instead of orphaning the series', () async {
      // Real bug, reported directly: "I removed the original as a single
      // instance and have a read error, but state no element." Removing
      // a template through the "Remove this occurrence" branch (plain
      // deleteTask) left every other instance still carrying the series'
      // recurrenceId — so still reporting isRecurring — with no row
      // carrying the rule, and findSeriesTemplate's firstWhere then threw
      // `Bad state: No element` on the next open of ANY of them.
      final notifier = container.read(taskListProvider.notifier);
      final today = DateTime.now();
      final anchor = DateTime(today.year, today.month, today.day, 9);
      final template = await notifier.createTask(
        title: 'Daily thing',
        scheduledAt: anchor,
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      final seriesId = template.recurrenceId;

      await notifier.deleteTask(template.id);

      final remaining = container.read(taskListProvider);
      final survivors = remaining
          .where((t) => t.recurrenceId == seriesId)
          .toList();
      expect(
        survivors,
        isNotEmpty,
        reason: 'sanity check: the rest of the series still exists',
      );

      final templates = survivors.where((t) => t.isRecurrenceTemplate).toList();
      expect(
        templates,
        hasLength(1),
        reason:
            'exactly one surviving row must carry the rule — zero '
            'orphans the series, more than one duplicates generation',
      );
      // The promoted successor is the earliest survivor, and it keeps
      // the outgoing template's own rule.
      final earliest = survivors.reduce(
        (a, b) => a.scheduledAt!.isBefore(b.scheduledAt!) ? a : b,
      );
      expect(templates.single.id, earliest.id);
      expect(
        templates.single.recurrenceRule?.frequency,
        RecurrenceFrequency.daily,
      );

      // The whole point: an instance can now be resolved (and edited)
      // without throwing.
      expect(
        () => findSeriesTemplate(survivors.first, remaining),
        returnsNormally,
      );
    });

    test('deleting the last remaining row of a series is still a plain '
        'delete (nothing left to promote)', () async {
      final notifier = container.read(taskListProvider.notifier);
      final template = await notifier.createTask(
        title: 'Lonely',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      // Drop every generated instance, leaving only the template.
      for (final task in container.read(taskListProvider)) {
        if (task.id != template.id) {
          await notifier.deleteTask(task.id);
        }
      }
      expect(container.read(taskListProvider), hasLength(1));

      await notifier.deleteTask(template.id);

      expect(container.read(taskListProvider), isEmpty);
    });
  });

  group('rescheduleTaskWithZone', () {
    test('sets zoneId and scheduledAt together, and originalScheduledAt '
        'once, matching rescheduleTask\'s own semantics', () async {
      final notifier = container.read(taskListProvider.notifier);
      final created = await notifier.createTask(
        title: 'Standup',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.work,
      );

      final newTime = DateTime(2026, 8, 20, 7, 30);
      await notifier.rescheduleTaskWithZone(created, newTime, 'zone-1');

      final saved = container
          .read(taskListProvider)
          .firstWhere((t) => t.id == created.id);
      expect(saved.zoneId, 'zone-1');
      expect(saved.scheduledAt, newTime);
      expect(saved.status, TaskStatus.rescheduled);
      expect(saved.originalScheduledAt, DateTime(2026, 8, 20, 9));

      // A second reschedule (e.g. dragged again later) must not overwrite
      // the ALREADY-preserved originalScheduledAt — same guarantee
      // rescheduleTask itself gives.
      final secondTime = DateTime(2026, 8, 20, 8, 0);
      await notifier.rescheduleTaskWithZone(saved, secondTime, 'zone-1');
      final savedAgain = container
          .read(taskListProvider)
          .firstWhere((t) => t.id == created.id);
      expect(savedAgain.originalScheduledAt, DateTime(2026, 8, 20, 9));
    });

    test('a null zoneId clears an existing assignment — dropping a task '
        'back onto the outer axis', () async {
      final notifier = container.read(taskListProvider.notifier);
      final created = await notifier.createTask(
        title: 'Standup',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.work,
      );
      created.zoneId = 'zone-1';
      await notifier.updateTask(created);

      await notifier.rescheduleTaskWithZone(
        created,
        DateTime(2026, 8, 20, 14),
        null,
      );

      final saved = container
          .read(taskListProvider)
          .firstWhere((t) => t.id == created.id);
      expect(saved.zoneId, isNull);
    });
  });

  group('resizeTasksInBatch', () {
    test('applies each task\'s own new duration and leaves scheduledAt/status '
        'untouched — a resize is never a reschedule', () async {
      final notifier = container.read(taskListProvider.notifier);
      final a = await notifier.createTask(
        title: 'A',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );
      final b = await notifier.createTask(
        title: 'B',
        scheduledAt: DateTime(2026, 8, 20, 11),
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.personal,
      );

      await notifier.resizeTasksInBatch({a.id: 45, b.id: 75});

      final tasks = container.read(taskListProvider);
      final savedA = tasks.firstWhere((t) => t.id == a.id);
      final savedB = tasks.firstWhere((t) => t.id == b.id);
      expect(savedA.durationMinutes, 45);
      expect(savedB.durationMinutes, 75);
      expect(savedA.scheduledAt, DateTime(2026, 8, 20, 9));
      expect(savedB.scheduledAt, DateTime(2026, 8, 20, 11));
      expect(savedA.status, TaskStatus.pending);
      expect(savedB.status, TaskStatus.pending);
      expect(savedA.originalScheduledAt, isNull);
      expect(savedB.originalScheduledAt, isNull);
    });

    test('an id with no matching task is silently skipped, other entries '
        'still apply', () async {
      final notifier = container.read(taskListProvider.notifier);
      final a = await notifier.createTask(
        title: 'A',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );

      await notifier.resizeTasksInBatch({a.id: 50, 'no-such-id': 999});

      final saved = container
          .read(taskListProvider)
          .firstWhere((t) => t.id == a.id);
      expect(saved.durationMinutes, 50);
    });

    test('one _refresh at the end — taskListProvider reflects every write '
        'without a manual reload', () async {
      final notifier = container.read(taskListProvider.notifier);
      final a = await notifier.createTask(
        title: 'A',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );
      final b = await notifier.createTask(
        title: 'B',
        scheduledAt: DateTime(2026, 8, 20, 11),
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.personal,
      );

      await notifier.resizeTasksInBatch({a.id: 45, b.id: 75});

      // Read straight from taskListProvider (not the repository) — this
      // is exactly what would fail if resizeTasksInBatch forgot the
      // trailing _refresh() call.
      final tasks = container.read(taskListProvider);
      expect(tasks.firstWhere((t) => t.id == a.id).durationMinutes, 45);
      expect(tasks.firstWhere((t) => t.id == b.id).durationMinutes, 75);
    });
  });

  group('shiftTasksByMinutes', () {
    test('shifts scheduledAt by each task\'s own delta and applies the same '
        'reschedule bookkeeping as an ordinary drag', () async {
      final notifier = container.read(taskListProvider.notifier);
      final a = await notifier.createTask(
        title: 'A',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );
      final b = await notifier.createTask(
        title: 'B',
        scheduledAt: DateTime(2026, 8, 20, 11),
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.personal,
      );

      await notifier.shiftTasksByMinutes({a.id: 30, b.id: -15});

      final tasks = container.read(taskListProvider);
      final savedA = tasks.firstWhere((t) => t.id == a.id);
      final savedB = tasks.firstWhere((t) => t.id == b.id);
      expect(savedA.scheduledAt, DateTime(2026, 8, 20, 9, 30));
      expect(savedB.scheduledAt, DateTime(2026, 8, 20, 10, 45));
      // Same bookkeeping rescheduleTask itself gives — confirmed via
      // AskUserQuestion: a task whose zone moved really did have its
      // own time change.
      expect(savedA.status, TaskStatus.rescheduled);
      expect(savedA.originalScheduledAt, DateTime(2026, 8, 20, 9));
      expect(savedB.status, TaskStatus.rescheduled);
      expect(savedB.originalScheduledAt, DateTime(2026, 8, 20, 11));
    });

    test('a second shift does not overwrite an already-set '
        'originalScheduledAt', () async {
      final notifier = container.read(taskListProvider.notifier);
      final a = await notifier.createTask(
        title: 'A',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );

      await notifier.shiftTasksByMinutes({a.id: 30});
      await notifier.shiftTasksByMinutes({a.id: 15});

      final saved = container
          .read(taskListProvider)
          .firstWhere((t) => t.id == a.id);
      expect(saved.scheduledAt, DateTime(2026, 8, 20, 9, 45));
      expect(saved.originalScheduledAt, DateTime(2026, 8, 20, 9));
    });

    test('an id with no matching task, or a task with no scheduledAt at all, '
        'is silently skipped', () async {
      final notifier = container.read(taskListProvider.notifier);
      final unscheduled = Task.captured(title: 'Inbox item');
      await notifier.updateTask(unscheduled);
      final a = await notifier.createTask(
        title: 'A',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );

      await notifier.shiftTasksByMinutes({
        'no-such-id': 60,
        unscheduled.id: 60,
        a.id: 30,
      });

      final tasks = container.read(taskListProvider);
      expect(
        tasks.firstWhere((t) => t.id == unscheduled.id).scheduledAt,
        isNull,
      );
      expect(
        tasks.firstWhere((t) => t.id == a.id).scheduledAt,
        DateTime(2026, 8, 20, 9, 30),
      );
    });
  });

  group('findOrphanedRecurringTaskIds', () {
    test('a task with no recurrenceId is never orphaned', () {
      final plain = Task.create(
        title: 'Plain',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
      );
      expect(findOrphanedRecurringTaskIds([plain]), isEmpty);
    });

    test('a healthy series (template present) has no orphans', () {
      final template = Task(
        id: 't1',
        title: 'Daily',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
        recurrenceId: 'series-1',
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      final instance = Task(
        id: 't2',
        title: 'Daily',
        scheduledAt: DateTime(2026, 8, 21, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
        recurrenceId: 'series-1',
      );
      expect(findOrphanedRecurringTaskIds([template, instance]), isEmpty);
    });

    test('every instance of a series with no template is orphaned', () {
      final instanceA = Task(
        id: 't2',
        title: 'Daily',
        scheduledAt: DateTime(2026, 8, 21, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
        recurrenceId: 'series-1',
      );
      final instanceB = Task(
        id: 't3',
        title: 'Daily',
        scheduledAt: DateTime(2026, 8, 22, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
        recurrenceId: 'series-1',
      );
      expect(
        findOrphanedRecurringTaskIds([instanceA, instanceB]),
        containsAll(['t2', 't3']),
      );
      expect(
        findOrphanedRecurringTaskIds([instanceA, instanceB]),
        hasLength(2),
      );
    });

    test('a healthy series and an orphaned series in the same list only '
        'flags the orphaned one', () {
      final healthyTemplate = Task(
        id: 't1',
        title: 'Daily',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
        recurrenceId: 'series-healthy',
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      final orphan = Task(
        id: 't2',
        title: 'Weekly',
        scheduledAt: DateTime(2026, 8, 21, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
        recurrenceId: 'series-orphaned',
      );
      expect(findOrphanedRecurringTaskIds([healthyTemplate, orphan]), ['t2']);
    });
  });

  group('dev-only clear tools', () {
    test('clearAllTasks deletes every task', () async {
      final notifier = container.read(taskListProvider.notifier);
      await notifier.createTask(
        title: 'A',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
      );
      await notifier.createTask(
        title: 'B',
        scheduledAt: DateTime(2026, 8, 21, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );
      expect(container.read(taskListProvider), hasLength(2));

      await notifier.clearAllTasks();

      expect(container.read(taskListProvider), isEmpty);
      expect(container.read(taskRepositoryProvider).getTasks(), isEmpty);
    });

    test('clearBadStateTasks removes only the orphaned-recurring rows, '
        'leaving plain and healthy-recurring tasks untouched', () async {
      final notifier = container.read(taskListProvider.notifier);
      final repository = container.read(taskRepositoryProvider);

      final plain = await notifier.createTask(
        title: 'Plain',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
      );
      final healthyTemplate = await notifier.createTask(
        title: 'Daily',
        scheduledAt: DateTime(2026, 8, 21, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      // Manually persist an orphaned instance (a template-less series) —
      // the real bug can't be reproduced through the notifier's own
      // guarded write paths any more, so this simulates pre-existing
      // corrupted data directly at the repository layer.
      final orphan = Task(
        id: 'orphan-1',
        title: 'Orphaned',
        scheduledAt: DateTime(2026, 8, 22, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
        recurrenceId: 'dangling-series',
      );
      await repository.saveTask(orphan);
      container.invalidate(taskListProvider);

      final removedCount = await notifier.clearBadStateTasks();

      expect(removedCount, 1);
      final remaining = container.read(taskListProvider);
      expect(remaining.map((t) => t.id), contains(plain.id));
      expect(remaining.map((t) => t.id), contains(healthyTemplate.id));
      expect(remaining.map((t) => t.id), isNot(contains('orphan-1')));
    });
  });

  group('templateId provenance', () {
    test('createTask records the templateId it was given', () async {
      final created = await container
          .read(taskListProvider.notifier)
          .createTask(
            title: 'Take a walk',
            scheduledAt: DateTime(2026, 8, 20, 9),
            durationMinutes: 30,
            categoryId: BuiltInCategoryIds.health,
            templateId: 'template-1',
          );

      expect(created.templateId, 'template-1');
      expect(box.get(created.id)?.templateId, 'template-1');
    });

    test('createTask leaves templateId null when none is given', () async {
      final created = await container
          .read(taskListProvider.notifier)
          .createTask(
            title: 'Ordinary',
            scheduledAt: DateTime(2026, 8, 20, 9),
            durationMinutes: 30,
            categoryId: BuiltInCategoryIds.work,
          );

      expect(created.templateId, isNull);
      expect(box.get(created.id)?.templateId, isNull);
    });
  });

  /// Regression coverage for the duplicate-series bug reported directly
  /// ("see duplicates, sometimes even 2") and diagnosed from a real
  /// exported backup: 651 tasks, 117 same-`recurrenceId`-same-day groups,
  /// 232 stranded rows. One daily series had THREE complete parallel
  /// 56-day generations (05:00 / 06:30 / 07:05) under a single
  /// `recurrenceId`, one per time-of-day the series had ever been edited
  /// to. See docs/ERROR_LOG.md for the full root-cause writeup.
  group('recurring time change must not duplicate the series', () {
    /// Every instance of [seriesId], grouped by calendar day — the shape
    /// the bug actually manifested in (more than one row per day).
    Map<DateTime, List<Task>> byDay(
      ProviderContainer container,
      String seriesId,
    ) {
      final result = <DateTime, List<Task>>{};
      for (final task in container.read(taskListProvider)) {
        if (task.recurrenceId != seriesId || task.scheduledAt == null) {
          continue;
        }
        final day = DateTime(
          task.scheduledAt!.year,
          task.scheduledAt!.month,
          task.scheduledAt!.day,
        );
        (result[day] ??= []).add(task);
      }
      return result;
    }

    test('changing the time via "all future occurrences" leaves exactly one '
        'instance per day — not a second parallel generation', () async {
      final notifier = container.read(taskListProvider.notifier);
      final today = DateTime.now();
      final anchor = DateTime(today.year, today.month, today.day, 7, 5);
      final template = await notifier.createTask(
        title: 'Stretching',
        scheduledAt: anchor,
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.health,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      final seriesId = template.recurrenceId!;
      final before = byDay(container, seriesId);
      expect(
        before.values.every((day) => day.length == 1),
        isTrue,
        reason: 'precondition: a freshly materialized series is one per day',
      );

      // The exact user action: change the series' time of day, choosing
      // "all future occurrences".
      template.scheduledAt = DateTime(anchor.year, anchor.month, anchor.day, 8);
      await notifier.updateTaskWithChangedRecurrence(
        template,
        template.recurrenceRule!,
      );

      final after = byDay(container, seriesId);
      final duplicated = after.entries
          .where((entry) => entry.value.length > 1)
          .toList();
      expect(
        duplicated,
        isEmpty,
        reason:
            'a time change must re-anchor the series, not generate a '
            'second generation alongside the old one — this is the exact '
            'shape found in the real backup (3 parallel 56-day series '
            'under one recurrenceId)',
      );
      // And the series actually MOVED — the whole point of the edit.
      expect(
        after.values
            .expand((day) => day)
            .every((t) => t.scheduledAt!.hour == 8),
        isTrue,
        reason: 'every future occurrence realigns to the new 08:00 anchor',
      );
    });

    test('repeating the time change three times still leaves one instance '
        'per day — the real backup had three stacked generations', () async {
      final notifier = container.read(taskListProvider.notifier);
      final today = DateTime.now();
      final anchor = DateTime(today.year, today.month, today.day, 5);
      final template = await notifier.createTask(
        title: 'Walk',
        scheduledAt: anchor,
        durationMinutes: 120,
        categoryId: BuiltInCategoryIds.health,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      final seriesId = template.recurrenceId!;

      for (final hour in [6, 7, 9]) {
        final current = container
            .read(taskListProvider)
            .firstWhere((t) => t.id == template.id);
        current.scheduledAt = DateTime(
          anchor.year,
          anchor.month,
          anchor.day,
          hour,
        );
        await notifier.updateTaskWithChangedRecurrence(
          current,
          current.recurrenceRule!,
        );
      }

      final after = byDay(container, seriesId);
      expect(
        after.entries.where((entry) => entry.value.length > 1),
        isEmpty,
        reason: 'three successive time edits must not stack three series',
      );
      expect(
        after.values
            .expand((day) => day)
            .every((t) => t.scheduledAt!.hour == 9),
        isTrue,
        reason: 'the series ends up at the LAST time chosen',
      );
    });

    test('a re-run of the launch top-up after a time change adds nothing — '
        'the prune-free materialize path must stay idempotent', () async {
      final notifier = container.read(taskListProvider.notifier);
      final today = DateTime.now();
      final anchor = DateTime(today.year, today.month, today.day, 7);
      final template = await notifier.createTask(
        title: 'Meditation',
        scheduledAt: anchor,
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.personal,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      final seriesId = template.recurrenceId!;

      template.scheduledAt = DateTime(
        anchor.year,
        anchor.month,
        anchor.day,
        10,
      );
      await notifier.updateTaskWithChangedRecurrence(
        template,
        template.recurrenceRule!,
      );
      final afterEdit = container.read(taskListProvider).length;

      // Simulates restarting the app — reported directly as a trigger
      // ("perhaps restarting app"). This path never prunes, so before the
      // per-day dedup fix any anchor drift refilled the whole window here.
      await notifier.materializeDueRecurrences();
      await notifier.materializeDueRecurrences();

      expect(
        container.read(taskListProvider).length,
        afterEdit,
        reason: 'launch top-ups must be idempotent after a time change',
      );
      expect(
        byDay(container, seriesId).entries.where((e) => e.value.length > 1),
        isEmpty,
      );
    });

    test('"all future" realigns an occurrence the user had moved '
        'individually, but never a completed or skipped one', () async {
      final notifier = container.read(taskListProvider.notifier);
      final today = DateTime.now();
      final anchor = DateTime(today.year, today.month, today.day, 7);
      final template = await notifier.createTask(
        title: 'Journal',
        scheduledAt: anchor,
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.personal,
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      final seriesId = template.recurrenceId!;

      final future =
          container
              .read(taskListProvider)
              .where(
                (t) =>
                    t.recurrenceId == seriesId &&
                    t.id != template.id &&
                    t.scheduledAt!.isAfter(DateTime.now()),
              )
              .toList()
            ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

      // One occurrence individually moved, one completed.
      final moved = future[0];
      await notifier.rescheduleTask(
        moved,
        moved.scheduledAt!.add(const Duration(hours: 5)),
      );
      final done = future[1];
      done.status = TaskStatus.completed;
      await notifier.updateTask(done);

      final current = container
          .read(taskListProvider)
          .firstWhere((t) => t.id == template.id);
      current.scheduledAt = DateTime(anchor.year, anchor.month, anchor.day, 11);
      await notifier.updateTaskWithChangedRecurrence(
        current,
        current.recurrenceRule!,
      );

      final tasks = container.read(taskListProvider);
      // The completed one is untouched — history is never rewritten.
      final refreshedDone = tasks.firstWhere((t) => t.id == done.id);
      expect(refreshedDone.status, TaskStatus.completed);
      expect(refreshedDone.scheduledAt, done.scheduledAt);

      // The individually-moved one is gone, replaced by a realigned
      // occurrence on its day — "change all future" wins (confirmed
      // directly), reversing the old permanent-protection rule.
      final movedDay = DateTime(
        moved.scheduledAt!.year,
        moved.scheduledAt!.month,
        moved.scheduledAt!.day,
      );
      final onMovedDay = tasks
          .where(
            (t) =>
                t.recurrenceId == seriesId &&
                t.scheduledAt != null &&
                DateTime(
                      t.scheduledAt!.year,
                      t.scheduledAt!.month,
                      t.scheduledAt!.day,
                    ) ==
                    movedDay,
          )
          .toList();
      expect(onMovedDay, hasLength(1));
      expect(onMovedDay.single.scheduledAt!.hour, 11);
    });
  });
}
