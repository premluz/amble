import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_switch.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/edit_selection_provider.dart';
import 'package:amble/features/zone_grid/zone_grid_screen.dart';
import 'package:amble/features/zone_grid/zone_grid_tab.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/task_template_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// Covers the Tasks tab's bottom dock swapping from plain "Close" to a
/// selection context menu (back-arrow / Edit / Remove) whenever
/// [editSelectionProvider] is non-empty — requested directly: "on edit
/// task mode when item(s) selected we need selection context menu."
///
/// Every real Hive write here (`createTask`/`deleteTask`, even called
/// directly on a notifier rather than through a tap) runs inside
/// `tester.runAsync` — a bare `await` on real disk I/O hangs indefinitely
/// under `flutter_test`'s synchronous pump-based zone regardless of how
/// it's invoked. See docs/ERROR_LOG.md's "bare await on real Hive I/O"
/// entry; this file hung for the full 10-minute test timeout the first
/// time this rule was missed here.
void main() {
  late Box<Task> taskBox;
  late Box<dynamic> prefsBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<TaskTemplate> taskTemplateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_zone_grid_selection_dock');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    prefsBox = await Hive.openBox<dynamic>('test_prefs_$stamp');
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
    zoneBox = await Hive.openBox<Zone>('test_zones_$stamp');
    trackedBehaviorBox = await Hive.openBox<TrackedBehavior>(
      'test_tracked_behaviors_$stamp',
    );
    taskTemplateBox = await Hive.openBox<TaskTemplate>(
      'test_task_templates_$stamp',
    );
  });

  tearDown(() async {
    await taskBox.deleteFromDisk();
    await prefsBox.deleteFromDisk();
    await categoryBox.deleteFromDisk();
    await zoneBox.deleteFromDisk();
    await trackedBehaviorBox.deleteFromDisk();
    await taskTemplateBox.deleteFromDisk();
  });

  Future<ProviderContainer> pumpEditScreen(WidgetTester tester) async {
    late ProviderContainer container;
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(prefsBox),
          ),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categoryBox),
          ),
          zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zoneBox)),
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(trackedBehaviorBox),
          ),
          taskTemplateRepositoryProvider.overrideWithValue(
            HiveTaskTemplateRepository(taskTemplateBox),
          ),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: [AmbleTheme.light],
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              const ZoneGridScreen(initialTab: ZoneGridTab.tasks),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Same discipline as zone_grid_edit_screen_merge_test.dart's own
    // pumpEditScreen — the embedded spatial Timeline never fully settles
    // in a plain widget-test environment.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  /// Creates one task via the real notifier/repository, inside
  /// `runAsync` per this file's own top-of-file note. Returns its id.
  Future<String> createTask(
    WidgetTester tester,
    ProviderContainer container, {
    required String title,
    required DateTime scheduledAt,
  }) async {
    late String id;
    await tester.runAsync(() async {
      await container.read(taskListProvider.notifier).createTask(
        title: title,
        scheduledAt: scheduledAt,
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.general,
      );
      id = container
          .read(taskListProvider)
          .firstWhere((t) => t.title == title)
          .id;
    });
    return id;
  }

  testWidgets(
    'with no selection, the dock shows plain Close (unchanged)',
    (tester) async {
      await pumpEditScreen(tester);

      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byTooltip('Clear selection'), findsNothing);
      expect(find.byTooltip('Edit selected'), findsNothing);
      expect(find.byTooltip('Remove selected'), findsNothing);
    },
  );

  testWidgets(
    'selecting a task swaps the dock to back-arrow / Edit / Remove',
    (tester) async {
      final container = await pumpEditScreen(tester);
      final savedId = await createTask(
        tester,
        container,
        title: 'Buy milk',
        scheduledAt: DateTime.now(),
      );

      container.read(editSelectionProvider.notifier).toggle(savedId);
      await tester.pump();

      expect(find.byTooltip('Close'), findsNothing);
      expect(find.byTooltip('Clear selection'), findsOneWidget);
      expect(find.byTooltip('Edit selected'), findsOneWidget);
      expect(find.byTooltip('Remove selected'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the back-arrow clears the selection but does not close the '
    'screen',
    (tester) async {
      final container = await pumpEditScreen(tester);
      final savedId = await createTask(
        tester,
        container,
        title: 'Buy milk',
        scheduledAt: DateTime.now(),
      );
      container.read(editSelectionProvider.notifier).toggle(savedId);
      await tester.pump();

      await tester.tap(find.byTooltip('Clear selection'));
      await tester.pump();

      expect(container.read(editSelectionProvider), isEmpty);
      // Still on the Edit screen — the back-arrow only cleared selection,
      // it did not pop this route (confirmed directly, distinct from the
      // old Close semantics).
      expect(find.byType(ZoneGridScreen), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Edit with exactly ONE task selected opens the ordinary '
    'task detail sheet, not the multi-edit sheet',
    (tester) async {
      final container = await pumpEditScreen(tester);
      final savedId = await createTask(
        tester,
        container,
        title: 'Buy milk',
        scheduledAt: DateTime.now(),
      );
      container.read(editSelectionProvider.notifier).toggle(savedId);
      await tester.pump();

      await tester.tap(find.byTooltip('Edit selected'));
      await tester.pumpAndSettle();

      // Never the multi-edit sheet's own "N tasks selected" header, nor
      // its distinctive "Notifications" row label (the single-task detail
      // sheet has its own "Tag" field too, so that text alone can't
      // disambiguate the two sheets) — the single-task path opened
      // instead (the ordinary detail sheet).
      expect(find.textContaining('tasks selected'), findsNothing);
    },
  );

  testWidgets(
    'tapping Edit with TWO tasks selected opens the multi-edit sheet',
    (tester) async {
      final container = await pumpEditScreen(tester);
      await createTask(
        tester,
        container,
        title: 'Buy milk',
        scheduledAt: DateTime.now(),
      );
      await createTask(
        tester,
        container,
        title: 'Buy eggs',
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final ids = container.read(taskListProvider).map((t) => t.id).toSet();
      for (final id in ids) {
        container.read(editSelectionProvider.notifier).toggle(id);
      }
      await tester.pump();

      await tester.tap(find.byTooltip('Edit selected'));
      await tester.pumpAndSettle();

      expect(find.text('2 tasks selected'), findsOneWidget);
      expect(find.text('Tag'), findsOneWidget);
      expect(find.text('Track'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Important'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Remove deletes every selected task and clears the selection',
    (tester) async {
      final container = await pumpEditScreen(tester);
      await createTask(
        tester,
        container,
        title: 'Buy milk',
        scheduledAt: DateTime.now(),
      );
      await createTask(
        tester,
        container,
        title: 'Buy eggs',
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final ids = container.read(taskListProvider).map((t) => t.id).toSet();
      for (final id in ids) {
        container.read(editSelectionProvider.notifier).toggle(id);
      }
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Remove selected'));
        await tester.pump();
        // `_removeSelectedTasks` awaits `deleteTask` in a LOOP (one Hive
        // write per selected task) — a single zero-delay drain only lets
        // one queued continuation resolve, not a whole sequential chain
        // of them. Poll until the real repository state settles instead
        // of guessing a fixed number of delays, same reasoning as this
        // codebase's other "drain real I/O before the block returns"
        // helpers (see docs/ERROR_LOG.md).
        for (var i = 0; i < 20 && container.read(taskListProvider).isNotEmpty;
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });

      expect(container.read(taskListProvider), isEmpty);
      expect(container.read(editSelectionProvider), isEmpty);
    },
  );

  testWidgets(
    'toggling and saving Important in the multi-edit sheet marks every '
    'selected task',
    (tester) async {
      final container = await pumpEditScreen(tester);
      await createTask(
        tester,
        container,
        title: 'Buy milk',
        scheduledAt: DateTime.now(),
      );
      await createTask(
        tester,
        container,
        title: 'Buy eggs',
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final ids = container.read(taskListProvider).map((t) => t.id).toSet();
      for (final id in ids) {
        container.read(editSelectionProvider.notifier).toggle(id);
      }
      await tester.pump();

      await tester.tap(find.byTooltip('Edit selected'));
      await tester.pumpAndSettle();

      final importantSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('Important'),
          matching: find.byType(Row),
        ),
        matching: find.byType(AppSwitch),
      );
      await tester.ensureVisible(importantSwitch);
      await tester.tap(importantSwitch);
      await tester.pump();

      final saveButton = find.text('Save');
      await tester.ensureVisible(saveButton);
      await tester.runAsync(() async {
        await tester.tap(saveButton);
        for (var i = 0;
            i < 20 &&
                !container.read(taskListProvider).every((t) => t.isImportant);
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });

      expect(
        container.read(taskListProvider).every((t) => t.isImportant),
        isTrue,
      );
    },
  );
}
