import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/task.dart';
import 'task_repository.dart';

class HiveTaskRepository implements TaskRepository {
  HiveTaskRepository(this._box);

  final Box<Task> _box;

  @override
  List<Task> getTasks() => _box.values.toList();

  @override
  Task? getTaskById(String id) => _box.get(id);

  @override
  Future<void> saveTask(Task task) => _box.put(task.id, task);

  @override
  Future<void> deleteTask(String id) => _box.delete(id);
}
