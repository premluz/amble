import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/purchases_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/trial_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/slow_cancel_notification_service.dart';
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

  // Requested directly: "lock behind 21 day trial ability to add new
  // tasks via any route." createTask/captureTask are the only two
  // methods that ever persist a brand-new Task, so the gate lives here —
  // see their own doc comments and trial_providers.dart. A dedicated
  // container (not the shared one from setUp) makes the expired-trial
  // state explicit rather than depending on installDateProvider's own
  // "not recorded = day zero" default.
  group('trial gate', () {
    late Box<dynamic> preferencesBox;
    late ProviderContainer expiredContainer;

    setUp(() async {
      preferencesBox = await Hive.openBox<dynamic>(
        'test_preferences_${DateTime.now().microsecondsSinceEpoch}',
      );
      await preferencesBox.put(
        PreferenceKeys.installDate,
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      );
      expiredContainer = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(preferencesBox),
          ),
          isPantaProProvider.overrideWithValue(false),
        ],
      );
    });

    tearDown(() async {
      expiredContainer.dispose();
      await preferencesBox.deleteFromDisk();
    });

    test('createTask throws TrialExpiredException once the trial has ended '
        'and panta_pro is not active', () async {
      expect(
        () => expiredContainer
            .read(taskListProvider.notifier)
            .createTask(
              title: 'Should not save',
              scheduledAt: DateTime(2026, 8, 20, 9),
              durationMinutes: 30,
              categoryId: BuiltInCategoryIds.work,
            ),
        throwsA(isA<TrialExpiredException>()),
      );
      expect(expiredContainer.read(taskListProvider), isEmpty);
    });

    test('captureTask throws TrialExpiredException once the trial has ended '
        'and panta_pro is not active', () async {
      expect(
        () => expiredContainer
            .read(taskListProvider.notifier)
            .captureTask('Should not save'),
        throwsA(isA<TrialExpiredException>()),
      );
      expect(expiredContainer.read(taskListProvider), isEmpty);
    });

    test('createTask succeeds once panta_pro is active despite the trial being over', () async {
      expiredContainer.updateOverrides([
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(preferencesBox),
        ),
        isPantaProProvider.overrideWithValue(true),
      ]);

      await expiredContainer
          .read(taskListProvider.notifier)
          .createTask(
            title: 'Pro unlocked',
            scheduledAt: DateTime(2026, 8, 20, 9),
            durationMinutes: 30,
            categoryId: BuiltInCategoryIds.work,
          );

      expect(expiredContainer.read(taskListProvider), hasLength(1));
    });
  });

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
        // A REAL "already imported this exact backup" case carries the
        // same createdAt as the local row — hasSameFieldsAs compares it
        // like every other field (confirmed directly, over excluding it
        // as pure metadata), so a fixture standing in for "the same task,
        // re-imported" must copy it too, same as every field above it.
        createdAt: existing.createdAt,
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
        // See the earlier "identicalCopy" fixture's own comment above.
        createdAt: unchanged.createdAt,
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

  group('deleteTasksInBatch', () {
    test('removes every id, and taskListProvider reflects all of them at '
        'once', () async {
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
      final c = await notifier.createTask(
        title: 'C',
        scheduledAt: DateTime(2026, 8, 20, 13),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.health,
      );

      await notifier.deleteTasksInBatch([a.id, b.id]);

      final remaining = container.read(taskListProvider);
      expect(remaining, hasLength(1));
      expect(remaining.single.id, c.id);
    });

    test('an id with no matching task is silently skipped, the rest still '
        'delete', () async {
      final notifier = container.read(taskListProvider.notifier);
      final a = await notifier.createTask(
        title: 'A',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );

      await notifier.deleteTasksInBatch([a.id, 'no-such-id']);

      expect(container.read(taskListProvider), isEmpty);
    });

    // Regression test for "one disappears instant, then after a long delay
    // the others" — reported directly, and still happening after this
    // method already shared a single _refresh. The remaining cause was
    // `cancelForTask` (a real platform-channel round trip) being awaited
    // once per row INSIDE the delete loop, so the wait scaled with the
    // number of selected rows.
    //
    // The slow fake below makes a blocking implementation fail loudly: if
    // the cancels were still awaited in-loop, this delete could not
    // possibly return before they finished, and the rows would not yet be
    // gone from taskListProvider when the await resolves.
    test('does not block on notification cancellation — the rows are gone '
        'before the (slow) cancels finish', () async {
      final slowService = SlowCancelNotificationService();
      final slowContainer = ProviderContainer(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
          notificationServiceProvider.overrideWithValue(slowService),
        ],
      );
      addTearDown(slowContainer.dispose);

      final notifier = slowContainer.read(taskListProvider.notifier);
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

      await notifier.deleteTasksInBatch([a.id, b.id]);

      // Both rows are already gone even though not one cancel has been
      // allowed to complete yet.
      expect(slowContainer.read(taskListProvider), isEmpty);
      expect(slowService.completedCancels, isZero);

      // The cancels still happen — they're deferred, not dropped.
      slowService.releaseCancels();
      await Future<void>.delayed(Duration.zero);
      expect(slowService.cancelledIds, containsAll([a.id, b.id]));
    });

    test(
      'a cancel failure never stops the remaining rows from deleting',
      () async {
        final throwingOnCancel = ProviderContainer(
          overrides: [
            taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
            notificationServiceProvider.overrideWithValue(
              ThrowingNotificationService(),
            ),
          ],
        );
        addTearDown(throwingOnCancel.dispose);

        final notifier = throwingOnCancel.read(taskListProvider.notifier);
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

        await notifier.deleteTasksInBatch([a.id, b.id]);

        expect(throwingOnCancel.read(taskListProvider), isEmpty);
      },
    );
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
}
