import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/task_template.dart';
import '../repositories/hive_task_template_repository.dart';
import '../repositories/task_template_repository.dart';

part 'task_template_providers.g.dart';

const taskTemplateBoxName = 'task_templates';

@Riverpod(keepAlive: true)
TaskTemplateRepository taskTemplateRepository(Ref ref) {
  final box = Hive.box<TaskTemplate>(taskTemplateBoxName);
  return HiveTaskTemplateRepository(box);
}

/// CRUD state over [TaskTemplateRepository], mirroring [ZoneList]'s shape —
/// the closest existing precedent, since both entities support the full
/// create/list/edit/delete set (unlike [CategoryList], which is create-only).
///
/// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md: this is
/// session-scoped app state read by the Inbox's Templates tab, and
/// `autoDispose` caused a real bug where a notifier's own write could be
/// torn down mid-flight with no listener active.
///
/// Every write to a template goes through here — no feature code touches
/// [TaskTemplateRepository] or Hive directly.
@Riverpod(keepAlive: true)
class TaskTemplateList extends _$TaskTemplateList {
  @override
  List<TaskTemplate> build() {
    return ref.watch(taskTemplateRepositoryProvider).getAll();
  }

  /// Creates a template and returns it, so a caller can act on the new row
  /// without a second lookup — mirrors [CategoryList.createCategory]/
  /// [ZoneList.createZone]'s own "return what was saved" shape.
  Future<TaskTemplate> createTemplate({
    required String title,
    required String categoryId,
    int? durationMinutes,
    String? notes,
    String? behaviorId,
    bool isImportant = false,
  }) async {
    final template = TaskTemplate.create(
      title: title,
      categoryId: categoryId,
      durationMinutes: durationMinutes,
      notes: notes,
      behaviorId: behaviorId,
      isImportant: isImportant,
    );
    await ref.read(taskTemplateRepositoryProvider).save(template);
    _refresh();
    return template;
  }

  Future<void> updateTemplate(TaskTemplate template) async {
    await ref.read(taskTemplateRepositoryProvider).save(template);
    _refresh();
  }

  /// Deletes a template outright — no confirmation prompt and no cascade,
  /// per CONSTITUTION.md's "templates ARE deletable" rule: tasks already
  /// spawned from it keep their (informational-only) `templateId` and are
  /// otherwise entirely unaffected.
  Future<void> deleteTemplate(String id) async {
    await ref.read(taskTemplateRepositoryProvider).delete(id);
    _refresh();
  }

  void _refresh() {
    state = ref.read(taskTemplateRepositoryProvider).getAll();
  }
}
