import 'package:hive_ce/hive_ce.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:amble/shared/models/category.dart';

/// Opens a uniquely-named [Category] box and seeds it with the 9 built-in
/// rows, matching what `main.dart`'s `seedBuiltInsAndBackfillIfNeeded`
/// would have done by the time a real app screen mounts. Widget tests that
/// render anything reading `categoryListProvider` (the Task Detail sheet,
/// either category picker) need a real, populated box — `categoryRepositoryProvider`
/// resolves a live `Hive.box<Category>`, not something a plain provider
/// override alone can stand in for the way `taskRepositoryProvider` does.
///
/// **2026-09-23 — expanded from 5 to 9, matching `category_providers.dart`'s
/// own real seed list exactly** (General/untagged, Health/red, Work/blue,
/// Home — the renamed "Personal," same id, Admin, and four new: Personal/
/// user icon, Social, Reading, Learning). See `BuiltInCategoryIds`' own doc
/// comment for why [BuiltInCategoryIds.personal] is "Home" now, not
/// "Personal."
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
  ]) {
    await box.put(category.id, category);
  }
  return box;
}
