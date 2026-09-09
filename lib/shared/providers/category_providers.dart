import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/category.dart';
import '../models/task.dart';
import '../models/task_category.dart';
import '../repositories/category_repository.dart';
import '../repositories/hive_category_repository.dart';
import '../repositories/preferences_repository.dart';
import 'preferences_providers.dart';
import 'task_providers.dart';

part 'category_providers.g.dart';

const categoryBoxName = 'categories';

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) {
  final box = Hive.box<Category>(categoryBoxName);
  return HiveCategoryRepository(box);
}

/// CRUD state over [CategoryRepository], mirroring [TaskList]/
/// [TrackedBehaviorList]'s shape.
///
/// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md — this
/// is session-scoped app state read by both category-picker sheets, not
/// screen-scoped state.
///
/// No `deleteCategory` — v1 scope is create + list only, per the confirmed
/// decision recorded in docs/DECISIONS.md.
@Riverpod(keepAlive: true)
class CategoryList extends _$CategoryList {
  @override
  List<Category> build() {
    return ref.watch(categoryRepositoryProvider).getCategories();
  }

  /// Creates a user-defined category and returns it, so a caller (the new
  /// Add-category modal) can select it immediately without a second lookup
  /// — mirrors [TaskList.createTask]'s own "return what was saved" shape.
  Future<Category> createCategory({
    required String name,
    required int colorToken,
    required String emoji,
  }) async {
    final category = Category.create(
      name: name,
      colorToken: colorToken,
      emoji: emoji,
    );
    await ref.read(categoryRepositoryProvider).saveCategory(category);
    _refresh();
    return category;
  }

  /// Renames/recolors an existing category (built-in or user-defined) —
  /// per CONSTITUTION.md's "v2: rename, recolor, and reorder" section
  /// (reorder itself confirmed out of scope for now). Mirrors
  /// [ZoneList.updateZone]'s exact shape: the caller mutates a fetched
  /// [Category]'s fields directly (both are plain mutable fields, not
  /// `final`) and passes the same object back in — `saveCategory` is a
  /// Hive `put` keyed by id, so this overwrites the existing row rather
  /// than creating a second one.
  Future<void> updateCategory(Category category) async {
    await ref.read(categoryRepositoryProvider).saveCategory(category);
    _refresh();
  }

  /// One-time, at-launch seed + backfill (see `main.dart`, called the same
  /// way `TaskList.materializeDueRecurrences` is): seeds the 5 built-in
  /// [Category] rows at their fixed [BuiltInCategoryIds] (idempotent by
  /// construction — `saveCategory` is a Hive `put` keyed by id, so calling
  /// this twice overwrites the same 5 rows rather than duplicating them),
  /// then resolves every existing [Task]'s deprecated `category` enum
  /// value onto its new `categoryId` where that's still null. Gated by
  /// [PreferenceKeys.categoriesSeeded] so it only actually runs once per
  /// install — the idempotency above is a belt-and-braces guarantee, not a
  /// substitute for the gate (re-running the Task backfill loop on every
  /// launch would mean re-scanning every task forever for no reason).
  Future<void> seedBuiltInsAndBackfillIfNeeded() async {
    final prefs = ref.read(preferencesRepositoryProvider);
    final alreadySeeded =
        prefs.getValue<bool>(PreferenceKeys.categoriesSeeded) ?? false;
    if (alreadySeeded) return;

    final categoryRepository = ref.read(categoryRepositoryProvider);
    final builtIns = <Category>[
      Category(
        id: BuiltInCategoryIds.general,
        name: 'General',
        colorToken: 0,
        emoji: '⚪',
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.health,
        name: 'Health',
        colorToken: 1,
        emoji: '⛑️',
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.work,
        name: 'Work',
        colorToken: 2,
        emoji: '💼',
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.personal,
        name: 'Personal',
        colorToken: 3,
        emoji: '🏠',
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.admin,
        name: 'Admin',
        colorToken: 4,
        emoji: '📋',
        isBuiltIn: true,
      ),
    ];
    for (final category in builtIns) {
      await categoryRepository.saveCategory(category);
    }

    final taskRepository = ref.read(taskRepositoryProvider);
    final tasks = taskRepository.getTasks();
    for (final task in tasks) {
      if (task.categoryId != null) continue;
      // ignore: deprecated_member_use_from_same_package
      task.categoryId = _builtInIdFor(task.category);
      await taskRepository.saveTask(task);
    }

    await prefs.setValue(PreferenceKeys.categoriesSeeded, true);
    _refresh();
  }

  /// Merges [categories] (already parsed/validated by the caller — see
  /// `BackupService.parseImportFile`) into local storage, so a user's
  /// custom categories survive export/restore on a fresh install. Mirrors
  /// [TaskList.importTasks]'s "never overwrite, count and report" shape,
  /// simplified for this entity's create-only scope: a new id is written
  /// as-is and counted imported; an id that already exists (e.g. one of
  /// the 5 built-ins, always present by the time an import runs) is left
  /// untouched and counted skipped — there's no per-field conflict
  /// resolution to do, since v1 has no edit, so "already exists" is the
  /// only other case, not a real conflict.
  Future<CategoryImportResult> importCategories(
    List<Category> categories,
  ) async {
    final repository = ref.read(categoryRepositoryProvider);
    var imported = 0;
    var alreadyPresent = 0;

    for (final category in categories) {
      final existing = repository.getCategoryById(category.id);
      if (existing == null) {
        await repository.saveCategory(category);
        imported++;
      } else {
        alreadyPresent++;
      }
    }

    _refresh();
    return CategoryImportResult(
      imported: imported,
      alreadyPresent: alreadyPresent,
    );
  }

  void _refresh() {
    state = ref.read(categoryRepositoryProvider).getCategories();
  }
}

/// Outcome of [CategoryList.importCategories] — mirrors [ImportResult]'s
/// shape (`task_providers.dart`), minus the `conflicts` count that
/// entity's edit-capable model needs and this one, create-only, doesn't.
class CategoryImportResult {
  const CategoryImportResult({
    required this.imported,
    required this.alreadyPresent,
  });

  final int imported;
  final int alreadyPresent;
}

/// Maps a legacy [TaskCategory] enum value to the matching built-in
/// [Category]'s fixed UUID — the one-time migration's resolution step. A
/// plain top-level function (not a notifier method) so the migration test
/// can exercise it directly without going through the full provider.
String _builtInIdFor(TaskCategory category) => switch (category) {
  TaskCategory.general => BuiltInCategoryIds.general,
  TaskCategory.health => BuiltInCategoryIds.health,
  TaskCategory.work => BuiltInCategoryIds.work,
  TaskCategory.personal => BuiltInCategoryIds.personal,
  TaskCategory.admin => BuiltInCategoryIds.admin,
};
