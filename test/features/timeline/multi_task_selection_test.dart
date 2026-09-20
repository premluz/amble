import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/dev_config.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
import 'package:amble/features/timeline/edit_selection_provider.dart';
import 'package:amble/features/timeline/pending_task_draft_provider.dart';
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

/// Covers Edit Mode's multi-task route (`DevMultiTaskEditMode`) tap-to-
/// select behavior — requested directly: with it on, tapping a task
/// toggles selection (an accent ring on the pill's rail indicates it,
/// replacing the wiggle that used to) instead of
/// opening the detail sheet; with it off (the default), Edit Mode is
/// unaffected — see `edit_selection_provider.dart`'s own doc comments and
/// docs/CONSTITUTION.md's Edit Mode section.
///
/// Uses the same full-`TimelineScreen`-pump shape
/// `list_mode_clustering_test.dart` already established — that file is
/// separately known to hang on ITS OWN specific List-mode test (a
/// pre-existing, already-isolated issue unrelated to Edit Mode), so this
/// file stays in Task view mode throughout, never touching that path.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  // Only ever touched once a quick-create draft actually mounts
  // (`QuickCreateOverlay` -> `TemplateChipStrip` reads it) — added
  // alongside the "tapping empty space still starts a draft as normal"
  // sanity check below, the first test in this file to render that far.
  late Box<TaskTemplate> templateBox;
  late ProviderContainer? capturedContainer;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_multi_task_selection');
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

  Future<void> pumpTimeline(
    WidgetTester tester, {
    required List<Task> tasks,
    bool editModeEnabled = true,
    bool multiTaskEditMode = true,
  }) async {
    // Real Hive disk I/O — must run inside runAsync, not a bare await in
    // the synchronous test zone, or the write can hang the whole test.
    // See docs/ERROR_LOG.md's "flutter test hangs indefinitely on real
    // Hive disk I/O" entry.
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
          taskTemplateRepositoryProvider.overrideWithValue(
            HiveTaskTemplateRepository(templateBox),
          ),
          // Fixed initial values, not a post-frame toggle from inside the
          // widget tree — driving `.toggle()`/`.set()` from a Consumer's
          // own `builder` re-runs on every rebuild the toggle itself
          // causes, which never settles. These providers are otherwise
          // real (still toggleable via their own notifier mid-test, e.g.
          // the "exiting Edit Mode clears the selection" case below), just
          // seeded to a starting value the same way `_FixedShowHourLabels`
          // already does for `ShowHourLabelsSetting` elsewhere.
          editModeEnabledProvider.overrideWith(
            () => _FixedEditModeEnabled(editModeEnabled),
          ),
          devMultiTaskEditModeProvider.overrideWith(
            () => _FixedDevMultiTaskEditMode(multiTaskEditMode),
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
    // NOT pumpAndSettle: EditModeWiggle starts a perpetually-repeating
    // AnimationController the instant `editModeEnabled` is true (every
    // wiggling block, or — under multi-task mode — every SELECTED one),
    // and pumpAndSettle waits for animations to finish, which a
    // `repeat(reverse: true)` controller never does. Same fix pattern
    // `edit_mode_wiggle_test.dart` already uses for this exact widget: a
    // bounded pump instead. One frame is enough to mount everything;
    // nothing in this file's own assertions depends on entrance/settle
    // animations finishing.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  // **2026-09-12 — anchored off `now`, was a fixed clock hour.** The
  // Timeline scrolls to centre on `DateTime.now()`, so a fixture pinned to
  // a literal 9:00/12:00/13:00 only landed on screen when the suite
  // happened to run near those hours — off-screen at any other time, and
  // every tap/drag against it then missed. This is the same
  // time-of-day-dependent fixture bug already documented several times in
  // docs/ERROR_LOG.md; these four files were the last holdouts, and were
  // failing for exactly that reason.
  //
  // `hour` is kept as the parameter so call sites read unchanged, but it
  // now means "this many half-hours apart from the others" rather than a
  // wall-clock time — the tests only ever needed the fixtures to be
  // distinguishable and simultaneously visible, never a specific hour.
  // Clamped to stay inside `now`'s own calendar day, since the Timeline
  // always opens on today (see the same clamp in armed_edit_task_test).
  Task makeTask(String title, {int hour = 9, int minutes = 30}) {
    final now = DateTime.now();
    final base = (now.hour * 60 + now.minute).clamp(60, 24 * 60 - 120);
    final spread = (hour - 9) * 30;
    return Task.create(
      title: title,
      scheduledAt: DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(minutes: (base + spread).clamp(0, 24 * 60 - 1))),
      durationMinutes: minutes,
      categoryId: BuiltInCategoryIds.work,
    );
  }

  testWidgets('with multi-task mode ON, tapping a task selects it instead of '
      'opening the detail sheet', (tester) async {
    final task = makeTask('Focus block');
    await pumpTimeline(tester, tasks: [task]);

    await tester.tap(find.text('Focus block'));
    await tester.pump();

    expect(find.text('Edit task'), findsNothing);
    expect(capturedContainer!.read(editSelectionProvider), {task.id});
  });

  testWidgets('tapping a selected task again deselects it', (tester) async {
    final task = makeTask('Focus block');
    await pumpTimeline(tester, tasks: [task]);

    await tester.tap(find.text('Focus block'));
    await tester.pump();
    expect(capturedContainer!.read(editSelectionProvider), {task.id});

    await tester.tap(find.text('Focus block'));
    await tester.pump();
    expect(capturedContainer!.read(editSelectionProvider), isEmpty);
  });

  /// Locates a task's own PILL — the only thing carrying the move/sweep
  /// drag detector. Split layout puts the pill and the title/time row as
  /// SIBLINGS, so dragging from the title text hits no drag handler at
  /// all (confirmed the hard way: every sweep assertion read an empty
  /// selection until this finder replaced `find.text`). Same helper
  /// `multi_task_group_move_test.dart` already uses for its own drags.
  Finder pillFor(String title) => find.byWidgetPredicate(
    (widget) => widget is TaskCapsuleBlock && widget.task.title == title,
  );

  // Requested directly: "let's use multi select on tasks also... with
  // selector zone and sweeping tap and drag on task." A drag beginning on
  // an UNSELECTED task sweeps every task the finger crosses into the
  // selection; a drag beginning on an already-SELECTED one keeps its
  // existing group move-to-reschedule meaning (both confirmed via
  // AskUserQuestion).
  group('drag-to-multi-select sweep (2026-09-20)', () {
    testWidgets(
      'dragging from an UNSELECTED task across a neighbour selects BOTH, '
      'not just the one the drag started on',
      (tester) async {
        final a = makeTask('Focus block', hour: 9);
        final b = makeTask('Standup', hour: 10);
        await pumpTimeline(tester, tasks: [a, b]);
        expect(capturedContainer!.read(editSelectionProvider), isEmpty);

        final gesture = await tester.startGesture(
          tester.getCenter(pillFor('Focus block')),
        );
        await tester.pump();
        await gesture.moveTo(tester.getCenter(pillFor('Standup')));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(capturedContainer!.read(editSelectionProvider), {a.id, b.id});
      },
    );

    // **2026-09-20 — replaced a test that asserted the WRONG visual.**
    // An earlier pass read "not seeing blue on tasks" as a missing
    // per-task selection ring and asserted `SelectedPillBorder` on each
    // swept capsule — which passed, while the real app still looked
    // wrong. Corrected directly: "the swipe sweep selection has nothing
    // to do with a pale border... it's sweeping on top of everything, in
    // the same way as sweep tap and sweep all the empty timeline of a
    // zone... it always follows the finger as the finger moves."
    //
    // So the affordance under test is a MARQUEE that exists only WHILE
    // the finger is down — which is exactly what the old test could
    // never have caught, since it only ever looked after `gesture.up()`.
    testWidgets(
      'a live marquee is drawn WHILE sweeping, and disappears once the '
      'finger lifts — the selection it made stays',
      (tester) async {
        final a = makeTask('Focus block', hour: 9);
        final b = makeTask('Standup', hour: 10);
        await pumpTimeline(tester, tasks: [a, b]);

        final marquee = find.byKey(const ValueKey('task-sweep-selection'));
        expect(
          marquee,
          findsNothing,
          reason: 'no marquee before a sweep has started',
        );

        final from = tester.getCenter(pillFor('Focus block'));
        final to = tester.getCenter(pillFor('Standup'));
        final gesture = await tester.startGesture(from);
        await tester.pump();
        // Stepped, not a single `moveTo` — a one-shot jump produces a
        // drag START with no UPDATEs at all in this harness (verified
        // with a throwaway probe: zero `onDragUpdate` calls for ANY drag
        // driven that way, sweep or ordinary move). The marquee only
        // grows on updates, so the test has to move the way a finger
        // actually does or it measures nothing.
        const steps = 8;
        for (var i = 1; i <= steps; i++) {
          await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
          await tester.pump();
        }

        expect(
          marquee,
          findsOneWidget,
          reason:
              'the marquee must be visible mid-sweep — this is the whole '
              'affordance, and it only exists while the finger is down',
        );
        expect(
          tester.getRect(marquee).height,
          greaterThan(0),
          reason: 'a zero-height marquee would be invisible in practice',
        );

        await gesture.up();
        await tester.pump();

        expect(
          marquee,
          findsNothing,
          reason: 'the marquee is torn down on release',
        );
        expect(capturedContainer!.read(editSelectionProvider), {
          a.id,
          b.id,
        }, reason: 'the selection the sweep produced must survive it');
      },
    );

    testWidgets(
      'the sweep is ADDITIVE — crossing back over a task already swept '
      'leaves it selected rather than toggling it off',
      (tester) async {
        final a = makeTask('Focus block', hour: 9);
        final b = makeTask('Standup', hour: 10);
        await pumpTimeline(tester, tasks: [a, b]);

        final gesture = await tester.startGesture(
          tester.getCenter(pillFor('Focus block')),
        );
        await tester.pump();
        await gesture.moveTo(tester.getCenter(pillFor('Standup')));
        await tester.pump();
        // Back onto the first task, then forward again — a wobbly drag
        // must not undo its own work.
        await gesture.moveTo(tester.getCenter(pillFor('Focus block')));
        await tester.pump();
        await gesture.moveTo(tester.getCenter(pillFor('Standup')));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(capturedContainer!.read(editSelectionProvider), {a.id, b.id});
      },
    );

    testWidgets(
      'a drag starting on an ALREADY-SELECTED task does NOT sweep — it '
      'stays a move, leaving the selection exactly as it was',
      (tester) async {
        final a = makeTask('Focus block', hour: 9);
        final b = makeTask('Standup', hour: 10);
        await pumpTimeline(tester, tasks: [a, b]);

        await tester.tap(find.text('Focus block'));
        await tester.pump();
        expect(capturedContainer!.read(editSelectionProvider), {a.id});

        final gesture = await tester.startGesture(
          tester.getCenter(pillFor('Focus block')),
        );
        await tester.pump();
        await gesture.moveTo(tester.getCenter(pillFor('Standup')));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(
          capturedContainer!.read(editSelectionProvider),
          {a.id},
          reason:
              'moving a selected task must not sweep others into the '
              'selection on the way past',
        );
      },
    );

    testWidgets(
      'with multi-task mode OFF, a drag on a task still moves it rather '
      'than sweeping — the selection stays empty',
      (tester) async {
        final a = makeTask('Focus block', hour: 9);
        final b = makeTask('Standup', hour: 10);
        await pumpTimeline(tester, tasks: [a, b], multiTaskEditMode: false);

        final gesture = await tester.startGesture(
          tester.getCenter(pillFor('Focus block')),
        );
        await tester.pump();
        await gesture.moveTo(tester.getCenter(pillFor('Standup')));
        await tester.pump();
        await gesture.up();
        // A real move runs a settle animation whose timer outlives a
        // single `pump` — drained here so the test doesn't end with a
        // pending timer. (The sweep cases above need no such drain:
        // a sweep never lifts or settles anything.)
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(capturedContainer!.read(editSelectionProvider), isEmpty);
      },
    );
  });

  testWidgets('selecting one task does not select a second, unrelated task', (
    tester,
  ) async {
    final a = makeTask('Focus block', hour: 9);
    final b = makeTask('Standup', hour: 13);
    await pumpTimeline(tester, tasks: [a, b]);

    await tester.tap(find.text('Focus block'));
    await tester.pump();

    expect(capturedContainer!.read(editSelectionProvider), {a.id});
  });

  testWidgets(
    'with multi-task mode OFF, tapping a task opens the detail sheet — '
    'ordinary (single-task) Edit Mode is completely unaffected',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, tasks: [task], multiTaskEditMode: false);

      await tester.tap(find.text('Focus block'));
      await tester.pump();
      // The detail sheet's own slide-up route transition — a bounded
      // pump past its duration, not pumpAndSettle, for the same reason
      // pumpTimeline itself avoids it (Edit Mode's wiggle is still
      // running underneath).
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Edit task'), findsOneWidget);
      expect(capturedContainer!.read(editSelectionProvider), isEmpty);
    },
  );

  testWidgets('exiting Edit Mode clears the selection', (tester) async {
    final task = makeTask('Focus block');
    await pumpTimeline(tester, tasks: [task]);

    await tester.tap(find.text('Focus block'));
    await tester.pump();
    expect(capturedContainer!.read(editSelectionProvider), {task.id});

    capturedContainer!.read(editModeEnabledProvider.notifier).toggle();
    await tester.pump();

    expect(capturedContainer!.read(editSelectionProvider), isEmpty);
  });

  testWidgets(
    'turning multi-task mode off clears the selection even while Edit '
    'Mode stays on',
    (tester) async {
      final task = makeTask('Focus block');
      await pumpTimeline(tester, tasks: [task]);

      await tester.tap(find.text('Focus block'));
      await tester.pump();
      expect(capturedContainer!.read(editSelectionProvider), {task.id});

      capturedContainer!.read(devMultiTaskEditModeProvider.notifier).set(false);
      await tester.pump();

      expect(capturedContainer!.read(editSelectionProvider), isEmpty);
      expect(capturedContainer!.read(editModeEnabledProvider), isTrue);
    },
  );

  // Requested directly: "on timeline view selected item through long
  // press when tapped outside once it removes selection completely —
  // let's adopt this for our multiselected in edit modes." Mirrors
  // `armedEditTaskProvider`'s own established rule exactly (see
  // `onEmptyTap`'s own doc comment in timeline_screen.dart): a tap on
  // empty space while something is selected ONLY clears the selection —
  // it must never also start a quick-create draft on that same tap.
  group('tapping empty space clears the selection (2026-09-20)', () {
    testWidgets(
      'tapping empty Timeline space while tasks are multi-selected clears '
      'the selection and does NOT also start a quick-create draft',
      (tester) async {
        final a = makeTask('Focus block', hour: 9);
        final b = makeTask('Standup', hour: 10);
        await pumpTimeline(tester, tasks: [a, b]);

        await tester.tap(find.text('Focus block'));
        await tester.pump();
        await tester.tap(find.text('Standup'));
        await tester.pump();
        expect(capturedContainer!.read(editSelectionProvider), {a.id, b.id});

        // Empty background, well clear of either task's own pill — same
        // fixed offset `tap_empty_space_quick_create_test.dart` already
        // established for this exact 430x932 viewport.
        await tester.tapAt(const Offset(220, 700));
        await tester.pump();

        expect(
          capturedContainer!.read(editSelectionProvider),
          isEmpty,
          reason: 'the tap must clear the multi-task selection',
        );
        expect(
          capturedContainer!.read(pendingTaskDraftProvider),
          isNull,
          reason:
              'a tap that only dismissed a selection must never also '
              'start a quick-create draft on the same tap — the exact '
              'bug already fixed once for the single-task armed case',
        );
      },
    );

    testWidgets(
      'with nothing selected, tapping empty Timeline space still starts '
      'a quick-create draft as normal — the new clearing rule does not '
      'swallow the ordinary case',
      (tester) async {
        final task = makeTask('Focus block', hour: 9);
        await pumpTimeline(tester, tasks: [task]);

        expect(capturedContainer!.read(editSelectionProvider), isEmpty);

        await tester.tapAt(const Offset(220, 700));
        await tester.pump();

        expect(capturedContainer!.read(pendingTaskDraftProvider), isNotNull);
      },
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
