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

/// A move-drag or a resize now shows the task's own live edge time in an
/// accent badge pinned over the hour gutter, ALWAYS on the LEFT — first
/// reported directly for move only ("when dragging (moving) cant see
/// hour changeing. only when resizing can see"), then extended to resize
/// too, still left-pinned rather than following to the right edge: "the
/// time in accent color bg when moving or rezising, sohul always be on
/// left[;] also when resizing... we should show times not only when
/// wiggling." Task view only (`compactText` is List mode's own signal, so
/// no equivalent gutter exists there). A move-drag shows BOTH edges
/// (start AND end shift together, duration unchanged) — corrected from an
/// earlier start-only version, reported directly: "when moving also end
/// should be shown in blue atm only beginning start time." A resize shows
/// only the edge actually moving: top-resize the live START, bottom-resize
/// the live END.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  late Box<TaskTemplate> templateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_drag_move_time_label');
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

  // Same clamped-offset-from-now shape other Timeline test files use, for
  // the same reason: a fixed clock hour only stays on-screen by
  // coincidence of when the suite happens to run.
  Task makeTask(String title, {int minutes = 60}) {
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

  // Same handle-ordering convention as multi_task_group_resize_test.dart:
  // TaskCapsuleBlock renders the top-edge handle first in its Stack, the
  // bottom-edge handle second, so `.first`/`.last` pick them out reliably.
  Finder topHandleFor(String title) => find
      .descendant(of: pillFor(title), matching: find.byType(ResizeHandle))
      .first;
  Finder bottomHandleFor(String title) => find
      .descendant(of: pillFor(title), matching: find.byType(ResizeHandle))
      .last;

  testWidgets(
    'an ordinary (not being dragged) task shows no left-edge time label',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, task: task);

      expect(find.byType(TaskEdgeTimeLabel), findsNothing);
    },
  );

  testWidgets(
    'dragging a task (moving) shows BOTH its live start and end time, '
    'pinned to the left, over the hour gutter',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, task: task);

      await tester.runAsync(() async {
        final dragStart = tester.getCenter(pillFor('Focus block'));
        final gesture = await tester.startGesture(dragStart);
        // Several small moves rather than one big jump — see the resize
        // tests' own note: the gesture arena needs to actually resolve
        // the recognizer before `onDragUpdate`'s delta accumulates, and
        // this is what actually proves the labels track a CHANGED time
        // rather than just existing.
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(0, 5));
          await tester.pump();
        }

        // BOTH edges, not just the start — corrected directly: "when
        // moving also end should be shown... atm only beginning start
        // time."
        expect(find.byType(TaskEdgeTimeLabel), findsNWidgets(2));
        final labels = tester
            .widgetList<TaskEdgeTimeLabel>(find.byType(TaskEdgeTimeLabel))
            .toList();
        final originalStart = task.scheduledAt!;
        final originalEnd = originalStart.add(
          Duration(minutes: task.durationMinutes!),
        );
        for (final label in labels) {
          expect(
            label.time.hour * 60 + label.time.minute,
            isNot(originalStart.hour * 60 + originalStart.minute),
          );
        }
        // Both shift by the SAME amount (duration unchanged) — the two
        // labels' minute-of-day values differ by exactly the task's own
        // duration, same as at rest.
        final minutesOfDay =
            labels.map((l) => l.time.hour * 60 + l.time.minute).toList()
              ..sort();
        expect(
          minutesOfDay[1] - minutesOfDay[0],
          originalEnd.difference(originalStart).inMinutes,
        );

        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets('releasing the drag hides the left-edge time labels again', (
    tester,
  ) async {
    final task = makeTask('Focus block');
    await pumpTimeline(tester, task: task);

    await tester.runAsync(() async {
      final dragStart = tester.getCenter(pillFor('Focus block'));
      final gesture = await tester.startGesture(dragStart);
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(find.byType(TaskEdgeTimeLabel), findsNWidgets(2));

      await gesture.up();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TaskEdgeTimeLabel), findsNothing);
  });

  testWidgets(
    'the left-edge labels show no hairline — just the accent time badge',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, task: task);

      await tester.runAsync(() async {
        final dragStart = tester.getCenter(pillFor('Focus block'));
        final gesture = await tester.startGesture(dragStart);
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();

        final labels = tester.widgetList<TaskEdgeTimeLabel>(
          find.byType(TaskEdgeTimeLabel),
        );
        expect(labels, isNotEmpty);
        for (final label in labels) {
          expect(label.showLine, isFalse);
        }

        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets(
    'dragging the BOTTOM resize handle shows BOTH edge labels — the live '
    'END time (moving) AND the unchanged START (reported directly: both '
    'edges must stay visible during either resize, not just the moving '
    'one)',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, task: task);

      // Long-press arms the task, revealing its resize handles — same
      // precondition armed_edit_task_test.dart's own handle tests use.
      await tester.longPress(find.text('Focus block'));
      await tester.pump();

      await tester.runAsync(() async {
        final handleCenter = tester.getCenter(bottomHandleFor('Focus block'));
        final gesture = await tester.startGesture(handleCenter);
        // Several small moves rather than one big jump: a real drag
        // reports incremental per-frame deltas, and the gesture arena
        // needs to actually resolve the vertical-drag recognizer before
        // `onDragUpdate`'s delta accumulates — one large `moveBy` can
        // land entirely inside that unresolved window and never fire.
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(0, 5));
          await tester.pump();
        }

        expect(find.byType(TaskEdgeTimeLabel), findsNWidgets(2));
        final labels = tester
            .widgetList<TaskEdgeTimeLabel>(find.byType(TaskEdgeTimeLabel))
            .toList();
        final originalStart = task.scheduledAt!;
        final expectedEnd = originalStart.add(
          Duration(minutes: task.durationMinutes!),
        );

        final startLabel = labels.firstWhere(
          (l) =>
              l.time.hour * 60 + l.time.minute ==
              originalStart.hour * 60 + originalStart.minute,
        );
        expect(startLabel.time.hour, originalStart.hour);

        final endLabel = labels.firstWhere((l) => l != startLabel);
        // A generous window rather than an exact snapped-minute match:
        // this only needs to prove the label tracks the END (a later
        // time than the unchanged start), not the drag's exact snap
        // arithmetic (already covered by _previewDurationMinutes'
        // own unit coverage elsewhere).
        expect(
          endLabel.time.hour * 60 + endLabel.time.minute,
          greaterThan(expectedEnd.hour * 60 + expectedEnd.minute - 5),
        );

        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets(
    'dragging the TOP resize handle shows BOTH edge labels — the live '
    'START time (moving) AND the unchanged END',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, task: task);

      await tester.longPress(find.text('Focus block'));
      await tester.pump();

      await tester.runAsync(() async {
        final handleCenter = tester.getCenter(topHandleFor('Focus block'));
        final gesture = await tester.startGesture(handleCenter);
        // Several small moves rather than one big jump: a real drag
        // reports incremental per-frame deltas, and the gesture arena
        // needs to actually resolve the vertical-drag recognizer before
        // `onDragUpdate`'s delta accumulates — one large `moveBy` can
        // land entirely inside that unresolved window and never fire.
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(0, 5));
          await tester.pump();
        }

        expect(find.byType(TaskEdgeTimeLabel), findsNWidgets(2));
        final labels = tester
            .widgetList<TaskEdgeTimeLabel>(find.byType(TaskEdgeTimeLabel))
            .toList();
        final originalStart = task.scheduledAt!;
        final originalEnd = originalStart.add(
          Duration(minutes: task.durationMinutes!),
        );

        final endLabel = labels.firstWhere(
          (l) =>
              l.time.hour * 60 + l.time.minute ==
              originalEnd.hour * 60 + originalEnd.minute,
        );
        expect(endLabel.time.hour, originalEnd.hour);

        final startLabel = labels.firstWhere((l) => l != endLabel);
        expect(
          startLabel.time.hour * 60 + startLabel.time.minute,
          greaterThan(originalStart.hour * 60 + originalStart.minute),
        );

        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets(
    'resizing keeps both labels visible through release — the task stays '
    'armed afterward, so wiggle\'s own resting pair simply takes over '
    'with no gap where neither renders',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, task: task);

      await tester.longPress(find.text('Focus block'));
      await tester.pump();

      await tester.runAsync(() async {
        final handleCenter = tester.getCenter(bottomHandleFor('Focus block'));
        final gesture = await tester.startGesture(handleCenter);
        for (var i = 0; i < 8; i++) {
          await gesture.moveBy(const Offset(0, 5));
          await tester.pump();
        }
        // Both labels while the resize is live now (2026-09-12 — was
        // exactly one, the moving edge only; corrected directly).
        expect(find.byType(TaskEdgeTimeLabel), findsNWidgets(2));

        await gesture.up();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Still armed and wiggling after release (a resize's release does
      // NOT close the arm) — wiggle's own resting pair (`_edgeTimeLabels`)
      // has taken over from the live resize pair, so the count stays at
      // 2 rather than dropping to 0.
      expect(find.byType(TaskEdgeTimeLabel), findsNWidgets(2));
    },
  );
}
