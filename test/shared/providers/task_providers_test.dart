import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_category.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

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
}
