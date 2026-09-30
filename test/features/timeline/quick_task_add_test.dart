import 'package:flutter/material.dart';
import 'package:amble/features/task_detail/task_sheet_fields.dart';
import 'package:amble/core/widgets/app_size_reporter.dart';
import 'package:amble/core/widgets/app_sheet_surface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/clock_provider.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_wheel_time_picker.dart';
import 'package:amble/core/widgets/app_press_feedback.dart';
import 'package:amble/core/widgets/app_pane.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_value_chip.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/core/widgets/app_text_field.dart';
import 'package:amble/features/task_detail/quick_create_sheet_shell.dart';
import 'package:amble/features/timeline/pending_task_draft_provider.dart';
import 'package:amble/core/widgets/glass_pill_surface.dart';
import 'package:amble/features/timeline/edit_mode_wiggle.dart';
import 'package:amble/features/timeline/pending_task_pill.dart';
import 'package:amble/core/widgets/app_top_scroll_fade.dart';
import 'package:amble/core/widgets/app_sheet_header.dart';
import 'package:amble/core/widgets/app_switch.dart';
import 'package:amble/features/timeline/quick_create_overlay.dart';
import 'package:amble/features/timeline/resize_handle.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/template_chip_strip.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
import 'package:amble/features/task_detail/task_behavior_modal.dart';
import 'package:amble/features/task_detail/task_category_modal.dart';
import 'package:amble/features/task_detail/task_duration_modal.dart';
import 'package:amble/features/task_detail/task_preset_modal.dart';
import 'package:amble/features/task_detail/task_repeat_modal.dart';
import 'package:amble/features/task_detail/task_start_time_modal.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/behavior_target_type.dart';
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

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  });
}

Future<void> _moveTaskStart(
  WidgetTester tester, {
  required String title,
  required int hour,
}) async {
  final titleFinder = find.text(title);
  await tester.ensureVisible(titleFinder);
  await tester.tap(titleFinder);
  await tester.pumpAndSettle();
  // Editing: the chips run Date, Time, Duration — the time chip opens the
  // Start time picker.
  await _tapAndSettle(
    tester,
    find
        .descendant(
          of: find.byType(TaskSheetFields),
          matching: find.byType(AppValueChip),
        )
        .at(1),
  );
  tester.widget<AppWheelPicker>(find.byType(AppWheelPicker)).onChanged(hour, 0);
  await tester.pumpAndSettle();
  await _tapAndSettle(tester, find.text('Done'));
}

final _noon = () {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 12);
}();

/// End-to-end coverage, through the REAL `TimelineScreen`, for the "quick
/// task add" long-press interaction — originally requested as a plain tap
/// ("tap on an empty space in timeline view... puts a gray default
/// task and opens a small sheet with a task name input without the
/// keyboard opened... a little handle in the middle that the user can
/// extend to near full size add sheet"), then **2026-09-27** superseded by
/// a long-press: "Instead of tap to create new task we'll have 'quick
/// task add'... long press and when task is shown (no sheet yet coming)
/// user can move down or up to set length... on release we show sheet
/// quick add." Every case below still exercises the same end state (the
/// placeholder pill and the mini sheet) — only the gesture that reaches it
/// changed, via `longPressAndReleaseAt`.
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
          // Pinned to midday so the Timeline opens scrolled into the
          // fixtures' hours at any time of day (late runs used to open
          // past them).
          nowProvider.overrideWithValue(() => _noon),
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

  /// Starts, holds past the long-press threshold, and releases a "quick
  /// task add" hold at [point] — the full replacement for what a plain
  /// `tester.tapAt` used to do before tap-to-create was removed (see
  /// `place_task_line.dart`'s own doc comment on the 2026-09-27
  /// redesign). Every call site in this file that used to drop a draft
  /// with a bare tap now needs the whole hold-then-release sequence to
  /// reach the same end state (pill AND sheet both visible) — the release
  /// is what reveals `QuickCreateOverlay` now, not the hold itself.
  Future<void> longPressAndReleaseAt(WidgetTester tester, Offset point) async {
    final gesture = await tester.startGesture(point);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets(
    'long-pressing empty Timeline space drops a still placeholder pill '
    'and, on release, opens the small quick-create overlay with no '
    'keyboard',
    (tester) async {
      await pumpTimeline(tester);

      // A hold well clear of any hour-gutter/chrome, inside the day
      // column's empty background.
      await longPressAndReleaseAt(tester, const Offset(220, 400));

      expect(
        find.byType(PendingTaskPill),
        findsOneWidget,
        reason: 'the placeholder pill must appear immediately',
      );
      final wiggle = tester.widget<EditModeWiggle>(find.byType(EditModeWiggle));
      expect(wiggle.enabled, isFalse);
      expect(find.byType(QuickCreateOverlay), findsOneWidget);
      // Not a pushed route — the small panel's own button, same
      // shape/position as the big sheet's. "Add" commits the task outright
      // rather than handing off to the full form.
      expect(find.widgetWithText(ElevatedButton, 'Add'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(QuickCreateOverlay),
          matching: find.byType(AppValueChip),
        ),
        // Preset, date, time, duration; ★, #, tracked, bell, repeat, note.
        findsNWidgets(10),
      );
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('15m'), findsOneWidget);
      expect(
        tester
            .getRect(
              find
                  .descendant(
                    of: find.byType(QuickCreateOverlay),
                    matching: find.byType(AppValueChip),
                  )
                  .first,
            )
            .width,
        lessThan(tester.getRect(find.byType(QuickCreateOverlay)).width),
      );

      // No keyboard: the Name field must not be autofocused.
      final nameField = tester.widget<TextField>(find.byType(TextField).first);
      expect(nameField.autofocus, isFalse);
      // Pre-filled with a real default rather than starting empty.
      // Two now: the sheet's own Name field AND the pill, which carries
      // its title since it became a real task-shaped capsule.
      expect(find.text('New thing'), findsNWidgets(2));
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

      await longPressAndReleaseAt(tester, const Offset(220, 400));

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

  testWidgets(
    'the label chip opens the shared label sheet and keeps the selected label',
    (tester) async {
      final work = Category(
        id: BuiltInCategoryIds.work,
        name: 'Work',
        colorToken: 2,
        emoji: '',
        iconCodePoint: Icons.work_outline_rounded.codePoint,
        isBuiltIn: true,
      );
      await tester.runAsync(() => categoryBox.put(work.id, work));

      await pumpTimeline(tester);
      await longPressAndReleaseAt(tester, const Offset(220, 400));

      final labelChip = find.ancestor(
        of: find.text('#'),
        matching: find.byType(AppValueChip),
      );
      expect(labelChip, findsOneWidget);

      await tester.tap(labelChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(TaskCategoryModal), findsOneWidget);
      expect(find.byType(AppSheetHeader), findsOneWidget);
      final addLabelButton = find.ancestor(
        of: find.descendant(
          of: find.byType(TaskCategoryModal),
          matching: find.byIcon(Icons.add_rounded),
        ),
        matching: find.byType(AppButton),
      );
      expect(addLabelButton, findsOneWidget);
      expect(
        tester.widget<AppButton>(addLabelButton).variant,
        AppButtonVariant.primary,
      );
      expect(find.text('+ Add new'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TaskCategoryModal),
          matching: find.byType(AppPane),
        ),
        findsNothing,
      );
      expect(find.text('Work'), findsOneWidget);

      await tester.tap(find.text('Work'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(TaskCategoryModal), findsNothing);
      expect(tester.widget<AppValueChip>(labelChip).hasValue, isTrue);
    },
  );

  testWidgets('new label opens as one sheet with a header save action', (
    tester,
  ) async {
    await pumpTimeline(tester);
    await longPressAndReleaseAt(tester, const Offset(220, 400));

    await tester.tap(
      find.ancestor(
        of: find.descendant(
          of: find.byType(QuickCreateOverlay),
          matching: find.text('#'),
        ),
        matching: find.byType(AppValueChip),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final addLabelButton = find.ancestor(
      of: find.descendant(
        of: find.byType(TaskCategoryModal),
        matching: find.byIcon(Icons.add_rounded),
      ),
      matching: find.byType(AppButton),
    );
    await tester.tap(addLabelButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('New label'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Done'), findsNothing);
    expect(find.byType(AppPane), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppTextField &&
            widget.label == 'Label name' &&
            widget.variant == AppTextFieldVariant.bare,
      ),
      findsOneWidget,
    );
  });

  testWidgets('the mini sheet shows an Important star chip, off by default, '
      'and Add writes it to the created task', (tester) async {
    await pumpTimeline(tester);

    await longPressAndReleaseAt(tester, const Offset(220, 400));

    final starIcon = find.descendant(
      of: find.byType(QuickCreateOverlay),
      matching: find.byIcon(Icons.star_rounded),
    );
    final importantChip = find.ancestor(
      of: starIcon,
      matching: find.byType(AppValueChip),
    );
    expect(importantChip, findsOneWidget);
    expect(tester.widget<AppValueChip>(importantChip).hasValue, isFalse);

    final chipRows = tester
        .widgetList<Wrap>(
          find.descendant(
            of: find.byType(QuickCreateOverlay),
            matching: find.byType(Wrap),
          ),
        )
        .toList();
    expect(chipRows, hasLength(2));
    final firstRow = chipRows.first.children.whereType<AppValueChip>().toList();
    final secondRow = chipRows[1].children.whereType<AppValueChip>().toList();
    expect(firstRow.first.label, 'Preset');
    expect(firstRow, hasLength(4));
    expect(secondRow.first.icon, Icons.star_rounded);

    await tester.tap(importantChip);
    await tester.pump();
    expect(tester.widget<AppValueChip>(importantChip).hasValue, isTrue);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
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

  testWidgets('spatial Timeline reserves scroll clearance around the day', (
    tester,
  ) async {
    await pumpTimeline(tester);

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).first,
    );
    expect(
      scrollView.padding,
      EdgeInsets.only(
        top: TimelineScrollTokens.topClearance,
        bottom: TimelineScrollTokens.bottomClearance,
      ),
    );
  });

  testWidgets('tapping Add creates the task directly, with no full '
      'sheet in between, and clears the placeholder pill', (tester) async {
    await pumpTimeline(tester);
    expect(taskBox.values, isEmpty);

    await longPressAndReleaseAt(tester, const Offset(220, 400));

    // Same real-Hive-write polling the promoted-save test below uses —
    // createTask's disk write doesn't complete on any fixed frame
    // schedule, so pumping a fixed budget races it. See ERROR_LOG.md.
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
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
    expect(taskBox.values.first.title, 'New thing');

    // The full sheet never appeared, and the placeholder is gone — the
    // real task pill replaces it.
    expect(find.byType(QuickCreateSheetHandle), findsNothing);
    expect(find.byType(QuickCreateOverlay), findsNothing);
    expect(find.byType(PendingTaskPill), findsNothing);
  });

  // Overlapping schedules are allowed in forms. The setting only constrains
  // whether a pending draft can be moved into an unresolvable slot.
  testWidgets('Add creates an overlapping task when overlap checks are '
      'enabled', (tester) async {
    await tester.runAsync(
      () => preferencesBox.put('preventOverlappingTasks', true),
    );
    // Anchored around `now` (like the tap position below, which always
    // lands near `now` because the Timeline scrolls to centre on it) rather
    // than a fixed clock-hour span — a fixed 9:00-19:00 window only
    // overlapped the tap's actual landing spot by coincidence of when the
    // suite happened to run, and missed it (as a real, reproducible
    // failure, not flakiness) once `now` fell outside that window.
    // The Timeline's clock is pinned to midday (see pumpTimeline), so anchor
    // to that same instant.
    final now = _noon;
    final existing = Task.create(
      title: 'Existing task',
      scheduledAt: now.subtract(const Duration(hours: 5)),
      durationMinutes: 600,
      categoryId: BuiltInCategoryIds.general,
    );
    await tester.runAsync(() => taskBox.put(existing.id, existing));

    await pumpTimeline(tester);

    await longPressAndReleaseAt(tester, const Offset(220, 400));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimelineScreen)),
    );
    container.read(pendingTaskDraftProvider.notifier).updateDuration(90);
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        if (taskBox.values.length > 1) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();

    expect(taskBox.values, hasLength(2));
    final created = taskBox.values.singleWhere(
      (task) => task.title == 'New thing',
    );
    expect(created.scheduledAt, isNotNull);
    expect(created.durationMinutes, 90);
    expect(
      created.scheduledAt!.isBefore(
        existing.scheduledAt!.add(Duration(minutes: existing.durationMinutes!)),
      ),
      isTrue,
    );
    expect(
      created.scheduledAt!
          .add(Duration(minutes: created.durationMinutes!))
          .isAfter(existing.scheduledAt!),
      isTrue,
    );
    expect(find.textContaining('overlaps another task'), findsNothing);
    expect(find.byType(QuickCreateOverlay), findsNothing);
  });

  testWidgets(
    'editing a task into an occupied time saves, scrolls to it, and opens '
    'the overlap resolution menu',
    (tester) async {
      await tester.runAsync(
        () => preferencesBox.put('preventOverlappingTasks', true),
      );
      final now = DateTime.now();
      final firstStart = DateTime(now.year, now.month, now.day, 9);
      final edited = Task.create(
        title: 'Edited task',
        scheduledAt: firstStart,
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.general,
      );
      final neighbor = Task.create(
        title: 'Neighbor task',
        scheduledAt: firstStart.add(const Duration(hours: 1)),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.general,
      );
      await tester.runAsync(() async {
        await taskBox.put(edited.id, edited);
        await taskBox.put(neighbor.id, neighbor);
      });
      await pumpTimeline(tester);

      await _moveTaskStart(tester, title: 'Edited task', hour: 10);
      final saveAction = find.ancestor(
        of: find.text('Save'),
        matching: find.byType(AppPressFeedback),
      );
      await _tapAndSettle(tester, saveAction);

      expect(find.text('Edit task'), findsNothing);
      expect(find.textContaining('overlaps another task'), findsNothing);
      expect(find.text('Overlap'), findsOneWidget);
      expect(find.text('Push all'), findsOneWidget);
      expect(find.text('Trim'), findsOneWidget);
      expect(
        taskBox.get(edited.id)!.scheduledAt,
        firstStart.add(const Duration(hours: 1)),
      );
    },
  );

  testWidgets(
    'tapping the small sheet\'s own X button closes it and clears the '
    'placeholder pill, same position as the real sheet\'s own close '
    'button',
    (tester) async {
      await pumpTimeline(tester);

      await longPressAndReleaseAt(tester, const Offset(220, 400));

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

      await longPressAndReleaseAt(tester, const Offset(220, 400));

      expect(find.byType(PendingTaskPill), findsOneWidget);
      expect(find.byType(QuickCreateOverlay), findsOneWidget);

      // The sheet has three states as of 2026-09-16 (see
      // `quickCreateSheetMinimisedFraction`), so how far the pull travels
      // decides where it lands. A big, decisive pull still closes in ONE
      // gesture — measured: 300px on this viewport lands at fraction
      // 0.041, well below the close threshold, without stopping at
      // minimised on the way. (A moderate ~150px pull minimises instead;
      // that path has its own test below.)
      Future<void> dragDown(double distance) async {
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(QuickCreateSheetHandle)),
        );
        await tester.pump();
        await gesture.moveBy(Offset(0, distance / 2));
        await tester.pump();
        await gesture.moveBy(Offset(0, distance / 2));
        await tester.pump();
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }

      await dragDown(300);

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

      await longPressAndReleaseAt(tester, const Offset(220, 400));

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

  double sheetHeight(WidgetTester tester) => tester
      .getSize(
        find.descendant(
          of: find.byType(QuickCreateOverlay),
          matching: find.byType(AppSheetSurface),
        ),
      )
      .height;

  Future<void> dragHandleUp(WidgetTester tester, double by) async {
    // A `pump()` between EVERY gesture step — see the pill-drag test
    // above's own doc comment for why (onVerticalDragUpdate doesn't
    // register at all otherwise, in this full TimelineScreen tree).
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(QuickCreateSheetHandle)),
    );
    await tester.pump();
    await gesture.moveBy(Offset(0, -by / 2));
    await tester.pump();
    await gesture.moveBy(Offset(0, -by / 2));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('dragging the handle up expands the same sheet in place — '
      'the fields stay, the placeholder pill stays on Timeline', (
    tester,
  ) async {
    await pumpTimeline(tester);
    await longPressAndReleaseAt(tester, const Offset(220, 400));
    final small = sheetHeight(tester);

    await dragHandleUp(tester, 400);

    expect(sheetHeight(tester), greaterThan(small * 1.5));
    expect(find.byType(QuickCreateSheetHandle), findsOneWidget);
    expect(find.byType(TaskSheetFields), findsOneWidget);
    expect(find.byType(PendingTaskPill), findsOneWidget);
  });

  testWidgets(
    'a SHORT upward drag on the handle is enough to expand — reported '
    'directly as "difficult to do" when it demanded most of the screen',
    (tester) async {
      await pumpTimeline(tester);
      await longPressAndReleaseAt(tester, const Offset(220, 400));
      final small = sheetHeight(tester);

      // ~70px total, nowhere near the ~380px the old midpoint rule
      // needed on this 932px-tall test viewport.
      await dragHandleUp(tester, 70);

      expect(sheetHeight(tester), greaterThan(small * 1.5));
    },
  );

  testWidgets(
    'the name is typed in place: the first tap clears "New thing", the '
    'sheet stays, and Add saves what was typed',
    (tester) async {
      await pumpTimeline(tester);
      await longPressAndReleaseAt(tester, const Offset(220, 400));

      await tester.tap(find.byType(TextField).first);
      await tester.pump();

      // Still the same small sheet, now with an empty name — reported
      // directly: "New task name input should be reset to nothing, clears,
      // so user can type in from scratch." Scoped to the sheet: the PILL
      // still shows its own "New thing" label.
      expect(find.byType(QuickCreateSheetHandle), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller!.text, isEmpty);
      expect(
        find.descendant(
          of: find.byType(QuickCreateOverlay),
          matching: find.text('New thing'),
        ),
        findsNothing,
      );

      await tester.enterText(find.byType(TextField).first, 'Quick task');
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
        await tester.pump();
        // The real Hive write doesn't complete on any fixed frame schedule
        // (docs/ERROR_LOG.md) — poll with real delays until the sheet's
        // draft (and with it the overlay) is gone.
        for (var i = 0; i < 20; i++) {
          if (find.byType(QuickCreateOverlay).evaluate().isEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
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
  testWidgets('a freshly-held draft renders as a task-shaped pill carrying '
      'the "New thing" name, with no category emoji', (tester) async {
    await pumpTimeline(tester);

    await longPressAndReleaseAt(tester, const Offset(220, 400));

    expect(find.byType(PendingTaskPill), findsOneWidget);
    // The name appears on the pill itself, not only in the mini sheet's
    // own field — so `findsWidgets`, not `findsOneWidget`.
    expect(
      find.descendant(
        of: find.byType(PendingTaskPill),
        matching: find.text('New thing'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the draft defaults to a 15-minute duration', (tester) async {
    await pumpTimeline(tester);

    await longPressAndReleaseAt(tester, const Offset(220, 400));

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
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
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
  // position as other names and the draft is still (as it should be)." Asserted
  // here, in a real TimelineScreen, because the isolated test supplied
  // its own geometry and so could agree with a wrong formula.
  group('placeholder title, in a real Timeline (2026-09-08)', () {
    testWidgets('the name is NOT inside any EditModeWiggle', (tester) async {
      await pumpTimeline(tester);

      await longPressAndReleaseAt(tester, const Offset(220, 400));

      final titleOnPill = find.descendant(
        of: find.byType(PendingTaskPill),
        matching: find.text('New thing'),
      );
      expect(titleOnPill, findsOneWidget);
      expect(
        find.ancestor(of: titleOnPill, matching: find.byType(EditModeWiggle)),
        findsNothing,
        reason:
            'the placeholder name must not wiggle, same as a real '
            'task name in Edit Mode',
      );
      final wiggle = tester.widget<EditModeWiggle>(find.byType(EditModeWiggle));
      expect(wiggle.enabled, isFalse);
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

      // Held well clear of the existing task, so both sit in lane 0 and
      // their names must therefore share one x.
      await longPressAndReleaseAt(tester, const Offset(220, 500));

      final realNameX = tester.getTopLeft(find.text('Existing task')).dx;
      final draftNameX = tester
          .getTopLeft(
            find.descendant(
              of: find.byType(PendingTaskPill),
              matching: find.text('New thing'),
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

        await longPressAndReleaseAt(tester, const Offset(220, 400));

        final surface = find.descendant(
          of: find.byType(PendingTaskPill),
          matching: find.byType(GlassPillSurface),
        );
        expect(surface, findsOneWidget);

        final widget = tester.widget<GlassPillSurface>(surface);
        expect(
          widget.material,
          GlassPillMaterial.glass,
          reason:
              'the draft is airborne/provisional — it gets the frosted '
              'material, not the imported event\'s flat gray',
        );
        expect(
          widget.child,
          isNull,
          reason:
              'a draft has no category yet — any glyph would be '
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
    'holding a late-evening slot scrolls the draft into the space ABOVE '
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

      // Hold, then release, at the now-visible 22:00 row.
      final screenY = targetY - position.pixels;
      final gesture = await tester.startGesture(Offset(220, screenY));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
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
    await longPressAndReleaseAt(tester, const Offset(220, 400));

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

    await longPressAndReleaseAt(tester, const Offset(220, 400));

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

    await longPressAndReleaseAt(tester, const Offset(220, 400));

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

  testWidgets('the mini sheet hugs its content — no empty band under the '
      'chips — and ends in the bottom fade', (tester) async {
    await pumpTimeline(tester);
    await longPressAndReleaseAt(tester, const Offset(220, 400));
    // Bounded pumps (the Timeline animates perpetually): the measure lands
    // a frame after layout, then the height eases in.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final sheet = tester.getSize(
      find.descendant(
        of: find.byType(QuickCreateOverlay),
        matching: find.byType(AppSheetSurface),
      ),
    );
    final content = tester.getSize(
      find.descendant(
        of: find.byType(QuickCreateOverlay),
        matching: find.byType(AppSizeReporter),
      ),
    );
    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(sheet.height, closeTo(content.height, 1));
    expect(sheet.height, lessThan(screen * quickCreateSheetMinFraction));
    expect(
      find.descendant(
        of: find.byType(QuickCreateOverlay),
        matching: find.byWidgetPredicate(
          (w) => w is AppTopScrollFade && w.fromBottom,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('saved presets stay hidden until the Preset sheet is built', (
    tester,
  ) async {
    await seedTemplate(tester, 'Meditation', BuiltInCategoryIds.health);
    await pumpTimeline(tester);

    await longPressAndReleaseAt(tester, const Offset(220, 400));

    expect(find.byType(QuickCreateOverlay), findsOneWidget);
    expect(find.byType(TemplateChip), findsNothing);
    expect(find.text('Preset'), findsOneWidget);
  });

  testWidgets('Preset opens its sheet and applies the selected task values', (
    tester,
  ) async {
    await seedTemplate(
      tester,
      'Meditation',
      BuiltInCategoryIds.health,
      isImportant: true,
    );
    await pumpTimeline(tester);

    await longPressAndReleaseAt(tester, const Offset(220, 400));

    final presetChip = find.ancestor(
      of: find.text('Preset'),
      matching: find.byType(AppValueChip),
    );
    await tester.tap(presetChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TaskPresetModal), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TaskPresetModal),
        matching: find.byType(AppPane),
      ),
      findsNothing,
    );
    expect(find.text('Meditation'), findsOneWidget);

    await tester.tap(find.text('Meditation'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TaskPresetModal), findsNothing);
    expect(find.text('Meditation'), findsOneWidget);
    final starChip = find.ancestor(
      of: find.byIcon(Icons.star_rounded),
      matching: find.byType(AppValueChip),
    );
    expect(tester.widget<AppValueChip>(starChip).hasValue, isTrue);
  });

  testWidgets('notification and repeat chips use focused sheets and state', (
    tester,
  ) async {
    await pumpTimeline(tester);
    await longPressAndReleaseAt(tester, const Offset(220, 400));

    final notificationChip = find.ancestor(
      of: find.byIcon(Icons.notifications_rounded),
      matching: find.byType(AppValueChip),
    );
    expect(tester.widget<AppValueChip>(notificationChip).hasValue, isTrue);

    await tester.tap(notificationChip);
    await tester.pump();
    expect(find.byIcon(Icons.notifications_off_rounded), findsOneWidget);
    final disabledNotificationChip = find.ancestor(
      of: find.byIcon(Icons.notifications_off_rounded),
      matching: find.byType(AppValueChip),
    );
    expect(
      tester.widget<AppValueChip>(disabledNotificationChip).hasValue,
      isFalse,
    );

    final repeatChip = find.ancestor(
      of: find.byIcon(Icons.repeat_rounded),
      matching: find.byType(AppValueChip),
    );
    await tester.tap(repeatChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TaskRepeatModal), findsOneWidget);
    final repeatSwitch = find.descendant(
      of: find.byType(TaskRepeatModal),
      matching: find.byType(AppSwitch),
    );
    expect(tester.widget<AppSwitch>(repeatSwitch).value, isFalse);
    await tester.tap(repeatSwitch);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(TaskRepeatModal),
        matching: find.text('M'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TaskRepeatModal), findsNothing);
    expect(tester.widget<AppValueChip>(repeatChip).hasValue, isTrue);
  });

  testWidgets('tracked, time, and duration chips open their own sheets', (
    tester,
  ) async {
    final behavior = TrackedBehavior.create(
      title: 'Exercise',
      targetType: BehaviorTargetType.binary,
      timesPerWeek: 3,
    );
    await tester.runAsync(() => trackedBehaviorBox.put(behavior.id, behavior));
    await pumpTimeline(tester);
    await longPressAndReleaseAt(tester, const Offset(220, 400));

    final behaviorChip = find.ancestor(
      of: find.byIcon(Icons.fingerprint_rounded),
      matching: find.byType(AppValueChip),
    );
    await tester.tap(behaviorChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TaskBehaviorModal), findsOneWidget);
    final addBehaviorButton = find.ancestor(
      of: find.descendant(
        of: find.byType(TaskBehaviorModal),
        matching: find.byIcon(Icons.add_rounded),
      ),
      matching: find.byType(AppButton),
    );
    expect(addBehaviorButton, findsOneWidget);
    expect(
      tester.widget<AppButton>(addBehaviorButton).variant,
      AppButtonVariant.primary,
    );
    expect(find.widgetWithText(ElevatedButton, 'Done'), findsNothing);
    expect(find.text('Exercise'), findsOneWidget);
    await tester.tap(find.text('Exercise'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<AppValueChip>(behaviorChip).hasValue, isTrue);

    final chips = find.descendant(
      of: find.byType(QuickCreateOverlay),
      matching: find.byType(AppValueChip),
    );
    await tester.tap(chips.at(2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TaskStartTimeModal), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(chips.at(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TaskDurationModal), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TaskDurationModal), findsNothing);
  });

  // The third sheet state, requested directly against a reference
  // screenshot: "when scrolled, we need this state: just the title is
  // shown, and there is this little handle to expand or tap to expand.
  // When tapped, it expands to this mini sheet, not a minimized sheet,
  // but a small sheet as it is at the beginning... So we need 3 states."
  //
  // Confirmed directly that a downward HANDLE DRAG is what collapses it
  // (rather than scrolling the timeline behind it).
  group('minimised state (2026-09-16)', () {
    Future<void> openThenMinimise(WidgetTester tester) async {
      await longPressAndReleaseAt(tester, const Offset(220, 400));

      // A MODERATE pull: far enough to leave the small sheet, not so far
      // that it closes outright (300px does — see the drag-to-close test).
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(QuickCreateSheetHandle)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, 75));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 75));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }

    testWidgets('a moderate pull down minimises rather than closing — the '
        'draft and its placeholder pill both survive', (tester) async {
      await pumpTimeline(tester);
      await openThenMinimise(tester);

      expect(find.byType(QuickCreateOverlay), findsOneWidget);
      expect(
        find.byType(PendingTaskPill),
        findsOneWidget,
        reason: 'a minimised draft is still a live draft',
      );
    });

    testWidgets('minimised shows ONLY the title — no Add, no template '
        'strip, no editable field', (tester) async {
      await pumpTimeline(tester);
      await openThenMinimise(tester);

      // The default draft name, rendered as plain text INSIDE the sheet.
      // Scoped to the overlay: the placeholder pill on the Timeline
      // renders the same name, so an unscoped finder matches twice.
      expect(
        find.descendant(
          of: find.byType(QuickCreateOverlay),
          matching: find.text('New thing'),
        ),
        findsOneWidget,
      );
      expect(find.byType(AppTextField), findsNothing);
      expect(find.text('Add'), findsNothing);
      expect(find.byType(TemplateChipStrip), findsNothing);
    });

    testWidgets('tapping the minimised sheet restores the SMALL sheet, not '
        'the full one', (tester) async {
      await pumpTimeline(tester);
      await openThenMinimise(tester);

      await tester.tap(find.byType(QuickCreateSheetHandle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Back to the small sheet: its own field and Add button are
      // there again, and it did NOT skip ahead to the full pushed sheet
      // (which would have replaced this overlay entirely).
      expect(find.byType(QuickCreateOverlay), findsOneWidget);
      expect(find.byType(AppTextField), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });
  });
}
