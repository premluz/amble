import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_bottom_dock.dart';
import 'package:amble/core/widgets/app_shell_chrome.dart';
import 'package:amble/core/widgets/app_switch.dart';
import 'package:amble/core/widgets/app_tab_switch.dart';
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
import 'package:amble/shared/providers/zone_facet_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/memory_zone_repositories.dart';
import '../../support/seeded_category_box.dart';

/// Covers the Edit screen's selection toolbar: Back always closes Edit, while
/// Edit/Remove appear for selected tasks and zones.
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

  Future<ProviderContainer> pumpEditScreen(
    WidgetTester tester, {
    bool useShellDock = false,
    ZoneGridTab initialTab = ZoneGridTab.tasks,
  }) async {
    late ProviderContainer container;
    final shellChromeController = useShellDock
        ? AppShellChromeController()
        : null;
    if (shellChromeController != null) {
      addTearDown(shellChromeController.dispose);
    }
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
          zoneFacetRepositoryProvider.overrideWithValue(
            MemoryZoneFacetRepository(),
          ),
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
              builder: shellChromeController == null
                  ? null
                  : (context, child) => AppShellChromeScope(
                      controller: shellChromeController,
                      child: Overlay(
                        initialEntries: [
                          OverlayEntry(
                            builder: (_) => Stack(
                              children: [
                                child!,
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: SafeArea(
                                    top: false,
                                    child: AppBottomDock(
                                      activeView: AppBottomDockView.timeline,
                                      onSelectView: (_) {},
                                      onEditTap: () {},
                                      whatMattersEnabled: false,
                                      onWhatMattersTap: () {},
                                      visible: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              ZoneGridScreen(initialTab: initialTab),
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
      await container
          .read(taskListProvider.notifier)
          .createTask(
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

  testWidgets('with no selection, the dock shows plain Close (unchanged)', (
    tester,
  ) async {
    await pumpEditScreen(tester);

    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byTooltip('Clear selection'), findsNothing);
    expect(find.byTooltip('Edit selected'), findsNothing);
    expect(find.byTooltip('Remove selected'), findsNothing);
  });

  testWidgets('selecting a task keeps Close and adds Edit / Remove', (
    tester,
  ) async {
    final container = await pumpEditScreen(tester);
    final savedId = await createTask(
      tester,
      container,
      title: 'Buy milk',
      scheduledAt: DateTime.now(),
    );

    container.read(editSelectionProvider.notifier).toggle(savedId);
    await tester.pump();

    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byTooltip('Clear selection'), findsOneWidget);
    expect(find.byTooltip('Edit selected'), findsOneWidget);
    expect(find.byTooltip('Remove selected'), findsOneWidget);
  });

  testWidgets('Deselect clears multi-task selection without exiting Edit', (
    tester,
  ) async {
    final container = await pumpEditScreen(tester);
    final firstId = await createTask(
      tester,
      container,
      title: 'Buy milk',
      scheduledAt: DateTime.now(),
    );
    final secondId = await createTask(
      tester,
      container,
      title: 'Call Alex',
      scheduledAt: DateTime.now().add(const Duration(hours: 1)),
    );
    container.read(editSelectionProvider.notifier).toggle(firstId);
    container.read(editSelectionProvider.notifier).toggle(secondId);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byTooltip('Clear selection'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear selection'));
    await tester.pumpAndSettle();

    expect(container.read(editSelectionProvider), isEmpty);
    expect(find.byType(ZoneGridScreen), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets('Back exits task Edit and clears the selected task', (
    tester,
  ) async {
    final container = await pumpEditScreen(tester);
    final savedId = await createTask(
      tester,
      container,
      title: 'Buy milk',
      scheduledAt: DateTime.now(),
    );
    container.read(editSelectionProvider.notifier).toggle(savedId);
    await tester.pump();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(container.read(editSelectionProvider), isEmpty);
    expect(find.byType(ZoneGridScreen), findsNothing);
    expect(find.byTooltip('Close'), findsNothing);
  });

  testWidgets('Back exits Zone Edit and clears the selected zone', (
    tester,
  ) async {
    final container = await pumpEditScreen(
      tester,
      initialTab: ZoneGridTab.zones,
    );
    late Zone zone;
    await tester.runAsync(() async {
      zone =
          (await container
                  .read(zoneListProvider.notifier)
                  .paintWeeklyZones(
                    title: 'Focus',
                    weekdays: {1},
                    startMinutes: 240,
                    endMinutes: 300,
                  ))
              .single;
    });
    await tester.pump();
    container.read(zoneEditSelectionProvider.notifier).add(zone.id);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close zones'), findsOneWidget);
    await tester.tap(find.byTooltip('Close zones'));
    await tester.pumpAndSettle();

    expect(container.read(zoneEditSelectionProvider), isEmpty);
    expect(find.byType(ZoneGridScreen), findsNothing);
  });

  testWidgets('switching Tasks and Zones clears both edit selections', (
    tester,
  ) async {
    final container = await pumpEditScreen(tester);
    void switchTo(ZoneGridTab tab) {
      tester
          .widget<AppTabSwitch<ZoneGridTab>>(
            find.byType(AppTabSwitch<ZoneGridTab>).first,
          )
          .onChanged(tab);
    }

    container.read(editSelectionProvider.notifier).toggle('task-id');
    container.read(zoneEditSelectionProvider.notifier).add('zone-id');
    await tester.pump();
    switchTo(ZoneGridTab.zones);
    await tester.pump();

    expect(container.read(editSelectionProvider), isEmpty);
    expect(container.read(zoneEditSelectionProvider), isEmpty);

    container.read(editSelectionProvider.notifier).toggle('task-id');
    container.read(zoneEditSelectionProvider.notifier).add('zone-id');
    await tester.pump();
    switchTo(ZoneGridTab.tasks);
    await tester.pump();

    expect(container.read(editSelectionProvider), isEmpty);
    expect(container.read(zoneEditSelectionProvider), isEmpty);
  });

  testWidgets('tapping Edit with exactly ONE task selected opens the ordinary '
      'task detail sheet, not the multi-edit sheet', (tester) async {
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

    expect(container.read(editSelectionProvider), isEmpty);
    // Never the multi-edit sheet's own "N tasks selected" header, nor
    // its distinctive "Notifications" row label (the single-task detail
    // sheet has its own "Tag" field too, so that text alone can't
    // disambiguate the two sheets) — the single-task path opened
    // instead (the ordinary detail sheet).
    expect(find.textContaining('tasks selected'), findsNothing);
  });

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

      expect(container.read(editSelectionProvider), isEmpty);
      expect(find.text('2 tasks selected'), findsOneWidget);
      expect(find.text('Label'), findsOneWidget);
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
        // Batch deletion still writes to real Hive storage, so poll until
        // the repository state settles rather than guessing a fixed delay.
        for (
          var i = 0;
          i < 20 && container.read(taskListProvider).isNotEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });

      expect(container.read(taskListProvider), isEmpty);
      expect(container.read(editSelectionProvider), isEmpty);
    },
  );

  testWidgets(
    'shell dock Remove uses tasks added after the selection action appears',
    (tester) async {
      final container = await pumpEditScreen(tester, useShellDock: true);
      final firstId = await createTask(
        tester,
        container,
        title: 'Buy milk',
        scheduledAt: DateTime.now(),
      );
      final secondId = await createTask(
        tester,
        container,
        title: 'Buy eggs',
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      );

      container.read(editSelectionProvider.notifier).toggle(firstId);
      await tester.pump();
      container.read(editSelectionProvider.notifier).toggle(secondId);
      await tester.pump();

      expect(container.read(editSelectionProvider), {firstId, secondId});
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Remove selected'));
        for (
          var i = 0;
          i < 20 && container.read(taskListProvider).isNotEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });

      expect(container.read(taskListProvider), isEmpty);
      expect(container.read(editSelectionProvider), isEmpty);
    },
  );

  testWidgets(
    'shell dock Edit uses tasks added after the selection action appears',
    (tester) async {
      final container = await pumpEditScreen(tester, useShellDock: true);
      final firstId = await createTask(
        tester,
        container,
        title: 'Buy milk',
        scheduledAt: DateTime.now(),
      );
      final secondId = await createTask(
        tester,
        container,
        title: 'Buy eggs',
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      );

      container.read(editSelectionProvider.notifier).toggle(firstId);
      await tester.pump();
      container.read(editSelectionProvider.notifier).toggle(secondId);
      await tester.pump();

      await tester.tap(find.byTooltip('Edit selected'));
      await tester.pumpAndSettle();

      expect(find.text('2 tasks selected'), findsOneWidget);
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
        for (
          var i = 0;
          i < 20 &&
              !container.read(taskListProvider).every((t) => t.isImportant);
          i++
        ) {
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
