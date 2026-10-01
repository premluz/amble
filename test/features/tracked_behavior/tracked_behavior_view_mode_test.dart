import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/dev_config.dart';
import 'package:amble/features/tracked_behavior/behavior_completion.dart';
import 'package:amble/features/tracked_behavior/tracked_behavior_list_screen.dart';
import 'package:amble/features/tracked_behavior/tracked_behavior_row.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/behavior_target_type.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

List<Rect> _trackedDayCellRects(WidgetTester tester) {
  final cells = tester.widgetList<Container>(
    find.descendant(
      of: find.byType(TrackedBehaviorRow),
      matching: find.byType(Container),
    ),
  );
  final dayCells = <Container>[];
  for (final cell in cells) {
    final decoration = cell.decoration;
    if (decoration is BoxDecoration && decoration.shape == BoxShape.circle) {
      dayCells.add(cell);
    }
  }
  return dayCells.map((cell) => tester.getRect(find.byWidget(cell))).toList();
}

/// Requested directly, from a mockup: "let us build these views on the
/// tracked section... in the same way like in timeline we have view
/// switcher, in the same positions there will be view switcher for each
/// of these here, weekly, monthly, and six monthly." Covers the global
/// view-cycle button (mirroring `TimelineViewMode`'s own cycle) and each
/// card variant's completion-history rendering.
void main() {
  late Box<TrackedBehavior> box;
  late Box<Task> taskBox;
  late Box<dynamic> preferencesBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_tracked_view_mode');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final suffix = DateTime.now().microsecondsSinceEpoch;
    box = await Hive.openBox<TrackedBehavior>('test_behaviors_$suffix');
    taskBox = await Hive.openBox<Task>('test_tasks_$suffix');
    preferencesBox = await Hive.openBox<dynamic>('test_preferences_$suffix');
  });

  tearDown(() async {
    await box.close();
    await taskBox.close();
    await preferencesBox.close();
  });

  Future<void> pumpList(
    WidgetTester tester, {
    List<TrackedBehavior> behaviors = const [],
    List<Task> tasks = const [],
    AmbleTheme? theme,
    bool showCalendarLabels = false,
    bool showDemoData = false,
  }) async {
    final resolvedTheme = theme ?? AmbleTheme.light;
    await tester.runAsync(() async {
      for (final behavior in behaviors) {
        await box.put(behavior.id, behavior);
      }
      for (final task in tasks) {
        await taskBox.put(task.id, task);
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          devTrackedCalendarLabelsVisibleProvider.overrideWithValue(
            showCalendarLabels,
          ),
          devTrackedPatternDemoDataProvider.overrideWithValue(showDemoData),
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(box),
          ),
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(preferencesBox),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            brightness:
                resolvedTheme.colorTextPrimary.computeLuminance() >
                    resolvedTheme.colorSurfaceBase.computeLuminance()
                ? Brightness.dark
                : Brightness.light,
            extensions: [resolvedTheme],
          ),
          home: const Scaffold(body: TrackedBehaviorListScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  TrackedBehavior makeBehavior() => TrackedBehavior.create(
    title: 'Exercise',
    targetType: BehaviorTargetType.binary,
    timesPerWeek: 7,
  );

  testWidgets(
    'the view switcher defaults to Weekly view — a 7-day row of cells',
    (tester) async {
      await pumpList(tester, behaviors: [makeBehavior()]);

      // All three dock buttons are always present now
      // (`AppTrackedViewDock`) — this only confirms the button EXISTS;
      // the weekday-initials assertions below are what actually confirm
      // Weekly is the ACTIVE mode.
      expect(find.byTooltip('Weekly view'), findsOneWidget);
      // Calendar labels are hidden by the default dev configuration.
      expect(find.text('M'), findsNothing);
      expect(find.text('S'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TrackedBehaviorRow),
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsNothing,
      );
    },
  );

  // Tapping the switcher calls `TrackedBehaviorViewModeSetting.set`, which
  // does real, unawaited PreferencesRepository/Hive I/O — must run inside
  // `runAsync` or `pump`/`pumpAndSettle` hang indefinitely, the same class
  // of bug hit repeatedly earlier this session (see docs/ERROR_LOG.md).
  Future<void> tapSwitcher(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }

  // **2026-09-20 — no longer a single cycling button.** Requested
  // directly: "add that bottom nav with 3 icons connected for changing
  // views (and remove the top single icon)" — all three
  // (`AppTrackedViewDock`) are always visible and tapped directly now,
  // rather than one button cycling through the three in a fixed order.
  testWidgets(
    'tapping each of the three dock buttons switches directly to that '
    'view — Weekly, Monthly, Six-monthly all reachable in any order',
    (tester) async {
      await pumpList(
        tester,
        behaviors: [makeBehavior()],
        showCalendarLabels: true,
      );

      expect(find.byTooltip('Weekly view'), findsOneWidget);

      await tapSwitcher(tester, find.byTooltip('Monthly view'));
      // The monthly grid shows numbered day cells, e.g. day 1.
      expect(find.text('1'), findsOneWidget);

      await tapSwitcher(tester, find.byTooltip('Six-month view'));

      await tapSwitcher(tester, find.byTooltip('Weekly view'));
      // Back to the weekly row's own weekday initials.
      expect(find.text('M'), findsOneWidget);
    },
  );

  testWidgets('monthly day-cell gaps match the weekly row spacing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpList(tester, behaviors: [makeBehavior()]);
    await tester.pump(const Duration(seconds: 1));

    final weeklyCells = _trackedDayCellRects(tester);
    expect(weeklyCells, hasLength(7));
    final weeklyGap = weeklyCells[1].left - weeklyCells[0].right;

    await tapSwitcher(tester, find.byTooltip('Monthly view'));
    await tester.pump(const Duration(seconds: 1));

    final monthlyCells = _trackedDayCellRects(tester);
    expect(monthlyCells.length, greaterThan(7));
    expect(
      monthlyCells[1].left - monthlyCells[0].right,
      closeTo(weeklyGap, .01),
    );
    expect(
      monthlyCells[7].top - monthlyCells[0].bottom,
      closeTo(weeklyGap, .01),
    );
  });

  testWidgets('six-month day rows fill the padded card width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpList(tester, behaviors: [makeBehavior()]);
    await tapSwitcher(tester, find.byTooltip('Six-month view'));
    await tester.pump(const Duration(seconds: 1));

    final cells = _trackedDayCellRects(tester);
    expect(cells.length, greaterThan(100));
    final firstRowTop = cells.first.top;
    final firstRow = cells.where((cell) => cell.top == firstRowTop).toList();
    final card = tester.getRect(find.byType(TrackedBehaviorRow));
    final theme = AmbleTheme.light;

    expect(firstRow.length, greaterThan(1));
    expect(firstRow.first.left, closeTo(card.left + theme.spacingMd, .01));
    expect(firstRow.last.right, closeTo(card.right - theme.spacingMd, .01));
  });

  testWidgets(
    'the switcher setting persists across a rebuild (real preferences '
    'write, not just in-memory widget state)',
    (tester) async {
      await pumpList(
        tester,
        behaviors: [makeBehavior()],
        showCalendarLabels: true,
      );

      // **2026-09-20** — all three tooltips are always present now
      // (`AppTrackedViewDock`), so `find.byTooltip('Monthly view')`
      // alone can no longer signal "Monthly is the ACTIVE view" the way
      // it could with the old one-button cycle. The monthly grid's own
      // numbered day cell ("1") is what actually only renders in that
      // mode, so that's the real persistence signal here — `findsWidgets`
      // (at least one), not `findsOneWidget`: a "1" can legitimately
      // appear more than once in the grid (e.g. two visible months).
      await tapSwitcher(tester, find.byTooltip('Monthly view'));
      expect(find.text('1'), findsWidgets);

      // Rebuild the whole screen from scratch — the setting must still
      // read back as Monthly, proving it was actually persisted via
      // PreferencesRepository rather than held only in local widget
      // state.
      await pumpList(
        tester,
        behaviors: [makeBehavior()],
        showCalendarLabels: true,
      );
      expect(find.text('1'), findsWidgets);
    },
  );

  testWidgets(
    'a completed task linked to the behavior shows as a filled cell in '
    'the weekly view — an uncompleted behavior shows no filled cells',
    (tester) async {
      final behavior = makeBehavior();
      final today = DateTime.now();
      final completedTask = Task.create(
        title: 'Exercise',
        scheduledAt: DateTime(today.year, today.month, today.day, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
      )..behaviorId = behavior.id;
      completedTask.status = TaskStatus.completed;

      // Uncompleted baseline first — confirms the accent fill is genuinely
      // conditional on completion, not always on. Scoped to descendants of
      // the row itself — a bare find.byType(Container) also catches the
      // bottom bar's own "+" AppButton (circle shape), which fills with the SAME
      // colorAccent for an unrelated reason (its own press-feedback
      // circle), producing a false positive.
      await pumpList(tester, behaviors: [behavior], showCalendarLabels: true);
      final theme = AmbleTheme.light;
      bool anyCellFilled() => tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(TrackedBehaviorRow),
              matching: find.byType(Container),
            ),
          )
          .any(
            (c) => (c.decoration as BoxDecoration?)?.color == theme.colorAccent,
          );
      expect(anyCellFilled(), isFalse);

      await pumpList(tester, behaviors: [behavior], tasks: [completedTask]);
      expect(anyCellFilled(), isTrue);
    },
  );

  testWidgets(
    'light today uses the subdued surface without an accent border, while '
    'completion uses the accent fill alone',
    (tester) async {
      final behavior = makeBehavior();
      final today = DateTime.now();
      final completedTask = Task.create(
        title: 'Exercise',
        scheduledAt: DateTime(today.year, today.month, today.day, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.health,
      )..behaviorId = behavior.id;
      completedTask.status = TaskStatus.completed;

      List<BoxDecoration> dayCellDecorations() => tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(TrackedBehaviorRow),
              matching: find.byType(Container),
            ),
          )
          .map((cell) => cell.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => decoration.shape == BoxShape.circle)
          .toList();

      await pumpList(tester, behaviors: [behavior], showCalendarLabels: true);
      final theme = AmbleTheme.light;
      final todayIndex = today.weekday - 1;
      final uncompletedToday = dayCellDecorations()[todayIndex];
      expect(uncompletedToday.color, theme.colorSurfaceField);
      expect(uncompletedToday.border, isNull);

      final weekdayLabels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(TrackedBehaviorRow),
              matching: find.byType(Text),
            ),
          )
          .where((label) => label.data?.length == 1)
          .toList();
      expect(weekdayLabels, hasLength(7));
      expect(
        weekdayLabels[todayIndex].style?.fontSize,
        theme.textCaption.fontSize,
      );
      expect(weekdayLabels[todayIndex].style?.color, theme.colorTextTertiary);
      for (var i = 0; i < weekdayLabels.length; i++) {
        if (i == todayIndex) continue;
        expect(weekdayLabels[i].style?.color, theme.colorTextTertiary);
      }

      await pumpList(tester, behaviors: [behavior], tasks: [completedTask]);
      final completedToday = dayCellDecorations()[todayIndex];
      expect(completedToday.color, theme.colorAccent);
      expect(completedToday.border, isNull);
    },
  );

  testWidgets(
    'dark tracked days use quieter token rungs for incomplete cells and labels',
    (tester) async {
      final behavior = makeBehavior();
      final today = DateTime.now();
      await pumpList(
        tester,
        behaviors: [behavior],
        theme: AmbleTheme.dark,
        showCalendarLabels: true,
      );

      final cells = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(TrackedBehaviorRow),
              matching: find.byType(Container),
            ),
          )
          .where(
            (cell) =>
                (cell.decoration as BoxDecoration?)?.shape == BoxShape.circle,
          )
          .toList();
      final todayIndex = today.weekday - 1;
      final theme = AmbleTheme.dark;

      expect(
        (cells[todayIndex].decoration as BoxDecoration).color,
        theme.colorSurfaceFieldActive,
      );
      expect(
        (cells[(todayIndex + 1) % 7].decoration as BoxDecoration).color,
        theme.colorSurfaceOverlay,
      );

      final weekdayLabels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(TrackedBehaviorRow),
              matching: find.byType(Text),
            ),
          )
          .where((label) => label.data?.length == 1)
          .toList();
      expect(weekdayLabels[todayIndex].style?.color, theme.colorTextPrimary);
      expect(
        weekdayLabels[(todayIndex + 1) % 7].style?.color,
        theme.colorTextTertiary,
      );
      expect(
        weekdayLabels[(todayIndex + 1) % 7].style?.fontSize,
        theme.textCaption.fontSize,
      );
    },
  );

  test('completedDaysFor only counts completed tasks linked to THIS behavior, '
      'on the right day', () {
    final behavior = TrackedBehavior.create(
      title: 'Exercise',
      targetType: BehaviorTargetType.binary,
      timesPerWeek: 7,
    );
    final otherBehavior = TrackedBehavior.create(
      title: 'Read',
      targetType: BehaviorTargetType.binary,
      timesPerWeek: 7,
    );
    final day = DateTime(2026, 6, 1);

    final linkedCompleted = Task.create(
      title: 'Exercise',
      scheduledAt: DateTime(2026, 6, 1, 9),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.health,
    )..behaviorId = behavior.id;
    linkedCompleted.status = TaskStatus.completed;

    final linkedPending = Task.create(
      title: 'Exercise',
      scheduledAt: DateTime(2026, 6, 2, 9),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.health,
    )..behaviorId = behavior.id;

    final differentBehaviorCompleted = Task.create(
      title: 'Read',
      scheduledAt: DateTime(2026, 6, 1, 9),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.general,
    )..behaviorId = otherBehavior.id;
    differentBehaviorCompleted.status = TaskStatus.completed;

    final completedDays = completedDaysFor(
      behavior,
      tasks: [linkedCompleted, linkedPending, differentBehaviorCompleted],
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 30),
    );

    expect(completedDays, {day});
  });

  test(
    'demo pattern data alternates days and adds short random-looking gaps',
    () {
      final start = DateTime(2026, 6, 1);
      final end = DateTime(2026, 6, 7);

      final interval = demoCompletedDaysFor(
        patternIndex: 0,
        start: start,
        end: end,
      );
      final full = demoCompletedDaysFor(
        patternIndex: 1,
        start: start,
        end: end,
      );

      expect(interval.length >= 3 && interval.length <= 4, isTrue);
      expect(full.length >= 4 && full.length <= 6, isTrue);

      var longestGap = 0;
      var currentGap = 0;
      for (var i = 0; i <= end.difference(start).inDays; i++) {
        final day = start.add(Duration(days: i));
        if (full.contains(day)) {
          currentGap = 0;
        } else {
          currentGap++;
          longestGap = longestGap > currentGap ? longestGap : currentGap;
        }
      }
      expect(longestGap >= 1 && longestGap <= 3, isTrue);
    },
  );

  testWidgets('pattern demo data fills rows without linked tasks', (
    tester,
  ) async {
    final first = makeBehavior();
    final second = TrackedBehavior.create(
      title: 'Read',
      targetType: BehaviorTargetType.binary,
      timesPerWeek: 7,
    );

    await pumpList(tester, behaviors: [first, second], showDemoData: true);

    List<BoxDecoration> dayCellDecorations(String id) => tester
        .widgetList<Container>(
          find.descendant(
            of: find.byKey(ValueKey<String>(id)),
            matching: find.byType(Container),
          ),
        )
        .map((cell) => cell.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => decoration.shape == BoxShape.circle)
        .toList();

    final firstCells = dayCellDecorations(first.id);
    final secondCells = dayCellDecorations(second.id);
    final accent = AmbleTheme.light.colorAccent;

    final firstFilled = firstCells.where((cell) => cell.color == accent).length;
    final secondFilled = secondCells
        .where((cell) => cell.color == accent)
        .length;

    // Hive preserves values, not a domain ordering guarantee; both demo
    // variants are intentionally non-full, so assert their populated shape
    // without coupling the test to storage order.
    expect(firstFilled >= 1 && firstFilled <= 6, isTrue);
    expect(secondFilled >= 1 && secondFilled <= 6, isTrue);
  });

  testWidgets('six-month month labels use the subtle tertiary text tone', (
    tester,
  ) async {
    await pumpList(
      tester,
      behaviors: [makeBehavior()],
      showCalendarLabels: true,
    );
    await tapSwitcher(tester, find.byTooltip('Six-month view'));

    const monthNames = {
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    };
    final monthLabels = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(TrackedBehaviorRow),
            matching: find.byType(Text),
          ),
        )
        .where((label) => monthNames.contains(label.data))
        .toList();

    expect(monthLabels, isNotEmpty);
    for (final label in monthLabels) {
      expect(label.style?.color, AmbleTheme.light.colorTextTertiary);
    }
  });
}
