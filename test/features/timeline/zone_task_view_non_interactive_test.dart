import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
import 'package:amble/features/timeline/edit_selection_provider.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
import 'package:amble/features/timeline/zone_background_block.dart';
import 'package:amble/hive_registrar.g.dart';
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

/// Requested directly: "turn off edit zones (tap on zones) on tasks edit."
/// Zones on the spatial Task view's Edit Mode used to be tap-selectable
/// (revealing resize handles, move-drag, and drag-to-delete) — that whole
/// interaction is now removed. Zones render as purely decorative
/// background bands there, same as outside Edit Mode; zone editing still
/// lives on the merged Edit screen's own dedicated Zones tab
/// (`ZoneGridScreen`), unaffected by this. Supersedes
/// `zone_task_view_move_resize_test.dart`/`zone_multi_task_selection_test.dart`
/// (both deleted — they tested exactly the interaction this removes).
class _FixedEditModeEnabled extends EditModeEnabled {
  @override
  bool build() => true;
}

void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  late Box<TaskTemplate> templateBox;
  late ProviderContainer? capturedContainer;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_zone_task_view_non_interactive');
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
    templateBox = await Hive.openBox<TaskTemplate>('test_templates_$stamp');
    capturedContainer = null;
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await zoneBox.close();
    await trackedBehaviorBox.close();
    await preferencesBox.close();
    await templateBox.close();
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
          taskTemplateRepositoryProvider.overrideWithValue(
            HiveTaskTemplateRepository(templateBox),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          editModeEnabledProvider.overrideWith(() => _FixedEditModeEnabled()),
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

  testWidgets('in Task Edit Mode, a zone has no header tap wired at all', (
    tester,
  ) async {
    await pumpTaskViewWithZone(tester);

    final block = findZoneBlock();
    expect(block.onHeaderTap, isNull);
    expect(block.editModeEnabled, isFalse);
  });

  testWidgets(
    'in Task Edit Mode, a zone has no move/resize/delete handlers wired',
    (tester) async {
      await pumpTaskViewWithZone(tester);

      final block = findZoneBlock();
      expect(block.onMoveEnd, isNull);
      expect(block.onResizeTopEnd, isNull);
      expect(block.onResizeBottomEnd, isNull);
    },
  );

  testWidgets('tapping a zone\'s own fill in Task Edit Mode does not select '
      'it — the zone selection set stays empty', (tester) async {
    final zone = await pumpTaskViewWithZone(tester);

    // The zone NAME label is always IgnorePointer-wrapped (purely
    // decorative, unrelated to this fix — see ZoneNameLabel's own doc
    // comment), so tapping IT never reached the zone's own header
    // GestureDetector even before this change. Tap the zone's own FILL
    // instead — its real rendered rect, per ZoneBackgroundBlock.
    final rect = tester.getRect(find.byType(ZoneBackgroundBlock));
    await tester.tapAt(rect.center);
    await tester.pump();

    expect(
      capturedContainer!.read(zoneEditSelectionProvider),
      isNot(contains(zone.id)),
    );
    expect(capturedContainer!.read(zoneEditSelectionProvider), isEmpty);
  });

  testWidgets(
    'the zone still renders as a plain decorative band — same as outside '
    'Edit Mode, just non-interactive',
    (tester) async {
      await pumpTaskViewWithZone(tester);

      expect(find.byType(ZoneBackgroundBlock), findsOneWidget);
      expect(find.textContaining('Morning ritual'), findsOneWidget);
    },
  );

  // Pins the band's own EXTENT, which had flipped twice with nothing
  // guarding it: it spanned the full content row, was narrowed on
  // 2026-09-23 to column 2's own `timelineZoneWidth` (stopping one gutter
  // short of the content column), and was then restored to full width
  // when a four-panel now/to-be comparison asked for it directly across
  // both views ("it's full content size").
  //
  // A zone is the container its tasks live INSIDE, so its band is the
  // backdrop behind the whole row — pill AND name — which is what the
  // non-spatial view's own card already does. Column 2's width still
  // governs where PILLS sit, so widening the band moves no task.
  testWidgets(
    'the zone band spans the FULL content width — from column 2\'s own '
    'left edge to the screen\'s right padding, not stopping at '
    'timelineZoneWidth beside the content column',
    (tester) async {
      await pumpTaskViewWithZone(tester);

      const viewportWidth = 430.0;
      final theme = AmbleTheme.light;
      final rect = tester.getRect(find.byType(ZoneBackgroundBlock));

      // ZoneBackgroundBlock trims its own rendered width by
      // `zoneBackgroundGap` and extends it left by `zoneBackgroundOffset`
      // (both purely cosmetic — see that widget's own doc comments), so
      // the band's right edge lands that combined nudge inside the
      // screen's own padding. Checked as an edge position rather than a
      // bare width so the cosmetic offsets stay visible in the math.
      expect(
        rect.right,
        moreOrLessEquals(
          viewportWidth -
              theme.spacingScreenPadding -
              zoneBackgroundGap -
              zoneBackgroundOffset,
          epsilon: 1.0,
        ),
        reason:
            'the band must reach the screen edge padding, not stop one '
            'gutter short of the content column',
      );

      // Guards the specific value this reverses: the narrow band would
      // have ended a full content column short of here.
      final narrowRight =
          theme.timelineZoneLeft + theme.timelineZoneWidth(viewportWidth);
      expect(
        rect.right,
        greaterThan(narrowRight + 1),
        reason: 'the band must be wider than column 2 alone',
      );
    },
  );
}
