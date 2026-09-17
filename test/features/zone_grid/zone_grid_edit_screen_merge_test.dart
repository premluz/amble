import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
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

/// Covers the 2026-09-17 merge, requested directly: "we have 2 inactive
/// tabs on edit zone screen. We need to make them work and switch edit
/// zone with edit tasks views with these tabs... one entry point instead
/// of 2 in the header." `ZoneGridScreen` gained a "Tasks" tab (renamed
/// from the previously-inert "Events") that hosts the pre-existing
/// spatial Timeline, forced into its own Edit Mode, as this screen's
/// other tab — swapping wholesale between the two pre-existing screens
/// rather than merging their gesture systems (confirmed directly).
void main() {
  late Box<Task> taskBox;
  late Box<dynamic> prefsBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<TaskTemplate> taskTemplateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_zone_grid_edit_merge');
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
    ZoneGridTab initialTab = ZoneGridTab.tasks,
  }) async {
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
              // A real Scaffold underneath, pushed to from — `pop()`
              // (the "Close" button, or the system back gesture) is a
              // no-op with nothing to pop TO, which would silently skip
              // `dispose()` entirely and mask exactly the "does Edit Mode
              // leak into what's underneath" behavior this file exists
              // to check.
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
    await tester.pumpAndSettle(); // the MaterialPageRoute's own push transition
    // NOT pumpAndSettle from here on — the embedded spatial Timeline
    // never fully settles in a plain widget-test environment, same as
    // every other full-Timeline harness in this codebase (see
    // edit_mode_hides_main_nav_test.dart's own pumpHome).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  testWidgets(
    'opening on the Tasks tab shows the spatial Timeline with Edit Mode '
    'already on, and hides its own inner header (no duplicate close button)',
    (tester) async {
      final container = await pumpEditScreen(tester);

      expect(find.byType(TimelineScreen), findsOneWidget);
      expect(container.read(editModeEnabledProvider), isTrue);
      // One "Close" tooltip from the merged screen's own top row — a
      // second one would mean the embedded TimelineScreen's own
      // Edit-Mode-collapsed header rendered too (the bug `showHeader:
      // false` exists to prevent).
      expect(find.byTooltip('Close'), findsOneWidget);
    },
  );

  testWidgets(
    'switching to the Zones tab turns Edit Mode off and shows the zone grid',
    (tester) async {
      final container = await pumpEditScreen(tester);
      expect(container.read(editModeEnabledProvider), isTrue);

      await tester.tap(find.text('Zones'));
      await tester.pump();

      expect(container.read(editModeEnabledProvider), isFalse);
      expect(find.byType(TimelineScreen), findsNothing);
      expect(find.byKey(const ValueKey('zone-paint-surface')), findsOneWidget);
    },
  );

  testWidgets('switching back to Tasks from Zones turns Edit Mode on again', (
    tester,
  ) async {
    final container = await pumpEditScreen(
      tester,
      initialTab: ZoneGridTab.zones,
    );
    expect(container.read(editModeEnabledProvider), isFalse);

    await tester.tap(find.text('Tasks'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(editModeEnabledProvider), isTrue);
    expect(find.byType(TimelineScreen), findsOneWidget);
  });

  testWidgets(
    'closing the screen from the Tasks tab turns Edit Mode back off — it '
    'must not leak into whatever screen is underneath once this pops',
    (tester) async {
      final container = await pumpEditScreen(tester);
      expect(container.read(editModeEnabledProvider), isTrue);

      await tester.tap(find.byTooltip('Close'));
      // NOT pumpAndSettle — the underlying screen still holds the same
      // never-settling embedded Timeline this file's own pump helper
      // avoids pumpAndSettle for; bounded pumps carry the pop's own
      // transition through to completion (so `dispose()` actually runs)
      // without waiting on an animation that never quiesces.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(editModeEnabledProvider), isFalse);
    },
  );
}
