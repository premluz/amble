import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/task.dart';
import '../models/task_category.dart';
import '../models/task_status.dart';
import '../repositories/hive_task_repository.dart';
import '../repositories/task_repository.dart';

part 'task_providers.g.dart';

const taskBoxName = 'tasks';

@Riverpod(keepAlive: true)
TaskRepository taskRepository(Ref ref) {
  final box = Hive.box<Task>(taskBoxName);
  return HiveTaskRepository(box);
}

@Riverpod(keepAlive: true)
class TaskList extends _$TaskList {
  @override
  List<Task> build() {
    return ref.watch(taskRepositoryProvider).getTasks();
  }

  Future<void> createTask({
    required String title,
    String? notes,
    required DateTime scheduledAt,
    required int durationMinutes,
    required TaskCategory category,
  }) async {
    final task = Task.create(
      title: title,
      notes: notes,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      category: category,
    );
    await ref.read(taskRepositoryProvider).saveTask(task);
    _refresh();
  }

  Future<void> updateTask(Task task) async {
    await ref.read(taskRepositoryProvider).saveTask(task);
    _refresh();
  }

  /// Moves [task] to [newScheduledAt]. Per the Constitution's data model:
  /// `originalScheduledAt` is set only on the *first* reschedule and
  /// preserved afterward (never overwritten), and `status` moves to
  /// `rescheduled`.
  Future<void> rescheduleTask(Task task, DateTime newScheduledAt) async {
    task.originalScheduledAt ??= task.scheduledAt;
    task.scheduledAt = newScheduledAt;
    task.status = TaskStatus.rescheduled;
    await ref.read(taskRepositoryProvider).saveTask(task);
    _refresh();
  }

  /// Toggles [task] between `completed` and `pending`, writing/clearing
  /// `completedAt` alongside `status` per the Constitution (a separate
  /// timestamp from `scheduledAt`, never conflated with it).
  Future<void> toggleComplete(Task task) async {
    if (task.status == TaskStatus.completed) {
      task.status = TaskStatus.pending;
      task.completedAt = null;
    } else {
      task.status = TaskStatus.completed;
      task.completedAt = DateTime.now();
    }
    await ref.read(taskRepositoryProvider).saveTask(task);
    _refresh();
  }

  Future<void> deleteTask(String id) async {
    await ref.read(taskRepositoryProvider).deleteTask(id);
    _refresh();
  }

  void _refresh() {
    state = ref.read(taskRepositoryProvider).getTasks();
  }
}

@riverpod
Task? taskById(Ref ref, String id) {
  final tasks = ref.watch(taskListProvider);
  for (final task in tasks) {
    if (task.id == id) return task;
  }
  return null;
}
