import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/task_size.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

/// Covers the "Task size" split requested directly: "Settings in
/// appearance separately font size and separately pill size, let's split
/// this." [TaskSizeSetting] keeps controlling the badge/pill diameter
/// alone; this is the new, independent font-size half.
///
/// The migration behavior (confirmed via AskUserQuestion) is the highest-
/// risk part: an existing user's ALREADY-SAVED [TaskSizeSetting] value
/// must seed [TaskFontSizeSetting] once, by name, so their font size
/// doesn't silently change the moment this becomes a separate control.
void main() {
  late Box<dynamic> box;
  late ProviderContainer container;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_task_font_size');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<dynamic>(
      'test_preferences_${DateTime.now().microsecondsSinceEpoch}',
    );
    container = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(box),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await box.deleteFromDisk();
  });

  group('a fresh install (neither taskSize nor taskFontSize ever saved)', () {
    test('defaults to TaskFontSize.md, matching TaskSizeSetting\'s own '
        'plain default reached by name', () {
      expect(container.read(taskFontSizeSettingProvider), TaskFontSize.md);
    });

    test('independent of TaskSizeSetting once set — changing the pill '
        'size does not move the font size', () async {
      // Establish font size first, matching the default md/md pairing.
      expect(container.read(taskFontSizeSettingProvider), TaskFontSize.md);

      await container.read(taskSizeSettingProvider.notifier).set(TaskSize.lg);

      expect(
        container.read(taskFontSizeSettingProvider),
        TaskFontSize.md,
        reason: 'the two settings must be independent once resolved — '
            'changing pill size alone must never move font size',
      );
    });
  });

  group('migration from an existing TaskSizeSetting value', () {
    test('an existing sm pill size migrates to TaskFontSize.sm on first '
        'read, by name', () async {
      await container.read(taskSizeSettingProvider.notifier).set(TaskSize.sm);

      expect(container.read(taskFontSizeSettingProvider), TaskFontSize.sm);
    });

    test('an existing lg pill size migrates to TaskFontSize.lg on first '
        'read, by name', () async {
      await container.read(taskSizeSettingProvider.notifier).set(TaskSize.lg);

      expect(container.read(taskFontSizeSettingProvider), TaskFontSize.lg);
    });

    // `build()` deliberately never writes on its own (real bug, fixed
    // directly: an earlier version DID write from inside `build()` via a
    // fire-and-forget `unawaited(...)` Hive call, and any test tearing
    // down its Hive box before that write finished deadlocked — the exact
    // "unawaited Hive write still in flight when the test returned" class
    // of bug this codebase has hit before). `migrateIfNeeded()` is the
    // explicit, awaited persistence step `main()` calls once at launch —
    // covered on its own below, separately from the in-memory resolution
    // `build()` still does correctly without it.
    test('build() alone does NOT persist the migrated value — reading it '
        'twice re-derives from taskSize each time until migrateIfNeeded() '
        'is called', () async {
      await container.read(taskSizeSettingProvider.notifier).set(TaskSize.sm);
      expect(container.read(taskFontSizeSettingProvider), TaskFontSize.sm);

      final repository = HivePreferencesRepository(box);
      expect(
        repository.getValue<TaskFontSize>(PreferenceKeys.taskFontSize),
        isNull,
        reason: 'build() must not have written anything to storage yet',
      );
    });

    test('migrateIfNeeded() persists the migration once — a fresh '
        'container then reads it back without re-deriving from a '
        'LATER-changed taskSize', () async {
      await container.read(taskSizeSettingProvider.notifier).set(TaskSize.sm);
      // Resolves TaskFontSize.sm in memory (via build()) and this call
      // then persists exactly that.
      await container
          .read(taskFontSizeSettingProvider.notifier)
          .migrateIfNeeded();

      // Now change the LEGACY setting in a fresh container — if the
      // migration hadn't been persisted, this fresh container would
      // re-derive from the NEW taskSize (lg) and wrongly report
      // TaskFontSize.lg instead of the already-migrated sm.
      final freshContainer = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(box),
          ),
        ],
      );
      addTearDown(freshContainer.dispose);
      await freshContainer
          .read(taskSizeSettingProvider.notifier)
          .set(TaskSize.lg);

      expect(
        freshContainer.read(taskFontSizeSettingProvider),
        TaskFontSize.sm,
        reason: 'once migrated, taskFontSize must be its own persisted '
            'value — changing taskSize afterward must not re-derive it',
      );
    });

    test('migrateIfNeeded() is a no-op once a value is already stored', () async {
      await container
          .read(taskFontSizeSettingProvider.notifier)
          .set(TaskFontSize.lg);

      // Change taskSize AFTER an explicit font-size choice, then call
      // migrateIfNeeded again — it must never overwrite a real choice.
      await container.read(taskSizeSettingProvider.notifier).set(TaskSize.sm);
      await container
          .read(taskFontSizeSettingProvider.notifier)
          .migrateIfNeeded();

      expect(container.read(taskFontSizeSettingProvider), TaskFontSize.lg);
    });

    test('once a user explicitly sets a font size, it persists across '
        'containers exactly like any other real setting', () async {
      await container
          .read(taskFontSizeSettingProvider.notifier)
          .set(TaskFontSize.lg);

      final freshContainer = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(box),
          ),
        ],
      );
      addTearDown(freshContainer.dispose);

      expect(
        freshContainer.read(taskFontSizeSettingProvider),
        TaskFontSize.lg,
      );
    });
  });
}
