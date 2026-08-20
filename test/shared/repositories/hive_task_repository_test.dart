import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_category.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

void main() {
  late Box<Task> box;
  late HiveTaskRepository repository;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Task>(
      'test_tasks_${DateTime.now().microsecondsSinceEpoch}',
    );
    repository = HiveTaskRepository(box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  test('saveTask persists and getTaskById retrieves it', () async {
    final task = Task(
      id: 'task-1',
      title: 'Walk',
      scheduledAt: DateTime(2026, 8, 20, 9),
      durationMinutes: 30,
      category: TaskCategory.health,
    );

    await repository.saveTask(task);

    final fetched = repository.getTaskById('task-1');
    expect(fetched, isNotNull);
    expect(fetched!.title, 'Walk');
    expect(fetched.status, TaskStatus.pending);
    expect(fetched.schemaVersion, 1);
  });

  test('getTasks returns all saved tasks', () async {
    await repository.saveTask(
      Task(
        id: 'a',
        title: 'A',
        scheduledAt: DateTime(2026, 8, 20),
        durationMinutes: 15,
        category: TaskCategory.work,
      ),
    );
    await repository.saveTask(
      Task(
        id: 'b',
        title: 'B',
        scheduledAt: DateTime(2026, 8, 20),
        durationMinutes: 15,
        category: TaskCategory.admin,
      ),
    );

    expect(repository.getTasks().length, 2);
  });

  test('deleteTask removes the task', () async {
    await repository.saveTask(
      Task(
        id: 'to-delete',
        title: 'Gone soon',
        scheduledAt: DateTime(2026, 8, 20),
        durationMinutes: 10,
        category: TaskCategory.personal,
      ),
    );

    await repository.deleteTask('to-delete');

    expect(repository.getTaskById('to-delete'), isNull);
  });

  test('Task.create generates a unique client-side UUID', () {
    final a = Task.create(
      title: 'A',
      scheduledAt: DateTime(2026, 8, 20),
      durationMinutes: 10,
      category: TaskCategory.personal,
    );
    final b = Task.create(
      title: 'B',
      scheduledAt: DateTime(2026, 8, 20),
      durationMinutes: 10,
      category: TaskCategory.personal,
    );

    expect(a.id, isNotEmpty);
    expect(a.id, isNot(equals(b.id)));
  });
}
