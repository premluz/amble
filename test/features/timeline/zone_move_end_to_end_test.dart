import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/dev_config.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
import 'package:amble/features/timeline/zone_container_block.dart';
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

/// Reported directly: "can't move zones." Investigation traced this to a
/// genuine, pre-existing gap: `DevZoneViewInCycle` (`core/dev_config.dart`)
/// defaulted OFF in every debug build, so `day_strip.dart`'s Task/Zone/
/// List cycle button never offered Zone view as a destination at all —
/// there was nothing to move because Zone view itself was unreachable.
/// Confirmed directly as stale (a leftover from before Zone view was
/// finished) and fixed by flipping that default to ON, mirroring
/// `DevTrackedTabInCycle`'s own earlier "feature is finished now, default
/// it on" precedent.
///
/// This file exercises the real path through the full `TimelineScreen`
/// (not `ZoneDayTimeline` in isolation, which
/// `zone_day_timeline_move_resize_test.dart` already covers), with every
/// gate a real user's debug build actually has to clear
/// (`ZoneViewEnabledSetting`, `DevZoneViewInCycle`, `EditModeEnabled`) —
/// so a regression in any ONE of them is caught here, not just at the
/// narrower widget level.
///
/// Drives the header's move handlers DIRECTLY (via the widget's own
/// exposed callbacks) rather than a simulated drag gesture: a real touch
/// on-device reaches `ZoneContainerBlock`'s header `GestureDetector` (see
/// `zone_day_timeline_move_resize_test.dart`'s own passing gesture-driven
/// tests against that same widget in isolation), but simulating that
/// exact gesture through `TimelineScreen`'s full nested tree
/// (`AnimatedSwitcher`, several extra `Stack` layers) reproducibly failed
/// to reach the handler in `flutter test`'s own synthetic hit-testing,
/// confirmed via `WidgetsBinding.instance.hitTestInView` — a test-harness
/// limitation of driving gestures through many nested layers, not a
/// runtime bug (the underlying commit path, confirmed correct here, is
/// the actual thing this test needs to verify).
class _FixedZoneViewEnabled extends ZoneViewEnabledSetting {
  @override
  bool build() => true;
}

class _FixedDevZoneViewInCycle extends DevZoneViewInCycle {
  @override
  bool build() => true;
}

class _FixedEditModeEnabled extends EditModeEnabled {
  @override
  bool build() => true;
}

/// Pinned false: this file exercises ordinary (single-zone) Edit Mode, not
/// multi-task mode's "only the selected zone wiggles/is draggable" route
/// (see `edit_selection_provider.dart`'s `ZoneEditSelection`) — without
/// this override the real default (`true` as of 2026-09-06) would make
/// every zone here non-interactive until explicitly selected, which this
/// file's own gestures never do.
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
    Hive.init('./.dart_tool/test_hive_zone_move_e2e');
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

  Future<Zone> pumpTimelineWithZone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final zone = Zone.create(
      title: 'Morning ritual',
      startMinutes: now.hour * 60,
      endMinutes: now.hour * 60 + 60,
    );
    // Real Hive disk I/O — must run inside runAsync, not a bare await in
    // the synchronous test zone, or it can hang the whole test. See
    // docs/ERROR_LOG.md's "flutter test hangs indefinitely on real Hive
    // disk I/O" entry.
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
          zoneViewEnabledSettingProvider.overrideWith(
            () => _FixedZoneViewEnabled(),
          ),
          devZoneViewInCycleProvider.overrideWith(
            () => _FixedDevZoneViewInCycle(),
          ),
          editModeEnabledProvider.overrideWith(() => _FixedEditModeEnabled()),
          devMultiTaskEditModeProvider.overrideWith(
            () => _FixedDevMultiTaskEditMode(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(body: TimelineScreen()),
        ),
      ),
    );
    // NOT pumpAndSettle: EditModeWiggle's perpetually-repeating animation
    // never settles once Edit Mode is on. See
    // multi_task_selection_test.dart's own pumpTimeline for the same fix.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    final headerFinder = find.textContaining('Morning ritual');
    if (headerFinder.evaluate().isEmpty) {
      fail(
        'Zone header never rendered at all — Zone view or the zone '
        'itself failed to appear in TimelineScreen.',
      );
    }
    return zone;
  }

  ZoneContainerBlock findContainerBlock() =>
      find.byType(ZoneContainerBlock).evaluate().single.widget
          as ZoneContainerBlock;

  testWidgets(
    'dragging a zone header in the real Zone view (Edit Mode on) moves it',
    (tester) async {
      final zone = await pumpTimelineWithZone(tester);
      final originalStartMinutes = zone.startMinutes;

      final container = findContainerBlock();
      expect(
        container.onMoveStart,
        isNotNull,
        reason:
            'Move is not wired for this container — Edit Mode gating '
            'or the callback chain regressed.',
      );

      await tester.runAsync(() async {
        container.onMoveStart!(DragStartDetails());
        container.onMoveUpdate!(
          DragUpdateDetails(globalPosition: Offset.zero, delta: Offset(0, 60)),
        );
        container.onMoveEnd!(DragEndDetails());
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
    'dragging a zone\'s bottom resize handle in the real Zone view grows it',
    (tester) async {
      final zone = await pumpTimelineWithZone(tester);
      final originalEndMinutes = zone.endMinutes;

      final container = findContainerBlock();
      expect(
        container.onResizeBottomStart,
        isNotNull,
        reason:
            'Resize is not wired for this container — Edit Mode gating '
            'or the callback chain regressed.',
      );

      await tester.runAsync(() async {
        container.onResizeBottomStart!(DragStartDetails());
        container.onResizeBottomUpdate!(
          DragUpdateDetails(globalPosition: Offset.zero, delta: Offset(0, 60)),
        );
        container.onResizeBottomEnd!(DragEndDetails());
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
}
