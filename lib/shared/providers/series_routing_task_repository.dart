import '../models/occurrence_alert.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';
import 'occurrence_store.dart';

/// Lets every existing `TaskList` write path act on series occurrences
/// shown as tasks: occurrence ids go to [OccurrenceStore] as commands,
/// everything else goes to the real task store unchanged. An occurrence can
/// therefore never be stored as a plain task.
///
/// Only reads by id are routed; [getTasks] stays real-tasks-only, so lists
/// derived from it (Inbox, materialization, notifications) never see
/// occurrences.
class SeriesRoutingTaskRepository implements TaskRepository {
  SeriesRoutingTaskRepository(this._tasks, this._occurrences);

  final TaskRepository _tasks;
  final OccurrenceStore Function() _occurrences;

  @override
  List<Task> getTasks() => _tasks.getTasks();

  @override
  Task? getTaskById(String id) {
    final key = occurrenceKeyFromPayload(id);
    return key == null
        ? _tasks.getTaskById(id)
        : _occurrences().currentTask(key);
  }

  @override
  Future<void> saveTask(Task task) => occurrenceKeyFromPayload(task.id) == null
      ? _tasks.saveTask(task)
      : _occurrences().applyTaskEdit(task);

  @override
  Future<void> deleteTask(String id) => occurrenceKeyFromPayload(id) == null
      ? _tasks.deleteTask(id)
      : _occurrences().cancelOccurrence(id);
}
