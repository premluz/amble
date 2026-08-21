import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_category.dart';
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
            category: TaskCategory.health,
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
        category: TaskCategory.work,
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
      category: TaskCategory.admin,
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
      category: TaskCategory.personal,
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
      category: TaskCategory.health,
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
          category: TaskCategory.work,
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
        category: TaskCategory.personal,
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
        category: existing.category,
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
        category: TaskCategory.personal,
      );
      final existing = container.read(taskListProvider).single;
      final conflicting = Task(
        id: existing.id,
        title: 'Imported version — different title',
        category: TaskCategory.work,
      );

      final result = await notifier.importTasks([conflicting]);

      expect(result.imported, 0);
      expect(result.alreadyPresent, 0);
      expect(result.conflicts, 1);
      final stillLocal = container.read(taskListProvider).single;
      expect(stillLocal.title, 'Local version');
      expect(stillLocal.category, TaskCategory.personal);
    });

    test('a mixed batch reports each outcome correctly', () async {
      final notifier = container.read(taskListProvider.notifier);
      await notifier.createTask(
        title: 'Unchanged locally',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        category: TaskCategory.admin,
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
        category: unchanged.category,
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
        category: TaskCategory.health,
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
            category: TaskCategory.work,
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
        category: TaskCategory.work,
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
        category: TaskCategory.work,
      );
      final id = throwingContainer.read(taskListProvider).single.id;

      await notifier.deleteTask(id);

      expect(throwingContainer.read(taskListProvider), isEmpty);
    });
  });
}
