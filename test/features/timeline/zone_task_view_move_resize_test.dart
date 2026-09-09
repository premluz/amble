import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/dev_config.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
import 'package:amble/features/timeline/zone_background_block.dart';
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

/// Reversed 2026-09-06 (confirmed directly — "we should be able to edit
/// zones in any view ... in spatial task view also"): the Spatial Task
/// View's zone background block was purely decorative; it now supports the
/// same move/resize gestures the Spatial Zone View's own container
/// (`ZoneContainerBlock`) already has, via the same shared cascade commit
/// path (`_commitZoneCascade` in `timeline_screen.dart`).
///
/// Mirrors `zone_move_end_to_end_test.dart`'s own shape exactly (same
/// gates, same direct-callback-invocation strategy for the same
/// test-harness reason documented there) but stays in Task view
/// (`ZoneViewEnabledSetting`/`DevZoneViewInCycle` both default false here,
/// unlike that file) and drives `ZoneBackgroundBlock`'s callbacks instead
/// of `ZoneContainerBlock`'s.
class _FixedEditModeEnabled extends EditModeEnabled {
  @override
  bool build() => true;
}

/// Pinned false: this file exercises ordinary (single-zone) Edit Mode, not
/// multi-task mode's "only the selected zone wiggles/is draggable" route —
/// see `zone_move_end_to_end_test.dart`'s own copy of this override for the
/// full reasoning.
class _FixedDevMultiTaskEditMode extends DevMultiTaskEditMode {
  @override
  bool build() => false;
}

void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_zone_task_view_move_resize');
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
          // zoneViewEnabledSettingProvider/devZoneViewInCycleProvider both
          // left at their real defaults — this test's whole point is Task
          // view, not Zone view.
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(body: TimelineScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    final headerFinder = find.textContaining('Morning ritual');
    if (headerFinder.evaluate().isEmpty) {
      fail(
        'Zone block never rendered at all in Task view — regressed '
        'zone-background rendering or Edit Mode gating.',
      );
    }
    return zone;
  }

  ZoneBackgroundBlock findZoneBlock() =>
      find.byType(ZoneBackgroundBlock).evaluate().single.widget
          as ZoneBackgroundBlock;

  testWidgets(
    'dragging a zone header in the Spatial Task View (Edit Mode on) moves it',
    (tester) async {
      final zone = await pumpTaskViewWithZone(tester);
      final originalStartMinutes = zone.startMinutes;

      final block = findZoneBlock();
      expect(
        block.onMoveStart,
        isNotNull,
        reason:
            'Move is not wired for this block — Edit Mode gating or the '
            'callback chain regressed.',
      );

      await tester.runAsync(() async {
        block.onMoveStart!(DragStartDetails());
        block.onMoveUpdate!(
          DragUpdateDetails(globalPosition: Offset.zero, delta: Offset(0, 60)),
        );
        block.onMoveEnd!(DragEndDetails());
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final saved = zoneBox.get(zone.id)!;
      expect(
        saved.startMinutes,
        isNot(originalStartMinutes),
        reason:
            'Zone startMinutes unchanged after the move gesture — the '
            'move did not commit.',
      );
    },
  );

  testWidgets(
    "dragging a zone's bottom resize handle in the Spatial Task View grows it",
    (tester) async {
      final zone = await pumpTaskViewWithZone(tester);
      final originalEndMinutes = zone.endMinutes;

      final block = findZoneBlock();
      expect(
        block.onResizeBottomStart,
        isNotNull,
        reason:
            'Resize is not wired for this block — Edit Mode gating or the '
            'callback chain regressed.',
      );

      await tester.runAsync(() async {
        block.onResizeBottomStart!(DragStartDetails());
        block.onResizeBottomUpdate!(
          DragUpdateDetails(globalPosition: Offset.zero, delta: Offset(0, 60)),
        );
        block.onResizeBottomEnd!(DragEndDetails());
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final saved = zoneBox.get(zone.id)!;
      expect(
        saved.endMinutes,
        isNot(originalEndMinutes),
        reason:
            'Zone endMinutes unchanged after the resize gesture — the '
            'resize did not commit.',
      );
      expect(saved.startMinutes, zone.startMinutes);
    },
  );

  testWidgets(
    'resizing TODAY\'s materialized instance of a recurring series leaves '
    'a DIFFERENT day\'s instance of the same series completely untouched',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final otherDay = today.add(const Duration(days: 3));

      // Two rows sharing one recurrenceId — exactly what
      // `zone_recurrence_generator.dart` would materialize for a
      // recurring series, constructed directly here so the test doesn't
      // depend on the generator's own window/day-matching behavior.
      final todayInstance = Zone.create(
        title: 'Morning ritual',
        startMinutes: now.hour * 60,
        endMinutes: now.hour * 60 + 60,
        recurrenceId: 'series-1',
        anchorDate: today,
      );
      final otherDayInstance = Zone.create(
        title: 'Morning ritual',
        startMinutes: now.hour * 60,
        endMinutes: now.hour * 60 + 60,
        recurrenceId: 'series-1',
        anchorDate: otherDay,
      );
      await tester.runAsync(() async {
        await zoneBox.put(todayInstance.id, todayInstance);
        await zoneBox.put(otherDayInstance.id, otherDayInstance);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(
              HiveTaskRepository(taskBox),
            ),
            categoryRepositoryProvider.overrideWithValue(
              HiveCategoryRepository(categoryBox),
            ),
            zoneRepositoryProvider.overrideWithValue(
              HiveZoneRepository(zoneBox),
            ),
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
          child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              extensions: [AmbleTheme.light],
            ),
            home: const Scaffold(body: TimelineScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Only today's instance renders — the Timeline defaults to today.
      expect(find.byType(ZoneBackgroundBlock), findsOneWidget);
      final block = findZoneBlock();
      // Snapshotted BEFORE the drag: `Box.get` returns the same cached
      // `HiveObject` instance every time, so `todayInstance`/
      // `otherDayInstance` themselves get mutated in place the moment the
      // cascade commits — comparing against them afterward would silently
      // compare a value against itself.
      final originalTodayEnd = todayInstance.endMinutes;
      final originalOtherDayStart = otherDayInstance.startMinutes;
      final originalOtherDayEnd = otherDayInstance.endMinutes;

      await tester.runAsync(() async {
        block.onResizeBottomStart!(DragStartDetails());
        block.onResizeBottomUpdate!(
          DragUpdateDetails(globalPosition: Offset.zero, delta: Offset(0, 60)),
        );
        block.onResizeBottomEnd!(DragEndDetails());
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final savedToday = zoneBox.get(todayInstance.id)!;
      final savedOtherDay = zoneBox.get(otherDayInstance.id)!;

      expect(
        savedToday.endMinutes,
        isNot(originalTodayEnd),
        reason: 'Today\'s instance should have resized.',
      );
      expect(
        savedOtherDay.endMinutes,
        originalOtherDayEnd,
        reason:
            'A sibling occurrence in the same series must be completely '
            'untouched by resizing a different day\'s instance.',
      );
      expect(savedOtherDay.startMinutes, originalOtherDayStart);
    },
  );
}
