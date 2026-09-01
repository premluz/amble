import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';

void main() {
  late Box<Category> box;
  late HiveCategoryRepository repository;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_categories');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Category>(
      'test_categories_${DateTime.now().microsecondsSinceEpoch}',
    );
    repository = HiveCategoryRepository(box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  test('saveCategory persists and getCategoryById retrieves it', () async {
    final category = Category.create(
      name: 'Reading',
      colorToken: 2,
      emoji: '📚',
    );

    await repository.saveCategory(category);

    final fetched = repository.getCategoryById(category.id);
    expect(fetched, isNotNull);
    expect(fetched!.name, 'Reading');
    expect(fetched.colorToken, 2);
    expect(fetched.emoji, '📚');
    expect(fetched.schemaVersion, 1);
  });

  test('getCategoryById returns null for an unknown id', () {
    expect(repository.getCategoryById('never-saved'), isNull);
  });

  test('getCategories returns all saved categories', () async {
    await repository.saveCategory(
      Category.create(name: 'A', colorToken: 0, emoji: '⭐'),
    );
    await repository.saveCategory(
      Category.create(name: 'B', colorToken: 1, emoji: '🎯'),
    );

    expect(repository.getCategories().length, 2);
  });

  test('saving an existing id updates rather than duplicating', () async {
    final category = Category.create(
      name: 'Original',
      colorToken: 0,
      emoji: '⭐',
    );
    await repository.saveCategory(category);

    category.name = 'Edited';
    category.colorToken = 4;
    await repository.saveCategory(category);

    expect(repository.getCategories().length, 1);
    expect(repository.getCategoryById(category.id)!.name, 'Edited');
    expect(repository.getCategoryById(category.id)!.colorToken, 4);
  });

  test('seeding the 5 built-in categories twice (by fixed id) does not '
      'duplicate them — idempotent by construction, since saveCategory is a '
      'Hive put keyed by id', () async {
    final builtIns = [
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
        colorToken: 0,
        emoji: '⛑️',
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.work,
        name: 'Work',
        colorToken: 0,
        emoji: '💼',
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.personal,
        name: 'Personal',
        colorToken: 0,
        emoji: '🏠',
        isBuiltIn: true,
      ),
      Category(
        id: BuiltInCategoryIds.admin,
        name: 'Admin',
        colorToken: 0,
        emoji: '📋',
        isBuiltIn: true,
      ),
    ];

    for (final category in builtIns) {
      await repository.saveCategory(category);
    }
    // Seed a second time, same fixed ids — simulates seeding running
    // twice (e.g. a preference-flag race or a re-triggered migration).
    for (final category in builtIns) {
      await repository.saveCategory(category);
    }

    expect(repository.getCategories().length, 5);
    expect(
      repository.getCategoryById(BuiltInCategoryIds.health)!.name,
      'Health',
    );
  });

  test('Category.create generates a unique client-side UUID', () {
    final a = Category.create(name: 'A', colorToken: 0, emoji: '⭐');
    final b = Category.create(name: 'B', colorToken: 0, emoji: '⭐');

    expect(a.id, isNotEmpty);
    expect(a.id, isNot(equals(b.id)));
  });
}
