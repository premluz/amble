import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/resize_handle.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/task_edge_time_label.dart';
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

/// The anchored edge must NOT move, and the dragged edge must follow the
/// finger continuously — reported directly after a first fix only removed
/// the easing:
///
/// > "when resizing top, I seem to be moving the pill and the bottom part
/// > of it is adjusting... it's almost like I'm moving the pill and the
/// > bottom is being resized downward... And also the blue badge with
/// > time, end time is moving around while it should remain fixed."
///
/// **The bug these exist for.** A top-edge drag shifts the block's `top`
/// down by the start delta and shrinks its height by that same delta, so
/// the two cancel and the END stays put. But the pill's rendered height is
/// floored at `sizeTaskBadge` (24px = ~16 minutes at the default scale,
/// three times the 5-minute duration floor that was being clamped
/// against). Past that floor the height freezes while `top` keeps moving,
/// so the whole pill slides downward and the end badge — which was
/// positioned off the same floored height — slid with it.
///
/// `resize_tracks_finger_test.dart` never caught this because it drags a
/// 120-minute task a few pixels: nowhere near the floor.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  late Box<TaskTemplate> templateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_resize_anchored_edge');
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

  // Anchored off `now`, like every other fixture in this directory.
  Task makeTask(String title, {int minutes = 30}) {
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
  // `getRect(pillFor(...))` measures the capsule's ROOT, which is an
  // IntrinsicHeight Row (rail + title + checkbox): its height comes from
  // the text column, not from the duration, so it barely moves during a
  // resize. Measuring it is why an earlier pass of these tests passed
  // while the real pill was still visibly wrong.
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
    'dragging the TOP handle far enough to hit the pill-height floor still '
    'leaves the BOTTOM edge anchored — the pill must not start sliding '
    'downward once it can no longer shrink',
    (tester) async {
      // 30 minutes: at the default scale its pill is ~45px, so dragging
      // ~30px down takes it well past the ~24px height floor.
      final task = makeTask('Focus block', minutes: 30);
      await pumpTimeline(tester, task: task);

      await tester.longPress(find.text('Focus block'));
      await tester.pump();

      await tester.runAsync(() async {
        final startRect = tester.getRect(railFor('Focus block'));
        final gesture = await tester.startGesture(
          tester.getCenter(topHandleFor('Focus block')),
        );

        var maxBottomDrift = 0.0;
        // Drag well past the floor, sampling the bottom edge the whole
        // way — the slide only begins after the floor is crossed, so a
        // single end-of-drag assertion could miss it.
        for (var i = 0; i < 12; i++) {
          await gesture.moveBy(const Offset(0, 4));
          await tester.pump();
          final rect = tester.getRect(railFor('Focus block'));
          final drift = (rect.bottom - startRect.bottom).abs();
          if (drift > maxBottomDrift) maxBottomDrift = drift;
        }

        expect(
          maxBottomDrift,
          lessThan(2.0),
          reason:
              'the end is anchored during a top-edge resize, so the '
              'bottom edge must stay put for the WHOLE drag — including '
              'after the pill hits its minimum renderable height',
        );

        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets(
    'the END time badge stays fixed through a top-edge drag while the '
    'START badge moves — "it should remain fixed"',
    (tester) async {
      final task = makeTask('Focus block', minutes: 30);
      await pumpTimeline(tester, task: task);

      await tester.longPress(find.text('Focus block'));
      await tester.pump();

      await tester.runAsync(() async {
        final originalEnd = task.scheduledAt!.add(
          Duration(minutes: task.durationMinutes!),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(topHandleFor('Focus block')),
        );
        await gesture.moveBy(const Offset(0, 4));
        await tester.pump();

        Rect endBadgeRect() {
          final labels = tester
              .widgetList<TaskEdgeTimeLabel>(find.byType(TaskEdgeTimeLabel))
              .toList();
          final endLabel = labels.firstWhere(
            (l) =>
                l.time.hour == originalEnd.hour &&
                l.time.minute == originalEnd.minute,
            orElse: () => throw StateError(
              'the END badge stopped showing the task\'s real end time — '
              'it is meant to be anchored, so its VALUE must not change '
              'either. Found: ${labels.map((l) => l.time).toList()}',
            ),
          );
          return tester.getRect(find.byWidget(endLabel));
        }

        final firstEndRect = endBadgeRect();
        var maxEndDrift = 0.0;
        for (var i = 0; i < 12; i++) {
          await gesture.moveBy(const Offset(0, 4));
          await tester.pump();
          final drift = (endBadgeRect().top - firstEndRect.top).abs();
          if (drift > maxEndDrift) maxEndDrift = drift;
        }

        expect(
          maxEndDrift,
          lessThan(2.0),
          reason:
              'reported directly: "the blue badge with time, end time is '
              'moving around while it should remain fixed"',
        );

        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets(
    'a BOTTOM drag smaller than one 5-minute snap step still moves the '
    'pill — live geometry is continuous, snapping happens on release',
    (tester) async {
      final task = makeTask('Focus block', minutes: 120);
      await pumpTimeline(tester, task: task);

      await tester.longPress(find.text('Focus block'));
      await tester.pump();

      await tester.runAsync(() async {
        final gesture = await tester.startGesture(
          tester.getCenter(bottomHandleFor('Focus block')),
        );

        // Cross kTouchSlop (18px) FIRST — below it the gesture arena has
        // not resolved the vertical-drag recognizer and onDragUpdate
        // never fires at all, so a 3px drag measures nothing whatever the
        // preview is driven by.
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();

        // NOW sample: baseline after slop, then a sub-snap nudge.
        final startRect = tester.getRect(railFor('Focus block'));
        // ~3px at the default 1.5px/min scale is 2 minutes — well under
        // the 5-minute snap step, so a snapped preview would not move the
        // pill at all here.
        await gesture.moveBy(const Offset(0, 3));
        await tester.pump();

        final grown =
            tester.getRect(railFor('Focus block')).height - startRect.height;
        expect(
          grown,
          greaterThan(0.5),
          reason:
              'the pill must respond to a sub-snap drag — driving it from '
              'the SNAPPED duration made it jump a whole step at a time, '
              'which read as the badge responding while the pill lagged',
        );

        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );
}
