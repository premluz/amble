import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/resize_handle.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
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

/// A resize drag must track the finger 1:1 — reported directly:
/// "when resizing the size of pill should follow (resize top does it) but
/// resize bottom is animated so pill catches up (should follow also)...
/// and also when resize top seem that pill is moving not only resizing
/// top... and it moves and 'settles' with animation. This should be
/// settled continually, only the side that is being dragged resizes."
///
/// Two separate animations caused this, one per edge:
/// - BOTTOM: `TaskCapsuleBlock`'s pill-height `AnimatedContainer`
///   (`motionSlow`), which exists so a duration change from the edit modal
///   or a cascade visibly grows the pill — under a finger it lagged.
/// - TOP: the block's own `AnimatedPositioned`, which was only un-animated
///   while `_isDragging`. A top-resize moves `top` too, so it eased.
///
/// These assert the OBSERVABLE consequence (geometry matches the finger on
/// the very next frame, with no pending animation to settle) rather than
/// the private flags, so they still hold if the implementation changes.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  late Box<TaskTemplate> templateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_resize_tracks_finger');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final suffix = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$suffix');
    categoryBox = await openSeededCategoryBox('test_categories_$suffix');
    zoneBox = await Hive.openBox<Zone>('test_zones_$suffix');
    trackedBehaviorBox = await Hive.openBox<TrackedBehavior>(
      'test_tracked_behaviors_$suffix',
    );
    preferencesBox = await Hive.openBox<dynamic>('test_preferences_$suffix');
    templateBox = await Hive.openBox<TaskTemplate>('test_templates_$suffix');
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await zoneBox.close();
    await trackedBehaviorBox.close();
    await preferencesBox.close();
    await templateBox.close();
  });

  Future<void> pumpTimeline(WidgetTester tester, {required Task task}) async {
    await tester.runAsync(() => taskBox.put(task.id, task));

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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
          taskTemplateRepositoryProvider.overrideWithValue(
            HiveTaskTemplateRepository(templateBox),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(
            body: TimelineScreen(mode: TimelineDisplayMode.spatial),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Anchored off `now` for the same reason every other file here does —
  // a fixed clock hour only stays on-screen by coincidence of run time.
  Task makeTask(String title, {int minutes = 120}) {
    final now = DateTime.now();
    final minutesSinceMidnight = (now.hour * 60 + now.minute).clamp(
      60,
      24 * 60 - 1 - minutes,
    );
    return Task.create(
      title: title,
      scheduledAt: DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(minutes: minutesSinceMidnight)),
      durationMinutes: minutes,
      categoryId: BuiltInCategoryIds.work,
    );
  }

  Finder pillFor(String title) => find.byWidgetPredicate(
    (widget) => widget is TaskCapsuleBlock && widget.task.title == title,
  );

  // The RAIL — the one AnimatedContainer inside a TaskCapsuleBlock, and
  // the only thing actually sized by `pillHeight`.
  //
  // **Corrected 2026-09-12.** These tests previously measured
  // `getRect(pillFor(...))`, i.e. the capsule's ROOT — an IntrinsicHeight
  // Row whose height comes from the title/checkbox column, not from the
  // task's duration. It barely moves during a resize, so these assertions
  // passed while the real pill was still visibly lagging: a measurement
  // bug that made the whole file prove nothing.
  Finder railFor(String title) => find
      .descendant(of: pillFor(title), matching: find.byType(AnimatedContainer))
      .first;

  Finder topHandleFor(String title) => find
      .descendant(of: pillFor(title), matching: find.byType(ResizeHandle))
      .first;
  Finder bottomHandleFor(String title) => find
      .descendant(of: pillFor(title), matching: find.byType(ResizeHandle))
      .last;

  testWidgets(
    'a bottom-edge resize grows the pill on the SAME frame as the drag — '
    'no animation left pending to settle afterwards',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, task: task);

      await tester.longPress(find.text('Focus block'));
      await tester.pump();

      await tester.runAsync(() async {
        final startRect = tester.getRect(railFor('Focus block'));
        final gesture = await tester.startGesture(
          tester.getCenter(bottomHandleFor('Focus block')),
        );
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(0, 6));
          await tester.pump();
        }

        final duringRect = tester.getRect(railFor('Focus block'));
        expect(
          duringRect.height,
          greaterThan(startRect.height),
          reason: 'the pill must already be taller mid-drag',
        );

        // The actual bug: with an animated height, pumping more frames
        // WITHOUT moving the finger kept changing the geometry as the
        // tween caught up. Tracking 1:1 means a still finger means a
        // still pill.
        await tester.pump(const Duration(milliseconds: 400));
        final settledRect = tester.getRect(railFor('Focus block'));
        expect(
          settledRect.height,
          closeTo(duringRect.height, 0.5),
          reason:
              'the pill kept growing after the finger stopped — it was '
              'animating toward the drag instead of following it',
        );

        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets(
    'a top-edge resize moves the pill\'s top on the SAME frame as the '
    'drag — it does not ease into position afterwards',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, task: task);

      await tester.longPress(find.text('Focus block'));
      await tester.pump();

      await tester.runAsync(() async {
        final startRect = tester.getRect(railFor('Focus block'));
        final gesture = await tester.startGesture(
          tester.getCenter(topHandleFor('Focus block')),
        );
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(0, 6));
          await tester.pump();
        }

        final duringRect = tester.getRect(railFor('Focus block'));
        expect(
          duringRect.top,
          greaterThan(startRect.top),
          reason: 'dragging the top edge down must move the top down',
        );

        await tester.pump(const Duration(milliseconds: 400));
        final settledRect = tester.getRect(railFor('Focus block'));
        expect(
          settledRect.top,
          closeTo(duringRect.top, 0.5),
          reason:
              'the pill kept sliding after the finger stopped — the '
              'reported "moves and settles with animation"',
        );

        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets(
    'only the dragged edge moves — a bottom-edge resize leaves the pill\'s '
    'own top exactly where it was',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, task: task);

      await tester.longPress(find.text('Focus block'));
      await tester.pump();

      await tester.runAsync(() async {
        final startRect = tester.getRect(railFor('Focus block'));
        final gesture = await tester.startGesture(
          tester.getCenter(bottomHandleFor('Focus block')),
        );
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(0, 6));
          await tester.pump();
        }

        final duringRect = tester.getRect(railFor('Focus block'));
        expect(
          duringRect.top,
          // 1.5px, not an exact match: `baseTop` is a fractional pixel
          // value (minutes x pixelsPerMinute) and the rendered rect snaps
          // to whole device pixels, so a ~1px difference here is paint
          // rounding rather than movement. Confirmed pre-existing —
          // measured at 0.86px on unmodified `main`, with no resize
          // involved. Anything larger would be the real "anchored edge
          // drifted" bug this guards.
          closeTo(startRect.top, 1.5),
          reason:
              'requested directly: "only the side that is being dragged '
              'resizes" — the anchored edge must not drift',
        );

        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );
}
