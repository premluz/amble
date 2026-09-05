import '../models/task_template.dart';

/// Persistence interface for [TaskTemplate], mirroring [ZoneRepository]'s
/// shape. UI and state never call Hive directly — see CONSTITUTION.md's
/// access-pattern rule.
///
/// Unlike [CategoryRepository], this one has a real, unguarded [delete]:
/// nothing references a template once it has been used to spawn a task
/// (the spawned [Task] carries a `templateId`, but that field is
/// informational only and never read for cascade or validation), so there
/// is no orphaned-reference question to defer.
abstract class TaskTemplateRepository {
  List<TaskTemplate> getAll();
  TaskTemplate? getById(String id);
  Future<void> save(TaskTemplate template);
  Future<void> delete(String id);
}
