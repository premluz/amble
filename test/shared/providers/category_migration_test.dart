import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_category.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';

import '../../support/fake_notification_service.dart';

/// This is the highest-risk piece of the whole Category migration — see
/// docs/DECISIONS.md — so it gets its own dedicated test file rather than
/// living inside `task_providers_test.dart` or `category_providers`'s own
/// coverage. Exercises `CategoryList.seedBuiltInsAndBackfillIfNeeded`
/// against a Hive box holding a genuine pre-migration [Task] (the
/// deprecated `category` enum set, `categoryId` null), the exact shape a
/// real installed user's data is in before this feature ships.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<dynamic> preferencesBox;
  late ProviderContainer container;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_category_migration');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final suffix = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_migration_tasks_$suffix');
    categoryBox = await Hive.openBox<Category>(
      'test_migration_categories_$suffix',
    );
    preferencesBox = await Hive.openBox<dynamic>(
      'test_migration_preferences_$suffix',
    );

    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
        categoryRepositoryProvider.overrideWithValue(
          HiveCategoryRepository(categoryBox),
        ),
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(preferencesBox),
        ),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await taskBox.deleteFromDisk();
    await categoryBox.deleteFromDisk();
    await preferencesBox.deleteFromDisk();
  });

  test('seeds all 5 built-in categories at their fixed UUIDs', () async {
    await container
        .read(categoryListProvider.notifier)
        .seedBuiltInsAndBackfillIfNeeded();

    final categories = container.read(categoryListProvider);
    expect(categories, hasLength(5));
    expect(categories.map((c) => c.id).toSet(), {
      BuiltInCategoryIds.general,
      BuiltInCategoryIds.health,
      BuiltInCategoryIds.work,
      BuiltInCategoryIds.personal,
      BuiltInCategoryIds.admin,
    });
    for (final category in categories) {
      expect(category.isBuiltIn, isTrue);
    }
  });

  test(
    'backfills a pre-migration task (deprecated category enum set, '
    'categoryId null) to the matching built-in UUID, touching nothing else',
    () async {
      // Constructed via the plain Task(...) constructor with the OLD
      // `category` enum field set and `categoryId` left at its default
      // (null) — exactly the shape a real installed user's persisted Task
      // is in before this migration runs. `// ignore` because this is
      // deliberately exercising the deprecated field, the whole point of
      // this test.
      final preMigrationTask = Task(
        id: 'pre-migration-task',
        title: 'Morning run',
        notes: 'Bring water',
        scheduledAt: DateTime(2026, 8, 20, 7, 0),
        durationMinutes: 30,
        // ignore: deprecated_member_use_from_same_package
        category: TaskCategory.health,
      );
      await taskBox.put(preMigrationTask.id, preMigrationTask);

      await container
          .read(categoryListProvider.notifier)
          .seedBuiltInsAndBackfillIfNeeded();

      final migrated = taskBox.get('pre-migration-task')!;
      expect(migrated.categoryId, BuiltInCategoryIds.health);
      // Every other field is untouched by the migration.
      expect(migrated.title, 'Morning run');
      expect(migrated.notes, 'Bring water');
      expect(migrated.scheduledAt, DateTime(2026, 8, 20, 7, 0));
      expect(migrated.durationMinutes, 30);
      // ignore: deprecated_member_use_from_same_package
      expect(migrated.category, TaskCategory.health);
    },
  );

  test(
    'backfills every legacy TaskCategory value to its matching built-in',
    () async {
      final legacyValues = {
        TaskCategory.general: BuiltInCategoryIds.general,
        TaskCategory.health: BuiltInCategoryIds.health,
        TaskCategory.work: BuiltInCategoryIds.work,
        TaskCategory.personal: BuiltInCategoryIds.personal,
        TaskCategory.admin: BuiltInCategoryIds.admin,
      };

      var index = 0;
      for (final entry in legacyValues.entries) {
        final task = Task(
          id: 'legacy-task-$index',
          title: 'Task $index',
          scheduledAt: DateTime(2026, 8, 20, 7, 0),
          durationMinutes: 30,
          // ignore: deprecated_member_use_from_same_package
          category: entry.key,
        );
        await taskBox.put(task.id, task);
        index++;
      }

      await container
          .read(categoryListProvider.notifier)
          .seedBuiltInsAndBackfillIfNeeded();

      index = 0;
      for (final entry in legacyValues.entries) {
        final migrated = taskBox.get('legacy-task-$index')!;
        expect(
          migrated.categoryId,
          entry.value,
          reason: '${entry.key} should backfill to ${entry.value}',
        );
        index++;
      }
    },
  );

  test('does NOT overwrite a task that already has a categoryId set', () async {
    final alreadyMigrated = Task(
      id: 'already-migrated',
      title: 'Already has a category',
      scheduledAt: DateTime(2026, 8, 20, 7, 0),
      durationMinutes: 30,
      categoryId: 'some-custom-category-id',
    );
    await taskBox.put(alreadyMigrated.id, alreadyMigrated);

    await container
        .read(categoryListProvider.notifier)
        .seedBuiltInsAndBackfillIfNeeded();

    expect(
      taskBox.get('already-migrated')!.categoryId,
      'some-custom-category-id',
    );
  });

  test('running the seed/backfill twice does not duplicate the built-ins or '
      're-touch an already-migrated task', () async {
    final preMigrationTask = Task(
      id: 'pre-migration-task',
      title: 'Morning run',
      scheduledAt: DateTime(2026, 8, 20, 7, 0),
      durationMinutes: 30,
      // ignore: deprecated_member_use_from_same_package
      category: TaskCategory.work,
    );
    await taskBox.put(preMigrationTask.id, preMigrationTask);

    final notifier = container.read(categoryListProvider.notifier);
    await notifier.seedBuiltInsAndBackfillIfNeeded();
    await notifier.seedBuiltInsAndBackfillIfNeeded();

    expect(container.read(categoryListProvider), hasLength(5));
    expect(
      taskBox.get('pre-migration-task')!.categoryId,
      BuiltInCategoryIds.work,
    );
  });

  test(
    'is gated by PreferenceKeys.categoriesSeeded — does not re-run once set',
    () async {
      // Pre-set the flag directly, as if a previous launch already ran
      // the migration, then seed a task that WOULD be backfilled if the
      // gate were ignored.
      await preferencesBox.put(PreferenceKeys.categoriesSeeded, true);
      final task = Task(
        id: 'should-not-be-touched',
        title: 'Untouched',
        scheduledAt: DateTime(2026, 8, 20, 7, 0),
        durationMinutes: 30,
        // ignore: deprecated_member_use_from_same_package
        category: TaskCategory.admin,
      );
      await taskBox.put(task.id, task);

      await container
          .read(categoryListProvider.notifier)
          .seedBuiltInsAndBackfillIfNeeded();

      // No built-ins seeded, and the task's categoryId is still null —
      // the gate short-circuited before either step ran.
      expect(container.read(categoryListProvider), isEmpty);
      expect(taskBox.get('should-not-be-touched')!.categoryId, isNull);
    },
  );
}
