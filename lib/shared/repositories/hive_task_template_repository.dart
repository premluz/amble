import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/task_template.dart';
import 'task_template_repository.dart';

class HiveTaskTemplateRepository implements TaskTemplateRepository {
  HiveTaskTemplateRepository(this._box);

  final Box<TaskTemplate> _box;

  @override
  List<TaskTemplate> getAll() => _box.values.toList();

  @override
  TaskTemplate? getById(String id) => _box.get(id);

  @override
  Future<void> save(TaskTemplate template) => _box.put(template.id, template);

  @override
  Future<void> delete(String id) => _box.delete(id);
}
