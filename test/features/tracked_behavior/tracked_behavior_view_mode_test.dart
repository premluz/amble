import 'package:amble/core/tokens/semantic_theme.dart';
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
  }) async {
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
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(box),
          ),
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(preferencesBox),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
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

      expect(find.byTooltip('Weekly view'), findsOneWidget);
      // The weekly row's own weekday initials.
      expect(find.text('M'), findsOneWidget);
      expect(find.text('S'), findsNWidgets(2));
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

  testWidgets(
    'tapping the switcher cycles Weekly → Monthly → Six-monthly → Weekly',
    (tester) async {
      await pumpList(tester, behaviors: [makeBehavior()]);

      expect(find.byTooltip('Weekly view'), findsOneWidget);

      await tapSwitcher(tester, find.byTooltip('Weekly view'));
      expect(find.byTooltip('Monthly view'), findsOneWidget);
      // The monthly grid shows numbered day cells, e.g. day 1.
      expect(find.text('1'), findsOneWidget);

      await tapSwitcher(tester, find.byTooltip('Monthly view'));
      expect(find.byTooltip('Six-month view'), findsOneWidget);

      await tapSwitcher(tester, find.byTooltip('Six-month view'));
      expect(find.byTooltip('Weekly view'), findsOneWidget);
    },
  );

  testWidgets(
    'the switcher setting persists across a rebuild (real preferences '
    'write, not just in-memory widget state)',
    (tester) async {
      await pumpList(tester, behaviors: [makeBehavior()]);

      await tapSwitcher(tester, find.byTooltip('Weekly view'));
      expect(find.byTooltip('Monthly view'), findsOneWidget);

      // Rebuild the whole screen from scratch — the setting must still
      // read back as Monthly, proving it was actually persisted via
      // PreferencesRepository rather than held only in local widget
      // state.
      await pumpList(tester, behaviors: [makeBehavior()]);
      expect(find.byTooltip('Monthly view'), findsOneWidget);
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
      // bottom bar's own "+" AppIconButton, which fills with the SAME
      // colorAccent for an unrelated reason (its own press-feedback
      // circle), producing a false positive.
      await pumpList(tester, behaviors: [behavior]);
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
}
