import '../models/task.dart';

abstract class TaskRepository {
  List<Task> getTasks();
  Task? getTaskById(String id);
  Future<void> saveTask(Task task);
  Future<void> deleteTask(String id);
}
