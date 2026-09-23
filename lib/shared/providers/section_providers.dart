import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/section.dart';
import '../repositories/hive_section_repository.dart';
import '../repositories/section_repository.dart';
import 'task_providers.dart';

part 'section_providers.g.dart';

const sectionBoxName = 'sections';

@Riverpod(keepAlive: true)
SectionRepository sectionRepository(Ref ref) {
  final box = Hive.box<Section>(sectionBoxName);
  return HiveSectionRepository(box);
}

/// CRUD state over [SectionRepository], mirroring [CategoryList]'s shape.
///
/// `keepAlive: true` — same reasoning as [CategoryList]: session-scoped
/// app state read by both the Inbox's own tab row and its create-section
/// prompt, not screen-scoped state.
///
/// No seeded/built-in rows — unlike [CategoryList], every [Section] is
/// user-created (requested directly), so there is no equivalent of
/// [BuiltInCategoryIds] or a seed/backfill step to run at launch.
@Riverpod(keepAlive: true)
class SectionList extends _$SectionList {
  @override
  List<Section> build() {
    return ref.watch(sectionRepositoryProvider).getSections();
  }

  /// Creates a user-defined section and returns it, so a caller (the
  /// Inbox's own "+" create prompt) can select it immediately without a
  /// second lookup — mirrors [CategoryList.createCategory]'s own "return
  /// what was saved" shape.
  Future<Section> createSection({required String name}) async {
    final section = Section.create(name: name);
    await ref.read(sectionRepositoryProvider).saveSection(section);
    _refresh();
    return section;
  }

  Future<void> renameSection(String id, String name) async {
    final section = ref.read(sectionRepositoryProvider).getSectionById(id);
    if (section == null) return;
    section.name = name;
    await ref.read(sectionRepositoryProvider).saveSection(section);
    _refresh();
  }

  /// Re-saves [section] as-is — the Undo restore path for
  /// [deleteSection] (`inbox_section_tabs.dart`'s own long-press menu),
  /// mirroring `TaskList.updateTask`'s own "plain keyed re-save, since
  /// Hive keys by id" role in every other delete-with-undo flow in this
  /// app (see `task_remove.dart`'s `removeTask` doc comment). Does NOT
  /// restore any `Task.sectionId` [deleteSection] cleared — see that
  /// method's own doc comment for why that asymmetry is accepted.
  Future<void> restoreSection(Section section) async {
    await ref.read(sectionRepositoryProvider).saveSection(section);
    _refresh();
  }

  /// Deletes a [Section] and unassigns every [Task] filed into it —
  /// requested directly ("if a section is deleted, its items become
  /// unfiled"), the opposite policy from [CategoryList.deleteCategory]'s
  /// reassign-to-`general` (there is no built-in Section to reassign to).
  /// One bulk pass, one [_refresh] at the end — same "loop then refresh
  /// once" shape [CategoryList.deleteCategory] already established, and
  /// the same direct-repository-write path (not `TaskList.updateTask`,
  /// which would trigger this notifier's own unrelated notification-sync
  /// side effect for every affected task).
  Future<void> deleteSection(String id) async {
    final taskRepository = ref.read(taskRepositoryProvider);
    final affected = taskRepository
        .getTasks()
        .where((task) => task.sectionId == id)
        .toList();
    for (final task in affected) {
      task.sectionId = null;
      await taskRepository.saveTask(task);
    }

    await ref.read(sectionRepositoryProvider).deleteSection(id);
    _refresh();
  }

  void _refresh() {
    state = ref.read(sectionRepositoryProvider).getSections();
  }
}
