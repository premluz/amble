import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/dev_config.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
import 'package:amble/features/timeline/edit_selection_provider.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
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
import '../../support/seeded_category_box.dart';

/// Covers Edit Mode's multi-task group MOVE — requested directly: "moving
/// one, they would move as a group." A drag on any SELECTED task's pill
/// applies the same time delta to every selected task in one write, with
/// no cascade-push against unselected tasks (confirmed via
/// AskUserQuestion) — see `group_reschedule_test.dart` for the pure
/// clamp-math coverage this file doesn't repeat, and
/// `edit_selection_provider.dart`'s own doc comments for why the drag
/// needs a broadcast provider at all.
///
/// Drags directly on `TaskCapsuleBlock`'s own rendered bounds: every task
/// block renders `splitLayout: true` (both Task and List view), which
/// collapses `TaskCapsuleBlock` to just its icon pill — the ONLY hit
/// target `onDragStart`/`onDragUpdate`/`onDragEnd` are wired to — so its
/// bounding box IS the drag surface, with no separate text row to avoid.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  late ProviderContainer? capturedContainer;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_multi_task_group_move');
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
    capturedContainer = null;
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await zoneBox.close();
    await trackedBehaviorBox.close();
    await preferencesBox.close();
  });

  Future<void> pumpTimeline(
    WidgetTester tester, {
    required List<Task> tasks,
  }) async {
    await tester.runAsync(() async {
      for (final task in tasks) {
        await taskBox.put(task.id, task);
      }
    });

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
          editModeEnabledProvider.overrideWith(
            () => _FixedEditModeEnabled(true),
          ),
          devMultiTaskEditModeProvider.overrideWith(
            () => _FixedDevMultiTaskEditMode(true),
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
              home: const Scaffold(body: TimelineScreen()),
            );
          },
        ),
      ),
    );
    // NOT pumpAndSettle — EditModeWiggle's perpetual animation never
    // settles. See multi_task_selection_test.dart's own pumpTimeline for
    // the full explanation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Task makeTask(String title, {int hour = 9, int minutes = 30}) {
    final now = DateTime.now();
    return Task.create(
      title: title,
      scheduledAt: DateTime(now.year, now.month, now.day, hour),
      durationMinutes: minutes,
      categoryId: BuiltInCategoryIds.work,
    );
  }

  /// Locates a task's own pill directly by which `TaskCapsuleBlock` it
  /// renders — split layout (used in both Task and List view) puts the
  /// pill and the title/time row as SIBLINGS inside one shared box, not
  /// ancestor/descendant, so walking up from the title text would never
  /// find it.
  Finder pillFor(String title) => find.byWidgetPredicate(
    (widget) => widget is TaskCapsuleBlock && widget.task.title == title,
  );

  testWidgets(
    'dragging one selected task moves every OTHER selected task by the '
    'same delta — an unselected task is left untouched',
    (tester) async {
      final a = makeTask('Focus block', hour: 9);
      final b = makeTask('Standup', hour: 13);
      final untouched = makeTask('Lunch', hour: 12);
      // Captured BEFORE the drag — `Hive`'s in-memory Box returns the
      // SAME Task object on every `get`, so `a`/`b`/`untouched` themselves
      // get mutated in place by the very write this test is checking;
      // comparing against them afterward would be comparing a value
      // against itself.
      final originalA = a.scheduledAt;
      final originalB = b.scheduledAt;
      final originalUntouched = untouched.scheduledAt;
      await pumpTimeline(tester, tasks: [a, b, untouched]);

      // Select both a and b (not `untouched`).
      await tester.tap(find.text('Focus block'));
      await tester.pump();
      await tester.tap(find.text('Standup'));
      await tester.pump();
      expect(capturedContainer!.read(editSelectionProvider), {a.id, b.id});

      // Drag `a`'s pill down by 60 minutes' worth of pixels (1.5px/min ->
      // 90px), then release — this MUST end well past the 5-minute snap
      // threshold so it doesn't read as "released near the start." The
      // drop's own commit is real Hive disk I/O across a BATCH of two
      // `saveTask` calls, each followed by a fire-and-forget (not
      // awaited) notification sync — a real, non-zero delay is needed to
      // drain every one of those dangling continuations before this
      // block (and the test) returns, or one can resolve later against
      // an already-disposed ProviderContainer. Same fix pattern as
      // exit_confirmation_test.dart's `_tapAndSettle`. See
      // docs/ERROR_LOG.md.
      await tester.runAsync(() async {
        await tester.drag(pillFor('Focus block'), const Offset(0, 90));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 400));

      final savedA = taskBox.get(a.id)!;
      final savedB = taskBox.get(b.id)!;
      final savedUntouched = taskBox.get(untouched.id)!;

      // Both moved, and the untouched task never did.
      expect(savedA.scheduledAt, isNot(originalA));
      expect(savedB.scheduledAt, isNot(originalB));
      expect(savedUntouched.scheduledAt, originalUntouched);

      // The whole point of a GROUP move: every selected member moves by
      // the exact SAME delta — not asserting the raw pixel-to-minute
      // conversion `tester.drag()` itself produces (a Flutter test-
      // harness implementation detail, not part of this feature's
      // contract), which is why this compares the two deltas against
      // each other rather than either against a hardcoded clock time.
      final deltaA = savedA.scheduledAt!.difference(originalA!);
      final deltaB = savedB.scheduledAt!.difference(originalB!);
      expect(deltaA, deltaB);
      // And it actually moved by something meaningful, not a no-op that
      // happened to leave both scheduledAt values technically unequal by
      // floating point noise (DateTime has none, but the intent here is
      // "moved by a real amount," so make that explicit).
      expect(deltaA.inMinutes.abs(), greaterThanOrEqualTo(5));
    },
  );

  testWidgets('dragging a task with nothing selected still moves just that one '
      'task (multi-task mode ON but no active selection)', (tester) async {
    final a = makeTask('Focus block', hour: 9);
    // Captured before the drag — see the group-move test's own comment on
    // why (Hive returns the same object, so `a` itself gets mutated).
    final originalA = a.scheduledAt;
    await pumpTimeline(tester, tasks: [a]);

    // No tap-to-select first — this exercises the plain single-task
    // move path even while multi-task mode is globally on.
    await tester.runAsync(() async {
      await tester.drag(pillFor('Focus block'), const Offset(0, 90));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 400));

    final saved = taskBox.get(a.id)!;
    expect(saved.scheduledAt, isNot(originalA));
    expect(
      saved.scheduledAt!.difference(originalA!).inMinutes,
      greaterThanOrEqualTo(5),
    );
  });
}

class _FixedEditModeEnabled extends EditModeEnabled {
  _FixedEditModeEnabled(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;
}

class _FixedDevMultiTaskEditMode extends DevMultiTaskEditMode {
  _FixedDevMultiTaskEditMode(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;
}
