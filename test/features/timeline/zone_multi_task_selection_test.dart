import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/dev_config.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
import 'package:amble/features/timeline/edit_selection_provider.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
import 'package:amble/features/timeline/zone_background_block.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

import '../../support/fake_notification_service.dart';

/// Reported directly: "zones should not wiggle (be editable) in multi mode,
/// only when selected" — before this fix, a zone's move/resize handles
/// (and wiggle) rendered whenever Edit Mode was on, regardless of
/// `DevMultiTaskEditMode`, unlike a task's own identical rule (see
/// `multi_task_selection_test.dart`). Covers the Task view's own
/// `_DraggableZoneBlock`/`ZoneBackgroundBlock` fix — `zone_day_timeline`
/// (Zone view) got the same fix, verified separately since it's a distinct
/// widget tree.
class _FixedEditModeEnabled extends EditModeEnabled {
  @override
  bool build() => true;
}

class _FixedDevMultiTaskEditMode extends DevMultiTaskEditMode {
  @override
  bool build() => true;
}

void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  late ProviderContainer? capturedContainer;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_zone_multi_task_selection');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    categoryBox = await Hive.openBox<Category>('test_categories_$stamp');
    await categoryBox.put(
      BuiltInCategoryIds.general,
      Category(
        id: BuiltInCategoryIds.general,
        name: 'General',
        colorToken: 0,
        emoji: '⚪',
        isBuiltIn: true,
      ),
    );
    zoneBox = await Hive.openBox<Zone>('test_zones_$stamp');
    trackedBehaviorBox = await Hive.openBox<TrackedBehavior>(
      'test_tracked_behaviors_$stamp',
    );
    preferencesBox = await Hive.openBox<dynamic>('test_preferences_$stamp');
    capturedContainer = null;
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await zoneBox.close();
    await trackedBehaviorBox.close();
    await preferencesBox.close();
  });

  Future<Zone> pumpTaskViewWithZone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final zone = Zone.create(
      title: 'Morning ritual',
      startMinutes: now.hour * 60,
      endMinutes: now.hour * 60 + 60,
    );
    await tester.runAsync(() => zoneBox.put(zone.id, zone));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categoryBox),
          ),
          zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zoneBox)),
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(trackedBehaviorBox),
          ),
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(preferencesBox),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          editModeEnabledProvider.overrideWith(() => _FixedEditModeEnabled()),
          devMultiTaskEditModeProvider.overrideWith(
            () => _FixedDevMultiTaskEditMode(),
          ),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            capturedContainer = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: [AmbleTheme.light],
              ),
              home: const Scaffold(
                body: TimelineScreen(mode: TimelineDisplayMode.spatial),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    final headerFinder = find.textContaining('Morning ritual');
    if (headerFinder.evaluate().isEmpty) {
      fail('Zone block never rendered at all in Task view.');
    }
    return zone;
  }

  ZoneBackgroundBlock findZoneBlock() =>
      find.byType(ZoneBackgroundBlock).evaluate().single.widget
          as ZoneBackgroundBlock;

  testWidgets(
    'with multi-task mode ON and nothing selected, a zone has no move/resize '
    'handlers wired',
    (tester) async {
      await pumpTaskViewWithZone(tester);

      final block = findZoneBlock();
      expect(
        block.onMoveEnd,
        isNull,
        reason:
            'An unselected zone must not be draggable under multi-task '
            'mode.',
      );
      expect(block.onResizeTopEnd, isNull);
      expect(block.onResizeBottomEnd, isNull);
      // Tap-to-select stays live even while nothing is selected — that's
      // the only way to ever select a zone.
      expect(block.onHeaderTap, isNotNull);
    },
  );

  testWidgets('tapping a zone header selects it under multi-task mode', (
    tester,
  ) async {
    final zone = await pumpTaskViewWithZone(tester);

    final block = findZoneBlock();
    block.onHeaderTap!();
    await tester.pump();

    expect(
      capturedContainer!.read(zoneEditSelectionProvider),
      contains(zone.id),
    );
  });

  testWidgets('once selected, a zone gets move/resize handlers back', (
    tester,
  ) async {
    final zone = await pumpTaskViewWithZone(tester);

    capturedContainer!.read(zoneEditSelectionProvider.notifier).toggle(zone.id);
    await tester.pump();

    final block = findZoneBlock();
    expect(block.onMoveEnd, isNotNull);
    expect(block.onResizeTopEnd, isNotNull);
    expect(block.onResizeBottomEnd, isNotNull);
  });

  testWidgets('turning multi-task mode off clears the zone selection', (
    tester,
  ) async {
    final zone = await pumpTaskViewWithZone(tester);

    capturedContainer!.read(zoneEditSelectionProvider.notifier).toggle(zone.id);
    await tester.pump();
    expect(
      capturedContainer!.read(zoneEditSelectionProvider),
      contains(zone.id),
    );

    capturedContainer!.read(devMultiTaskEditModeProvider.notifier).set(false);
    await tester.pump();

    expect(capturedContainer!.read(zoneEditSelectionProvider), isEmpty);
  });
}
