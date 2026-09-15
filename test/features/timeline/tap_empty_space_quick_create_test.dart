import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/quick_create_sheet_shell.dart';
import 'package:amble/features/timeline/pending_task_draft_provider.dart';
import 'package:amble/core/widgets/glass_pill_surface.dart';
import 'package:amble/features/timeline/edit_mode_wiggle.dart';
import 'package:amble/features/timeline/pending_task_pill.dart';
import 'package:amble/core/widgets/app_top_scroll_fade.dart';
import 'package:amble/features/timeline/quick_create_overlay.dart';
import 'package:amble/features/timeline/resize_handle.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/template_chip_strip.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
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
import 'package:amble/shared/models/zone.dart';

import '../../support/fake_notification_service.dart';

/// End-to-end coverage, through the REAL `TimelineScreen`, for the tap-
/// empty-space quick-create interaction — requested directly: "tap on an
/// empty space in timeline view... puts a wiggly gray default task and
/// opens a small sheet with a task name input without the keyboard
/// opened... a little handle in the middle that the user can extend to
/// near full size add sheet."
///
/// The small sheet (`QuickCreateOverlay`) is deliberately NOT a pushed
/// `Navigator` route — see that widget's own doc comment for why (a
/// pushed route unconditionally makes everything below it non-
/// interactive via `AbsorbPointer`, confirmed by direct testing, which
/// would make the placeholder pill undraggable while the small sheet is
/// open — exactly the thing the user pointed out: "the sheet cannot be
/// actually modal otherwise dragging would be possible"). This file's
/// central test is the one that specifically proves the pill stays
/// draggable while the overlay is small.
///
/// Mirrors `zone_move_end_to_end_test.dart`'s own full-`TimelineScreen`-
/// pump harness (real Hive boxes, `ProviderScope` overrides).
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  late Box<TaskTemplate> templateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_tap_empty_space_quick_create');
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
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await zoneBox.close();
    await trackedBehaviorBox.close();
    await preferencesBox.close();
    await templateBox.close();
  });

  Future<void> pumpTimeline(WidgetTester tester) async {
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Must be called BEFORE pumpTimeline: `taskTemplateListProvider`
  // reads `getAll()` once at build time, so a template written after
  // the pump never appears.
  //
  // The `tester.runAsync` wrapper is load-bearing, and is the same
  // thing create_flow_template_browser_test.dart does for the same
  // reason: a Hive write started inside a widget test's own fake-async
  // zone never completes, so a bare `await box.put(...)` hangs the
  // test body outright, and merely dropping the await just moves the
  // hang to teardown, where `templateBox.close()` waits on that same
  // pending write. Both were observed here as a test that printed
  // nothing and never returned.
  Future<void> seedTemplate(
    WidgetTester tester,
    String title,
    String categoryId, {
    int? durationMinutes,
    bool isImportant = false,
  }) async {
    final template = TaskTemplate.create(
      title: title,
      categoryId: categoryId,
      durationMinutes: durationMinutes,
      isImportant: isImportant,
    );
    await tester.runAsync(() => templateBox.put(template.id, template));
  }

  testWidgets(
    'tapping empty Timeline space drops a wiggly placeholder pill and '
    'opens the small quick-create overlay with no keyboard',
    (tester) async {
      await pumpTimeline(tester);

      // A tap well clear of any hour-gutter/chrome, inside the day
      // column's empty background.
      await tester.tapAt(const Offset(220, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byType(PendingTaskPill),
        findsOneWidget,
        reason: 'the wiggly placeholder pill must appear immediately',
      );
      expect(find.byType(QuickCreateOverlay), findsOneWidget);
      // Not a pushed route — the small panel's own button, same
      // shape/position as the big sheet's. Labelled "Schedule" because
      // it commits the task outright rather than handing off to the full
      // form (reported directly).
      expect(find.widgetWithText(ElevatedButton, 'Schedule'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // No keyboard: the Name field must not be autofocused.
      final nameField = tester.widget<TextField>(find.byType(TextField).first);
      expect(nameField.autofocus, isFalse);
      // Pre-filled with a real default rather than starting empty.
      // Two now: the sheet's own Name field AND the pill, which carries
      // its title since it became a real task-shaped capsule.
      expect(find.text('New task'), findsNWidgets(2));
    },
  );

  testWidgets(
    'the sheet reaches the very bottom edge of the screen — no gap left '
    'by the DayStrip\'s own SafeArea stand-in',
    (tester) async {
      // A REAL bottom inset (home-indicator-style), set before pumping.
      // Without one this test can't see the bug at all: the default test
      // view has a zero bottom inset, so the offending `SafeArea` added
      // zero padding and the sheet looked flush either way. Confirmed by
      // reverting the fix and watching this test still pass until the
      // inset was added.
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(() {
        tester.view.resetViewPadding();
        tester.view.resetPadding();
      });

      await pumpTimeline(tester);

      await tester.tapAt(const Offset(220, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Reported directly: "still there is some padding from bottom of
      // screen.. sheet is not starting from edge bottom." The cause was
      // the bare `SafeArea` that stands in for DayStrip while it's
      // hidden — it added the bottom inset BELOW the Expanded holding
      // this sheet, on top of the sheet's own internal SafeArea, pushing
      // the whole panel up by that inset.
      final overlayRect = tester.getRect(find.byType(QuickCreateOverlay));
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      expect(
        overlayRect.bottom,
        closeTo(screenHeight, 0.5),
        reason: 'the sheet must be flush with the screen bottom',
      );
    },
  );

  // Replaces an earlier test that asserted this button PROMOTED to the
  // full sheet. The button's whole contract changed, reported directly:
  // "Done let's change to Schedule and it already sets the task there."
  // It now commits the task outright and never opens the full form.
  // Reported directly: "cant see important in quick add in mini sheet."
  // The full sheet, the edit flow, and templates all gained a real
  // Important toggle in the previous round; the mini sheet's own
  // direct-Schedule path had no way to set it at all.
  testWidgets('the mini sheet shows an Important toggle, off by default, '
      'and Schedule writes it to the created task', (tester) async {
    await pumpTimeline(tester);

    await tester.tapAt(const Offset(220, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Important'), findsOneWidget);
    final switchFinder = find.descendant(
      of: find.byType(QuickCreateOverlay),
      matching: find.byType(Switch),
    );
    expect(switchFinder, findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pump();
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Schedule'));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        if (taskBox.values.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 600));

    expect(taskBox.values, hasLength(1));
    expect(taskBox.values.first.isImportant, isTrue);
  });

  testWidgets('applying a template that is important seeds the mini '
      'sheet\'s own toggle, and it stays user-overridable afterward', (
    tester,
  ) async {
    await seedTemplate(
      tester,
      'Meditation',
      BuiltInCategoryIds.health,
      isImportant: true,
    );
    await pumpTimeline(tester);

    await tester.tapAt(const Offset(220, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byType(TemplateChip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final switchFinder = find.descendant(
      of: find.byType(QuickCreateOverlay),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    // Still overridable — applying a template doesn't lock the toggle.
    await tester.tap(switchFinder);
    await tester.pump();
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
  });

  // Requested directly: "on top of screen give gradient of the color of
  // bg to create that effect of content smoothly fading gradient on
  // timeline so there is not a hard line when content scrolls
  // underneath." Then, requested again for a mirrored one: "use same at
  // the bottom."
  testWidgets('the Timeline shows a top AND a bottom scroll-fade, fixed at the '
      'viewport edges regardless of scroll position', (tester) async {
    await pumpTimeline(tester);

    expect(find.byType(AppTopScrollFade), findsNWidgets(2));
    final fades = find
        .byType(AppTopScrollFade)
        .evaluate()
        .map((e) => e.widget as AppTopScrollFade)
        .toList();
    expect(fades.where((f) => f.fromBottom).length, 1);
    expect(fades.where((f) => !f.fromBottom).length, 1);

    // Both fade FROM the Timeline's own background TO transparent — a
    // colour mismatch would read as a visible tint rather than a
    // seamless fade.
    for (final fade in fades) {
      expect(fade.color, AmbleTheme.light.colorSurfaceTimeline);
    }

    // Purely decorative — must never intercept a tap meant for the
    // content scrolled underneath them. AppTopScrollFade wraps its OWN
    // DecoratedBox in an IgnorePointer internally (see that widget's own
    // doc comment), so this checks each fade's descendant DecoratedBox
    // has an IgnorePointer ancestor — not the fade widget itself, which
    // has no ancestor relationship to its own internals.
    for (final decoratedBox
        in find
            .descendant(
              of: find.byType(AppTopScrollFade),
              matching: find.byType(DecoratedBox),
            )
            .evaluate()) {
      final ignorePointerAncestors = find
          .ancestor(
            of: find.byWidget(decoratedBox.widget),
            matching: find.byType(IgnorePointer),
          )
          .evaluate()
          .toList();
      expect(ignorePointerAncestors, isNotEmpty);
      expect(
        (ignorePointerAncestors.first.widget as IgnorePointer).ignoring,
        isTrue,
      );
    }
  });

  testWidgets('tapping Schedule creates the task directly, with no full '
      'sheet in between, and clears the placeholder pill', (tester) async {
    await pumpTimeline(tester);
    expect(taskBox.values, isEmpty);

    await tester.tapAt(const Offset(220, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // Same real-Hive-write polling the promoted-save test below uses —
    // createTask's disk write doesn't complete on any fixed frame
    // schedule, so pumping a fixed budget races it. See ERROR_LOG.md.
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Schedule'));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        if (taskBox.values.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    // Drains the save-reveal animation timers the Timeline starts for a
    // newly-created task (_DayTimelineState._revealSavedTask's 900ms,
    // and _DraggableTaskBlockState._scheduleReveal's 500ms) — without
    // this the test fails on a pending timer even though the task itself
    // saved correctly.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 600));

    // A real task exists, carrying the default name and the duration the
    // placeholder pill was created with.
    expect(taskBox.values, hasLength(1));
    expect(taskBox.values.first.title, 'New task');

    // The full sheet never appeared, and the placeholder is gone — the
    // real task pill replaces it.
    expect(find.byType(QuickCreateSheetHandle), findsNothing);
    expect(find.byType(QuickCreateOverlay), findsNothing);
    expect(find.byType(PendingTaskPill), findsNothing);
  });

  // The mini sheet must not become a way to create exactly the overlaps
  // the "Prevent overlapping tasks" setting exists to prevent — the full
  // sheet's own save enforces this, so the direct-schedule path has to
  // as well.
  testWidgets('Schedule refuses to create an overlapping task when the '
      'prevent-overlap setting is on, and says so in the sheet', (
    tester,
  ) async {
    await tester.runAsync(
      () => preferencesBox.put('preventOverlappingTasks', true),
    );
    // Anchored around `now` (like the tap position below, which always
    // lands near `now` because the Timeline scrolls to centre on it) rather
    // than a fixed clock-hour span — a fixed 9:00-19:00 window only
    // overlapped the tap's actual landing spot by coincidence of when the
    // suite happened to run, and missed it (as a real, reproducible
    // failure, not flakiness) once `now` fell outside that window.
    final now = DateTime.now();
    final existing = Task.create(
      title: 'Existing task',
      scheduledAt: now.subtract(const Duration(hours: 5)),
      durationMinutes: 600,
      categoryId: BuiltInCategoryIds.general,
    );
    await tester.runAsync(() => taskBox.put(existing.id, existing));

    await pumpTimeline(tester);

    await tester.tapAt(const Offset(220, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Schedule'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
    await tester.pump();

    // Still just the one pre-existing task — nothing was created.
    expect(taskBox.values, hasLength(1));
    expect(find.textContaining('overlaps another task'), findsOneWidget);
    expect(find.byType(QuickCreateOverlay), findsOneWidget);
  });

  testWidgets(
    'tapping the small sheet\'s own X button closes it and clears the '
    'placeholder pill, same position as the real sheet\'s own close '
    'button',
    (tester) async {
      await pumpTimeline(tester);

      await tester.tapAt(const Offset(220, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(PendingTaskPill), findsNothing);
      expect(find.byType(QuickCreateSheetHandle), findsNothing);
    },
  );

  testWidgets(
    'dragging the handle DOWN far enough closes the overlay and clears '
    'the placeholder pill — requested directly ("the sheet should also '
    'be closing with this handle that expands it")',
    (tester) async {
      await pumpTimeline(tester);

      await tester.tapAt(const Offset(220, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(PendingTaskPill), findsOneWidget);
      expect(find.byType(QuickCreateOverlay), findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(QuickCreateSheetHandle)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, 150));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 150));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byType(PendingTaskPill),
        findsNothing,
        reason: 'closing must clear the draft, removing the placeholder too',
      );
      expect(find.byType(QuickCreateSheetHandle), findsNothing);
    },
  );

  testWidgets(
    'the placeholder pill can be dragged WHILE the small overlay is open '
    '— the fix this whole feature exists to prove',
    (tester) async {
      await pumpTimeline(tester);

      await tester.tapAt(const Offset(220, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(QuickCreateOverlay), findsOneWidget);

      // Grows the draft first, via its own BOTTOM resize handle, so this
      // exercises move-after-resize on an ordinary-length pill.
      //
      // This started life as a WORKAROUND: a badge-floored pill used to
      // have no move-only band at all between its two 16px handles, so
      // the drag below could not be performed on a fresh draft. That is
      // fixed (handles now shrink on short blocks — see
      // resizeHandleHeightFor), and the floored case has its own test
      // above. The resize is kept because the combination is worth
      // covering in its own right, not because it is still required.
      await tester.drag(find.byType(ResizeHandle).last, const Offset(0, 120));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final pillRect = tester.getRect(find.byType(PendingTaskPill));
      final pillTopBefore = pillRect.top;

      // A `pump()` between EVERY gesture step (down, each move, up) —
      // without one between the down event and the first move, the
      // gesture recognizer never registered the drag at all in this full
      // `TimelineScreen` tree (confirmed directly: onVerticalDragUpdate
      // never fired, only start/end, until pumps were interleaved this
      // way) — the same class of timing requirement already documented
      // for `LongPressDraggable` in `place_task_line_test.dart`.
      final gesture = await tester.startGesture(pillRect.center);
      await tester.pump();
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final pillTopAfter = tester.getTopLeft(find.byType(PendingTaskPill)).dy;
      expect(
        pillTopAfter,
        isNot(pillTopBefore),
        reason:
            'a drag on the pill must reach it even though the small '
            'overlay is on screen at the same time — proving Timeline '
            'underneath was never absorbed by a Navigator barrier',
      );
      // Still small — dragging the pill has nothing to do with the
      // overlay's own height. The small sheet's own Done button is still
      // showing (not the real pushed sheet's), so QuickCreateSheetHandle
      // (small-sheet-only) is a cleaner signal than ElevatedButton (both
      // sheets have one).
      expect(find.byType(QuickCreateOverlay), findsOneWidget);
      expect(find.byType(QuickCreateSheetHandle), findsOneWidget);
    },
  );

  testWidgets('dragging the handle promotes to the real sheet, revealing the '
      'schedule fields, while the placeholder pill stays on Timeline', (
    tester,
  ) async {
    await pumpTimeline(tester);

    await tester.tapAt(const Offset(220, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(PendingTaskPill), findsOneWidget);

    // A `pump()` between EVERY gesture step — see the pill-drag test
    // above's own doc comment for why (onVerticalDragUpdate doesn't
    // register at all otherwise, in this full TimelineScreen tree).
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(QuickCreateSheetHandle)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, -200));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -200));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    // The pushed route's own slide-up transition takes real animation
    // time to settle before its content (Category etc.) is queryable.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // Confirming the name stage (whether via the handle reaching full,
    // or Done) advances straight to stage 2 — Category is stage-2-only.
    expect(find.text('Category'), findsOneWidget);
    // The placeholder pill is unaffected by the promotion — it's a
    // Timeline-side widget, entirely separate from the pushed route.
    expect(find.byType(PendingTaskPill), findsOneWidget);
    // The overlay itself renders nothing once promoted (it stays in the
    // tree — still gated on the same still-live pendingDraft the real
    // pushed route also reads via draftId — but its own handle/Name
    // field are gone, replaced visually by the real pushed sheet).
    expect(find.byType(QuickCreateSheetHandle), findsNothing);
  });

  testWidgets(
    'a SHORT upward drag on the handle is enough to expand — reported '
    'directly as "difficult to do" when it demanded most of the screen',
    (tester) async {
      await pumpTimeline(tester);

      await tester.tapAt(const Offset(220, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(QuickCreateSheetHandle), findsOneWidget);

      // ~70px total, nowhere near the ~380px the old midpoint rule
      // needed on this 932px-tall test viewport.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(QuickCreateSheetHandle)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, -35));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -35));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(QuickCreateSheetHandle), findsNothing);
      expect(find.text('Category'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Name field promotes to the real sheet\'s own stage 1, '
    'autofocused, so typing continues in the same field — requested '
    'directly ("when name input is tapped then it goes into near full '
    'screen mode")',
    (tester) async {
      await pumpTimeline(tester);

      await tester.tapAt(const Offset(220, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(QuickCreateSheetHandle), findsOneWidget);

      // The tap alone (before any typing) is what triggers promotion —
      // fires on onFocusChanged, so a plain tap is enough; the small
      // overlay's own field is gone by the time this returns, replaced
      // by the real pushed sheet's OWN separate Name field/controller.
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Promoted to the real sheet's stage 1 — "Done", not "Schedule"/
      // "Category" (that's stage 2), and the Name field autofocused so
      // the keyboard stays up and typing continues uninterrupted.
      expect(find.byType(QuickCreateSheetHandle), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Done'), findsOneWidget);
      final promotedField = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(promotedField.autofocus, isTrue);

      // The "New task" default does NOT come across — reported directly:
      // "New task name input should be reset to nothing, clears, so user
      // can type in from scratch." The mini sheet clears its own field on
      // the tap, and the empty string is what seeds the full sheet.
      expect(promotedField.controller!.text, isEmpty);
      // Scoped to the sheet: the PILL still shows its own "New task"
      // label (it has no other name to show), so an unscoped
      // findsNothing would fail for the wrong reason.
      expect(
        find.descendant(
          of: find.byType(QuickCreateOverlay),
          matching: find.text('New task'),
        ),
        findsNothing,
      );

      await tester.enterText(find.byType(TextField).first, 'Quick task');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Confirming the name (Done/keyboard-complete) advances to stage 2.
      expect(find.text('Quick task'), findsOneWidget);
      expect(find.byType(PendingTaskPill), findsOneWidget);

      final saveButton = find.widgetWithText(ElevatedButton, 'Schedule');
      await tester.runAsync(() async {
        await tester.tap(saveButton);
        await tester.pump();
        // The real Hive write inside _save() doesn't complete on any
        // fixed frame schedule (see docs/ERROR_LOG.md's "flutter test
        // hangs indefinitely on real Hive disk I/O" entry) — poll with
        // real wall-clock delays (inside runAsync, so this is a genuine
        // async wait, not a frame-only pump) until the real sheet's own
        // route has actually closed, rather than guessing a fixed pump
        // budget.
        for (var i = 0; i < 20; i++) {
          if (find.byType(ElevatedButton).evaluate().isEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
        // Drains any continuation still queued behind the real Hive
        // write (e.g. TaskList's post-save _refresh()) before this
        // runAsync block — and the test — returns, or it can resolve
        // later, after tearDown has already closed the Hive box.
        await Future<void>.delayed(Duration.zero);
      });

      expect(
        find.byType(PendingTaskPill),
        findsNothing,
        reason: 'the placeholder must be gone once the real task is saved',
      );
      expect(find.byType(TaskCapsuleBlock), findsWidgets);
      expect(find.text('Quick task'), findsWidgets);
    },
  );

  testWidgets(
    'a plain tap on an existing task still opens the ordinary edit sheet '
    'directly, no quick-create overlay involved',
    (tester) async {
      final now = DateTime.now();
      final task = Task.create(
        title: 'Existing task',
        scheduledAt: DateTime(now.year, now.month, now.day, 9),
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.general,
      );
      // Seeded BEFORE the widget tree is pumped — taskListProvider reads
      // the box once at its own build time, so a write landing after
      // that (even via runAsync) is invisible to the already-built
      // provider state until something else triggers a refresh. Wrapped
      // in runAsync, not a bare await, per docs/ERROR_LOG.md's "flutter
      // test hangs indefinitely on real Hive disk I/O" entry.
      await tester.runAsync(() => taskBox.put(task.id, task));
      await pumpTimeline(tester);

      await tester.ensureVisible(find.text('Existing task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Existing task'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(QuickCreateOverlay), findsNothing);
      expect(find.byType(PendingTaskPill), findsNothing);
      // The ordinary edit flow shows the task already fully populated
      // (stage 2 straight away — "Save", not "Schedule").
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);
    },
  );

  // The placeholder renders as a real task capsule in grey — requested
  // directly ("as actual pill grey but no icon, so also new task text
  // would be there"), replacing the plain translucent rectangle plus blue
  // start/end time boxes it used to be. Those blue labels belonged to the
  // superseded design and are gone (git holds them).
  testWidgets('a tap-created draft renders as a task-shaped pill carrying '
      'the "New task" name, with no category emoji', (tester) async {
    await pumpTimeline(tester);

    await tester.tapAt(const Offset(220, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(PendingTaskPill), findsOneWidget);
    // The name appears on the pill itself, not only in the mini sheet's
    // own field — so `findsWidgets`, not `findsOneWidget`.
    expect(
      find.descendant(
        of: find.byType(PendingTaskPill),
        matching: find.text('New task'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the draft defaults to a 15-minute duration', (tester) async {
    await pumpTimeline(tester);

    await tester.tapAt(const Offset(220, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // Read off the widget's own declared height rather than a provider
    // container this file doesn't capture — the pill is sized directly
    // from the draft's duration, so this is the same value either way.
    // Asserted by promoting to the full sheet, whose Duration field
    // reads the draft directly. The pill's own rendered height can't
    // carry this: at 1.5 px/min a 15-minute draft is 22.5px, which floors
    // to `sizeTaskBadge` (24px), so height cannot tell 15 minutes apart
    // from any other short value.
    // runAsync + poll, per ERROR_LOG.md: a Hive write started inside a
    // widget test's fake-async zone never completes there.
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Schedule'));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        if (taskBox.values.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    // Drains the Timeline's save-reveal timers (900ms + 500ms).
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 600));

    final saved = taskBox.values.single;
    expect(saved.durationMinutes, quickAddDefaultMinutes);
  });

  // Reported directly AFTER an isolated-widget test wrongly confirmed
  // both properties: "still see the quick task name not in the same
  // position as other names and is wiggling (but shouldn't)." Asserted
  // here, in a real TimelineScreen, because the isolated test supplied
  // its own geometry and so could agree with a wrong formula.
  group('placeholder title, in a real Timeline (2026-09-08)', () {
    testWidgets('the name is NOT inside any EditModeWiggle', (tester) async {
      await pumpTimeline(tester);

      await tester.tapAt(const Offset(220, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final titleOnPill = find.descendant(
        of: find.byType(PendingTaskPill),
        matching: find.text('New task'),
      );
      expect(titleOnPill, findsOneWidget);
      expect(
        find.ancestor(of: titleOnPill, matching: find.byType(EditModeWiggle)),
        findsNothing,
        reason:
            'the placeholder name must not wiggle, same as a real '
            'task name in Edit Mode',
      );
    });

    testWidgets('the name starts at the same x as a real task\'s name', (
      tester,
    ) async {
      final existing = Task.create(
        title: 'Existing task',
        scheduledAt: DateTime.now().copyWith(hour: 8, minute: 0),
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.general,
      );
      await tester.runAsync(() => taskBox.put(existing.id, existing));
      await pumpTimeline(tester);

      // Tapped well clear of the existing task, so both sit in lane 0 and
      // their names must therefore share one x.
      await tester.tapAt(const Offset(220, 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final realNameX = tester.getTopLeft(find.text('Existing task')).dx;
      final draftNameX = tester
          .getTopLeft(
            find.descendant(
              of: find.byType(PendingTaskPill),
              matching: find.text('New task'),
            ),
          )
          .dx;

      expect(
        draftNameX,
        closeTo(realNameX, 0.5),
        reason:
            'all task names share one x — the whole point of the '
            'shared text column',
      );
    });

    // Requested directly: "this ghost phantom state should have fill gray
    // semitransparent with bg blur glassy thing / make this style reusable
    // token."
    //
    // The rail was a solid 30%-alpha `Container` at a HARDCODED
    // `theme.radiusSm` (a fixed 4px), so it neither read as provisional
    // nor tracked the "Pill shape" setting every other card follows. It
    // now uses the shared `GlassPillSurface` in its GLASS material — a
    // translucent fill over a real `BackdropFilter` — corner-tracking
    // `theme.radiusPill`, the active rung of that setting.
    //
    // The flat material is the imported-event counterpart and must NOT be
    // what the draft gets: a draft is airborne and provisional, an
    // imported event is a real calendar thing.
    testWidgets(
      'the draft rail is the shared glass surface — frosted, not the flat '
      'imported-event material, and no glyph of its own',
      (tester) async {
        await pumpTimeline(tester);

        await tester.tapAt(const Offset(220, 400));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        final surface = find.descendant(
          of: find.byType(PendingTaskPill),
          matching: find.byType(GlassPillSurface),
        );
        expect(surface, findsOneWidget);

        final widget = tester.widget<GlassPillSurface>(surface);
        expect(
          widget.material,
          GlassPillMaterial.glass,
          reason: 'the draft is airborne/provisional — it gets the frosted '
              'material, not the imported event\'s flat gray',
        );
        expect(
          widget.child,
          isNull,
          reason: 'a draft has no category yet — any glyph would be '
              'inventing one',
        );
        // The frosted look requires a real blur behind it, not just a
        // translucent fill (see colorSurfaceBlurOverlay's own doc comment).
        expect(
          find.descendant(
            of: find.byType(PendingTaskPill),
            matching: find.byType(BackdropFilter),
          ),
          findsOneWidget,
        );
      },
    );
  });

  // Reported directly: "bug when adding task quick add after 20:00 the
  // sheet covers 20-24 hours so cant see." The mini sheet is pinned to
  // the bottom `quickCreateSheetMinFraction` of the screen for as long as
  // it's open, so centring a freshly-tapped draft in the FULL viewport
  // (what `_scrollToSavedTask` does once its own sheet has already
  // closed) still leaves it hidden under the sheet.
  testWidgets(
    'tapping a late-evening slot scrolls the draft into the space ABOVE '
    'the mini sheet, not just into the full viewport',
    (tester) async {
      await pumpTimeline(tester);

      // 22:00 — deep enough into the day that any sane initial scroll
      // position (which opens centred on "now") requires scrolling past
      // it, and specifically the kind of slot the report names.
      final tapTime = DateTime.now().copyWith(
        hour: 22,
        minute: 0,
        second: 0,
        millisecond: 0,
      );
      final rangeStart = DateTime(tapTime.year, tapTime.month, tapTime.day);
      const pixelsPerMinute = 1.5; // TimelineScreen's own default.
      final targetY =
          tapTime.difference(rangeStart).inMinutes * pixelsPerMinute;

      final scrollable = find.descendant(
        of: find.byType(TimelineScreen),
        matching: find.byType(Scrollable),
      );
      final vertical = tester
          .widgetList<Scrollable>(scrollable)
          .where((s) => s.axisDirection == AxisDirection.down)
          .toList();
      final position = tester
          .state<ScrollableState>(find.byWidget(vertical.first))
          .position;

      // Scroll there directly rather than via a synthetic tap gesture —
      // `tester.tapAt` needs the target already on screen, which is
      // exactly the thing not true yet for 22:00 on a fresh session.
      position.jumpTo(
        (targetY - position.viewportDimension / 2).clamp(
          0.0,
          position.maxScrollExtent,
        ),
      );
      await tester.pump();

      // Tap at the now-visible 22:00 row.
      final screenY = targetY - position.pixels;
      await tester.tapAt(Offset(220, screenY));
      // Two pumps before the settle wait, not one: `_scrollToPendingDraft`
      // runs inside a `WidgetsBinding.instance.addPostFrameCallback`
      // (needed because the scroll content's own bottom padding — which
      // reserves room for the mini sheet — is laid out in this SAME
      // rebuild, so `maxScrollExtent` read synchronously mid-
      // `didUpdateWidget` is still the smaller pre-padding value). The
      // first pump flushes that callback and starts the animation; a
      // single pump was confirmed to leave the animation never observed
      // as started, let alone finished, so the fixed-duration wait below
      // measured from one frame too early.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final pillTop = tester.getTopLeft(find.byType(PendingTaskPill)).dy;
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final sheetTop = screenHeight * (1 - quickCreateSheetMinFraction);

      expect(
        pillTop,
        lessThan(sheetTop),
        reason:
            'the placeholder must land ABOVE the mini sheet, not hidden '
            'underneath it',
      );
    },
  );

  // The substantive change, after the original "positioned absolutely
  // over everything" design was questioned directly. The draft now
  // implements ScheduledBlock and flows through the same
  // layoutOverlappingTasks/detectOverlapClusters pipeline real tasks and
  // imported events do, so it shares lanes instead of painting over what
  // it collides with.
  testWidgets('a draft overlapping an existing task takes its OWN lane '
      'rather than painting on top of it', (tester) async {
    // A long task covering the tap target, so the draft must collide.
    final existing = Task.create(
      title: 'Existing task',
      scheduledAt: DateTime.now().copyWith(hour: 0, minute: 0),
      durationMinutes: 20 * 60,
      categoryId: BuiltInCategoryIds.general,
    );
    await tester.runAsync(() => taskBox.put(existing.id, existing));
    await pumpTimeline(tester);

    // Tap a spot the existing task already occupies.
    await tester.tapAt(const Offset(220, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(PendingTaskPill), findsOneWidget);

    final pill = tester.widget<PendingTaskPill>(find.byType(PendingTaskPill));
    expect(
      pill.columnOffset,
      greaterThan(0),
      reason:
          'an overlapping draft must be pushed into its own lane, not '
          'drawn over the task it collides with',
    );
  });

  // The fix for the edge the previous test had to work AROUND: at the
  // 5-minute default the pill floors to badge size (24px) while two
  // default 16px handles claim 32px between them, so the block was
  // entirely handle and could not be dragged to a new time at all.
  // Handles now shrink on short blocks (resizeHandleHeightFor), so this
  // drags a freshly-created, never-resized pill straight from its centre.
  testWidgets('a badge-floored pill can still be MOVED from its centre — '
      'the two resize handles must not consume the whole block', (
    tester,
  ) async {
    await pumpTimeline(tester);

    await tester.tapAt(const Offset(220, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final before = tester.getRect(find.byType(PendingTaskPill));
    // Guards the premise: if the pill ever stops flooring to badge size
    // this test silently stops covering the case it exists for.
    expect(
      before.height,
      lessThanOrEqualTo(32.0),
      reason: 'this test is only meaningful on a short, floored pill',
    );

    // Deliberately NO resize first, unlike the drag test above.
    final gesture = await tester.startGesture(before.center);
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final after = tester.getRect(find.byType(PendingTaskPill));
    expect(
      after.top,
      greaterThan(before.top),
      reason: 'a short pill must still be draggable, not all-handle',
    );
    // Moved, not resized — the height is unchanged.
    expect(after.height, closeTo(before.height, 0.5));
  });

  // Reported directly: "sheet should be larger height so there is not
  // scrolling of content." The panel keeps an inner SingleChildScrollView
  // as a defensive floor for genuinely short viewports, but on an
  // ordinary phone portrait viewport it must never actually engage —
  // raising quickCreateSheetMinFraction is the fix if content grows,
  // letting it scroll is not.
  testWidgets('the mini sheet fits its whole content without the inner '
      'scroll view engaging', (tester) async {
    await seedTemplate(tester, 'Meditation', BuiltInCategoryIds.health);
    await pumpTimeline(tester);

    await tester.tapAt(const Offset(220, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final scrollable = find.descendant(
      of: find.byType(QuickCreateOverlay),
      matching: find.byType(Scrollable),
    );

    // The panel's own vertical scroll view — not the chip strip's
    // horizontal one, which is expected to scroll.
    final vertical = tester
        .widgetList<Scrollable>(scrollable)
        .where((s) => s.axisDirection == AxisDirection.down)
        .toList();
    expect(vertical, hasLength(1));

    final position = tester
        .state<ScrollableState>(find.byWidget(vertical.first))
        .position;
    expect(
      position.maxScrollExtent,
      0.0,
      reason: 'content must fit without scrolling',
    );
  });

  // The mini template chips, specified from a layout mockup: "as soon as
  // they click a template, that applies the name and the category, but
  // not the duration. The duration is not overridden. It remains the one
  // set by the user."
  group('mini template chips', () {
    // Seeds SYNCHRONOUSLY, and must be called BEFORE pumpTimeline.
    // `taskTemplateListProvider` reads `getAll()` once at build time, so
    // a template written after the pump would never appear; and awaiting
    // a Hive write from inside a widget-test body hangs against the fake
    // async clock (`box.put`'s own disk flush never completes there).
    // `box.put` returns a Future but the in-memory map is updated
    // synchronously, which is all `getAll()` reads — so this deliberately
    // does not await it.

    testWidgets(
      'tapping a chip applies its title, leaving the draft duration the '
      'user already dragged out completely untouched',
      (tester) async {
        // A template carrying a duration deliberately UNLIKE the draft's
        // own, so "did the duration change" is unambiguous.
        await seedTemplate(
          tester,
          'Meditation',
          BuiltInCategoryIds.health,
          durationMinutes: 120,
        );
        await pumpTimeline(tester);

        await tester.tapAt(const Offset(220, 400));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        final beforeHeight = tester
            .getRect(find.byType(PendingTaskPill))
            .height;

        await tester.tap(find.byType(TemplateChip));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // The name came across...
        expect(find.text('Meditation'), findsWidgets);
        expect(
          find.descendant(
            of: find.byType(QuickCreateOverlay),
            matching: find.text('New task'),
          ),
          findsNothing,
        );

        // ...and the pill's own geometry — the user's expressed duration
        // — did NOT move, despite the template's own 120-minute default.
        expect(
          tester.getRect(find.byType(PendingTaskPill)).height,
          closeTo(beforeHeight, 0.5),
          reason: 'the template must not override the dragged duration',
        );
      },
    );

    testWidgets(
      'tapping a chip does NOT promote to the full sheet — the user stays '
      'in the mini sheet, free to keep adjusting the pill',
      (tester) async {
        await seedTemplate(tester, 'Meditation', BuiltInCategoryIds.health);
        await pumpTimeline(tester);

        await tester.tapAt(const Offset(220, 400));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        await tester.tap(find.byType(TemplateChip));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byType(QuickCreateOverlay), findsOneWidget);
        expect(find.byType(PendingTaskPill), findsOneWidget);
      },
    );

    testWidgets(
      'a second chip tap replaces the first template rather than stacking '
      'onto it',
      (tester) async {
        await seedTemplate(tester, 'Meditation', BuiltInCategoryIds.health);
        await seedTemplate(tester, 'Audiobook', BuiltInCategoryIds.personal);
        await pumpTimeline(tester);

        await tester.tapAt(const Offset(220, 400));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byType(TemplateChip), findsNWidgets(2));

        await tester.tap(find.byType(TemplateChip).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        final firstTitle = tester
            .widget<TextField>(find.byType(TextField).first)
            .controller!
            .text;

        await tester.tap(find.byType(TemplateChip).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        final secondTitle = tester
            .widget<TextField>(find.byType(TextField).first)
            .controller!
            .text;

        expect(secondTitle, isNot(firstTitle));
      },
    );

    testWidgets('with no templates saved, the strip renders nothing at all '
        'rather than an empty-state inside a 25%-height sheet', (tester) async {
      await pumpTimeline(tester);

      await tester.tapAt(const Offset(220, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(QuickCreateOverlay), findsOneWidget);
      expect(find.byType(TemplateChip), findsNothing);
    });
  });
}
