import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

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
    int? iconCodePoint,
  }) async {
    final category = Category.create(
      name: name,
      colorToken: colorToken,
      emoji: emoji,
      iconCodePoint: iconCodePoint,
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

  /// Deletes [id] — requested directly ("Edit category also [add a
  /// remove icon button]"), reversing the earlier "v1 scope is create +
  /// list only, no delete" decision (docs/DECISIONS.md). A built-in
  /// category (the 5 seeded rows, [Category.isBuiltIn]) can never be
  /// deleted — confirmed as the only sane floor, since
  /// [BuiltInCategoryIds.general] in particular is the fallback every
  /// reassignment below depends on existing. Callers must check
  /// [Category.isBuiltIn] before offering this at all (see
  /// `add_category_modal.dart`'s own gating).
  ///
  /// Every [Task] currently referencing [id] is reassigned to
  /// [BuiltInCategoryIds.general] FIRST, before the row itself is
  /// deleted — confirmed directly as the chosen behavior (over blocking
  /// the delete outright, or leaving tasks with a dangling `categoryId`
  /// the way `templateId`/Zone's `zoneId` are deliberately left to go
  /// stale): unlike those two fields, `categoryId` drives real, currently
  /// visible UI (the capsule's own color/emoji) for every affected task,
  /// so silently orphaning it would make already-scheduled tasks render
  /// with no resolvable category. One bulk pass, one [_refresh] at the
  /// end — mirrors `TaskList.deleteTaskSeries`'s own "loop then refresh
  /// once" shape rather than an individual write (and its own repository
  /// round-trip) per affected task.
  Future<void> deleteCategory(String id) async {
    final category = ref.read(categoryRepositoryProvider).getCategoryById(id);
    if (category == null || category.isBuiltIn) return;

    final taskRepository = ref.read(taskRepositoryProvider);
    final affected = taskRepository
        .getTasks()
        .where((task) => task.categoryId == id)
        .toList();
    for (final task in affected) {
      task.categoryId = BuiltInCategoryIds.general;
      await taskRepository.saveTask(task);
    }

    await ref.read(categoryRepositoryProvider).deleteCategory(id);
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
  /// Clears the built-in General category's old `'⚪'` glyph on installs
  /// that were ALREADY seeded before it was removed.
  ///
  /// The seed above only ever runs once per install (gated by
  /// `categoriesSeeded`), so changing its literal alone would fix new
  /// installs and leave every existing user looking at the white circle
  /// they asked to have removed. This is deliberately narrow: it touches
  /// ONLY the built-in General row, ONLY when that row still carries the
  /// exact old glyph, so a user who has since set their own emoji on it
  /// keeps their choice, and a second run is a no-op.
  Future<void> _clearLegacyGeneralEmoji() async {
    const legacyGeneralEmoji = '⚪';
    final categoryRepository = ref.read(categoryRepositoryProvider);
    final general = categoryRepository
        .getCategories()
        .where((c) => c.id == BuiltInCategoryIds.general)
        .firstOrNull;
    if (general == null || general.emoji != legacyGeneralEmoji) return;

    general.emoji = '';
    await categoryRepository.saveCategory(general);
    _refresh();
  }

  /// Same narrow, repeatable-no-op shape as [_clearLegacyGeneralEmoji]:
  /// an install seeded before [Category.iconCodePoint] existed has all 5
  /// built-in rows sitting with that field still null (the seed loop only
  /// ever runs once — see [seedBuiltInsAndBackfillIfNeeded]'s own doc
  /// comment). Backfills ONLY a built-in row that still has no
  /// `iconCodePoint` set, to the same default the fresh-seed literals
  /// above use (kept in sync with `features/task_detail/category_visual
  /// .dart`'s `builtInIconFor` by hand — duplicated rather than imported
  /// so this provider layer doesn't reach into `features/`, per
  /// ARCHITECTURE.md's strict one-directional dependency rule). Touches
  /// nothing on a row a user could ever have re-iconned (built-ins have
  /// no edit UI in v1), so there's no "keeps their own choice" case to
  /// protect here unlike the emoji one.
  Future<void> _backfillBuiltInIconCodePoints() async {
    final categoryRepository = ref.read(categoryRepositoryProvider);
    var changed = false;
    for (final category in categoryRepository.getCategories()) {
      if (!category.isBuiltIn || category.iconCodePoint != null) continue;
      final icon = switch (category.id) {
        BuiltInCategoryIds.health => TablerIcons.heart,
        BuiltInCategoryIds.work => TablerIcons.briefcase,
        BuiltInCategoryIds.personal => TablerIcons.home,
        BuiltInCategoryIds.admin => TablerIcons.clipboardList,
        _ => TablerIcons.circle,
      };
      category.iconCodePoint = icon.codePoint;
      await categoryRepository.saveCategory(category);
      changed = true;
    }
    if (changed) _refresh();
  }

  /// Same narrow, repeatable-no-op shape as [_clearLegacyGeneralEmoji]/
  /// [_backfillBuiltInIconCodePoints]: an install that was ALREADY seeded
  /// before the 2026-09-23 category expansion (5 built-ins → 9) has none
  /// of the 4 new rows and still carries the OLD "Personal" name/icon on
  /// [BuiltInCategoryIds.personal] — the one-time seed loop below never
  /// runs again for it, so those changes would otherwise never reach an
  /// existing install. Reported directly, after shipping that change:
  /// "when should [I] see them? if build app next time?" — the answer
  /// was "never, without a migration," which this is.
  ///
  /// Two repairs, each independently idempotent:
  /// 1. Renames [BuiltInCategoryIds.personal] from "Personal"/home-icon
  ///    to "Home"/home-icon IF it still carries the old name — SAME id,
  ///    so every task already referencing it keeps working; only the
  ///    label changes. Skipped if a user has already renamed it away
  ///    from "Personal" themselves (there is no built-in rename UI in
  ///    v1, so in practice this only ever matches the pre-migration
  ///    seed literal, but checking the name rather than unconditionally
  ///    overwriting costs nothing and matches this file's own established
  ///    "don't clobber a value a user could have changed" caution).
  /// 2. Inserts each of the 4 new built-in rows (Personal/user icon,
  ///    Social, Reading, Learning) that isn't already present, by id —
  ///    `saveCategory` is a Hive `put` keyed by id, so a second run that
  ///    finds them already there does nothing.
  Future<void> _migrateToExpandedCategorySet() async {
    final categoryRepository = ref.read(categoryRepositoryProvider);
    final existing = categoryRepository.getCategories();
    var changed = false;

    final oldPersonal = existing
        .where((c) => c.id == BuiltInCategoryIds.personal)
        .firstOrNull;
    if (oldPersonal != null && oldPersonal.name == 'Personal') {
      oldPersonal.name = 'Home';
      await categoryRepository.saveCategory(oldPersonal);
      changed = true;
    }

    final existingIds = existing.map((c) => c.id).toSet();
    final newBuiltIns = <Category>[
      Category(
        id: BuiltInCategoryIds.personalNew,
        name: 'Personal',
        colorToken: 5,
        emoji: '🙂',
        iconCodePoint: TablerIcons.user.codePoint,
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.social,
        name: 'Social',
        colorToken: 6,
        emoji: '🎉',
        iconCodePoint: TablerIcons.users.codePoint,
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.reading,
        name: 'Reading',
        colorToken: 7,
        emoji: '📖',
        iconCodePoint: TablerIcons.book.codePoint,
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.learning,
        name: 'Learning',
        colorToken: 8,
        emoji: '🎓',
        iconCodePoint: TablerIcons.school.codePoint,
        isBuiltIn: true,
      ),
    ];
    for (final category in newBuiltIns) {
      if (existingIds.contains(category.id)) continue;
      await categoryRepository.saveCategory(category);
      changed = true;
    }

    if (changed) _refresh();
  }

  Future<void> seedBuiltInsAndBackfillIfNeeded() async {
    final prefs = ref.read(preferencesRepositoryProvider);
    final alreadySeeded =
        prefs.getValue<bool>(PreferenceKeys.categoriesSeeded) ?? false;
    if (alreadySeeded) {
      await _clearLegacyGeneralEmoji();
      await _backfillBuiltInIconCodePoints();
      await _migrateToExpandedCategorySet();
      return;
    }

    final categoryRepository = ref.read(categoryRepositoryProvider);
    // **2026-09-23 — expanded from 5 to 9 built-ins**, requested directly:
    // General becomes an invisible "untagged" placeholder (never shown in
    // any tag list — see `categoryListProvider`'s own filtering),
    // Health/Work recolor (red/blue respectively — see
    // `ColorPrimitives`' own 2026-09-23 comment), the old "Personal" (home
    // icon) is renamed to "Home" at its SAME id, and 4 new categories are
    // added: a NEW "Personal" (user icon), "Social" (two-people icon),
    // "Reading" (book icon), "Learning" (graduation-cap icon).
    //
    // `colorToken` is UNUSED for built-ins (they resolve color via
    // `builtInTokenFor`'s id->TaskCategoryToken map instead — see
    // `category_visual.dart`) — kept at a stable per-row value only
    // because the field is non-nullable, not because it does anything.
    final builtIns = <Category>[
      Category(
        id: BuiltInCategoryIds.general,
        name: 'General',
        colorToken: 0,
        // Deliberately EMPTY — requested directly: "both light dark mode
        // default should not have emoji." The grey pill already carries
        // the "uncategorised" signal; a glyph on top of it adds a fifth
        // meaning where the point is the absence of one. See
        // `TaskCategoryTokenMapping.emoji`'s own copy of this reasoning
        // for the legacy enum's matching change.
        emoji: '',
        iconCodePoint: TablerIcons.circle.codePoint,
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.health,
        name: 'Health',
        colorToken: 1,
        emoji: '⛑️',
        iconCodePoint: TablerIcons.heart.codePoint,
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.work,
        name: 'Work',
        colorToken: 2,
        emoji: '💼',
        iconCodePoint: TablerIcons.briefcase.codePoint,
        isBuiltIn: true,
      ),
      Category(
        // Same id as the pre-rename "Personal" — this is a RENAME, not a
        // new category, so existing tasks' `categoryId` still resolves.
        id: BuiltInCategoryIds.personal,
        name: 'Home',
        colorToken: 3,
        emoji: '🏠',
        iconCodePoint: TablerIcons.home.codePoint,
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.admin,
        name: 'Admin',
        colorToken: 4,
        emoji: '📋',
        iconCodePoint: TablerIcons.clipboardList.codePoint,
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.personalNew,
        name: 'Personal',
        colorToken: 5,
        emoji: '🙂',
        iconCodePoint: TablerIcons.user.codePoint,
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.social,
        name: 'Social',
        colorToken: 6,
        emoji: '🎉',
        iconCodePoint: TablerIcons.users.codePoint,
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.reading,
        name: 'Reading',
        colorToken: 7,
        emoji: '📖',
        iconCodePoint: TablerIcons.book.codePoint,
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.learning,
        name: 'Learning',
        colorToken: 8,
        emoji: '🎓',
        iconCodePoint: TablerIcons.school.codePoint,
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

/// [categoryListProvider], minus [BuiltInCategoryIds.general].
///
/// **2026-09-23** — requested directly: General is an invisible
/// "untagged" placeholder — the fallback a task silently carries when no
/// real category was chosen — and must never appear as a selectable
/// option in a tag picker or the Settings tag list. It still exists as a
/// real [Category] row (raw [categoryListProvider] is unfiltered): a
/// task's `categoryId` can resolve to it, [CategoryList.deleteCategory]
/// reassigns orphaned tasks to it, and [CategoryBadge]'s own null-category
/// fallback renders its look directly — none of that changes. This
/// provider exists ONLY for the three UI sites that render "a list of
/// tags to pick/manage" (`task_category_modal.dart`,
/// `task_name_category_modal.dart`, `category_list_screen.dart`), so
/// General is invisible there without needing three separate `.where(...)`
/// calls (and the risk of a future 4th site forgetting the filter).
@riverpod
List<Category> visibleCategoryList(Ref ref) => ref
    .watch(categoryListProvider)
    .where((category) => category.id != BuiltInCategoryIds.general)
    .toList();

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
