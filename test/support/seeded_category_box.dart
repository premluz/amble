import 'package:hive_ce/hive_ce.dart';
import 'package:amble/shared/models/category.dart';

/// Opens a uniquely-named [Category] box and seeds it with the 5 built-in
/// rows, matching what `main.dart`'s `seedBuiltInsAndBackfillIfNeeded`
/// would have done by the time a real app screen mounts. Widget tests that
/// render anything reading `categoryListProvider` (the Task Detail sheet,
/// either category picker) need a real, populated box — `categoryRepositoryProvider`
/// resolves a live `Hive.box<Category>`, not something a plain provider
/// override alone can stand in for the way `taskRepositoryProvider` does.
///
/// Deliberately bypasses the real seed function's `PreferenceKeys.categoriesSeeded`
/// gate and its `Task` backfill loop — those are launch-once production
/// concerns unrelated to what these tests are actually checking, and gating
/// on them would mean every caller also standing up a `preferences` box.
Future<Box<Category>> openSeededCategoryBox(String name) async {
  final box = await Hive.openBox<Category>(name);
  for (final category in [
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
  ]) {
    await box.put(category.id, category);
  }
  return box;
}
