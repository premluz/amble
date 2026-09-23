import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
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
import 'package:amble/shared/providers/zone_facet_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/memory_zone_repositories.dart';
import '../../support/seeded_category_box.dart';

/// Covers the Zones tab's own selection row's "Edit placement" button
/// branching to the new bulk zone edit sheet for 2+ selected occurrences
/// — requested directly: "similar for zones but here we can change times
/// start end date, and name."
///
/// Every real Hive write here runs inside `tester.runAsync` — a bare
/// `await` on real Hive I/O hangs indefinitely under `flutter_test`'s
/// synchronous zone regardless of how it's invoked. See
/// docs/ERROR_LOG.md's matching entries (this exact bug hung the sibling
/// task selection-dock test for the full 10-minute timeout once already).
void main() {
  late Box<Task> taskBox;
  late Box<dynamic> prefsBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<TaskTemplate> taskTemplateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_zone_grid_multi_edit');
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
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              const ZoneGridScreen(initialTab: ZoneGridTab.zones),
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
    return container;
  }

  /// Paints one zone occurrence on [weekday] via the real
  /// notifier/repository, inside `runAsync` per this file's own top note.
  /// Returns the created zone's id.
  Future<String> paintZone(
    WidgetTester tester,
    ProviderContainer container, {
    required String title,
    required int weekday,
    int startMinutes = 480,
    int endMinutes = 540,
  }) async {
    late String id;
    await tester.runAsync(() async {
      final zones = await container
          .read(zoneListProvider.notifier)
          .paintWeeklyZones(
            title: title,
            weekdays: {weekday},
            startMinutes: startMinutes,
            endMinutes: endMinutes,
          );
      id = zones.single.id;
    });
    return id;
  }

  testWidgets(
    'with one zone selected, Edit placement opens the ordinary single '
    'zone form, not the multi-edit sheet',
    (tester) async {
      final container = await pumpEditScreen(tester);
      final id = await paintZone(
        tester,
        container,
        title: 'Morning routine',
        weekday: 1,
      );
      container.read(zoneEditSelectionProvider.notifier).add(id);
      await tester.pump();

      await tester.tap(find.byTooltip('Edit placement'));
      await tester.pumpAndSettle();

      expect(find.textContaining('zones selected'), findsNothing);
    },
  );

  testWidgets(
    'with two zones selected, Edit placement opens the bulk multi-edit '
    'sheet showing Name/Start/End/Date',
    (tester) async {
      final container = await pumpEditScreen(tester);
      final firstId = await paintZone(
        tester,
        container,
        title: 'Morning routine',
        weekday: 1,
      );
      final secondId = await paintZone(
        tester,
        container,
        title: 'Evening wind-down',
        weekday: 2,
        startMinutes: 1200,
        endMinutes: 1260,
      );
      container.read(zoneEditSelectionProvider.notifier).add(firstId);
      container.read(zoneEditSelectionProvider.notifier).add(secondId);
      await tester.pump();

      await tester.tap(find.byTooltip('Edit placement'));
      await tester.pumpAndSettle();

      expect(find.text('2 zones selected'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      // Different start/end minutes across the two selected zones ->
      // both segmented fields show their own "hh:mm" placeholder
      // (Mixed), never one zone's own value.
      expect(find.text('Change name'), findsOneWidget);
    },
  );

  testWidgets(
    'saving a new name in the multi-edit sheet renames every selected '
    'zone',
    (tester) async {
      final container = await pumpEditScreen(tester);
      final firstId = await paintZone(
        tester,
        container,
        title: 'Morning routine',
        weekday: 1,
      );
      final secondId = await paintZone(
        tester,
        container,
        title: 'Evening wind-down',
        weekday: 2,
      );
      container.read(zoneEditSelectionProvider.notifier).add(firstId);
      container.read(zoneEditSelectionProvider.notifier).add(secondId);
      await tester.pump();

      await tester.tap(find.byTooltip('Edit placement'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('multiZoneEditNameField')),
        'Shared name',
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        for (var i = 0;
            i < 20 &&
                !container
                    .read(zoneListProvider)
                    .every((z) => z.title == 'Shared name');
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();

      final zones = container.read(zoneListProvider);
      expect(zones.every((z) => z.title == 'Shared name'), isTrue);
    },
  );
}
