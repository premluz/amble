import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/task_action_sheet.dart';
import 'package:amble/shared/models/local_date.dart';
import 'package:amble/shared/models/series.dart';
import 'package:amble/shared/models/series_revision.dart';
import 'package:amble/shared/providers/occurrence_store.dart';
import 'package:amble/shared/repositories/series_repository.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

DateTime _daysFromToday(int days, {int hour = 9}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, hour);
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
}

class _NoopPreventOverlappingTasksSetting
    extends PreventOverlappingTasksSetting {
  @override
  bool build() => false;
}

Future<void> _pumpActionSheet(
  WidgetTester tester, {
  required Box<Task> box,
  required Box<Category> categoryBox,
  required Box<TrackedBehavior> trackedBehaviorBox,
  required Task task,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
        categoryRepositoryProvider.overrideWithValue(
          HiveCategoryRepository(categoryBox),
        ),
        trackedBehaviorRepositoryProvider.overrideWithValue(
          HiveTrackedBehaviorRepository(trackedBehaviorBox),
        ),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        preventOverlappingTasksSettingProvider.overrideWith(
          () => _NoopPreventOverlappingTasksSetting(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  // `navigatorKey.currentContext` is the Navigator's OWN element — sitting
  // structurally ABOVE the Overlay that same Navigator builds internally,
  // not a descendant of it. `Overlay.of(context, rootOverlay: true)`
  // (which `removeTask`'s own undo toast now calls) walks UP from
  // whatever context it's given, so starting from the Navigator's own
  // context never finds that Overlay — "No Overlay widget found," even
  // though one genuinely exists a level below. Every real call site in
  // app code passes an ordinary descendant widget's context instead (see
  // `inbox_screen.dart`'s own `showQuickCaptureSheet` calls); this test
  // now does the same via the mounted Scaffold's own element.
  final scaffoldContext = tester.element(find.byType(Scaffold));
  showTaskActionSheet(scaffoldContext, task: task);
  await tester.pumpAndSettle();
}

/// A weekly "Standup" series at 9:00 starting [today] on [today]'s
/// weekday, stored directly in the series box the test config opens.
/// Returns its first occurrence shown as a task.
Future<Task> _seedWeeklySeries(WidgetTester tester, LocalDate today) async {
  final series = Series.create(
    firstRevision: SeriesRevision(
      effectiveFrom: today,
      rule: RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        daysOfWeek: [today.weekday],
      ),
      startMinutes: 9 * 60,
      durationMinutes: 15,
      defaults: const SeriesDefaults(
        title: 'Standup',
        categoryId: BuiltInCategoryIds.work,
      ),
    ),
    now: DateTime.now(),
  );
  await tester.runAsync(() => HiveSeriesRepository.opened().save(series));
  return _occurrencesOn(today).single;
}

/// Series occurrences on [day], read fresh from storage.
List<Task> _occurrencesOn(LocalDate day) {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container.read(occurrenceStoreProvider.notifier).tasksOn(day);
}

void main() {
  late Box<Task> box;
  late Box<Category> categoryBox;
  late Box<TrackedBehavior> trackedBehaviorBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_action_sheet_remove');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Task>(
      'test_tasks_${DateTime.now().microsecondsSinceEpoch}',
    );
    categoryBox = await openSeededCategoryBox(
      'test_categories_${DateTime.now().microsecondsSinceEpoch}',
    );
    // The create/edit flows now render the tracked-behavior picker (it was
    // previously only on "Edit details"), so they watch
    // `trackedBehaviorListProvider` and this box must exist or the whole
    // stage fails to build. Never seeded — nothing here exercises
    // linking. Same fixture `create_flow_initial_modal_test.dart` already
    // established when the feature flag first defaulted on.
    trackedBehaviorBox = await Hive.openBox<TrackedBehavior>(
      'test_tracked_behaviors_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await box.close();
    await categoryBox.close();
    await trackedBehaviorBox.close();
  });

  // Requested directly: "let's build undo change mechanism." Tapping
  // Remove now shows an AppUndoToast; tapping ITS "Undo" restores the
  // exact task (via Task.toJson/fromJson, the same round-trip export/
  // import already proves correct) rather than leaving it deleted.
  testWidgets('Remove on a PLAIN task shows an Undo toast, and Undo '
      'restores it', (tester) async {
    final task = Task.create(
      title: 'Standup',
      scheduledAt: _daysFromToday(0),
      durationMinutes: 15,
      categoryId: BuiltInCategoryIds.work,
    );
    await tester.runAsync(() => box.put(task.id, task));

    await _pumpActionSheet(
      tester,
      box: box,
      categoryBox: categoryBox,
      trackedBehaviorBox: trackedBehaviorBox,
      task: task,
    );
    await _tapAndSettle(tester, find.text('Remove'));
    // `_remove`'s own `await removeTask(...)` inserts the toast's
    // OverlayEntry only once the delete's own await resolves — a moment
    // after `_tapAndSettle`'s `pumpAndSettle()` already decided nothing
    // else was scheduled and returned. One more `pump()` gives that
    // late-inserted entry an actual frame to paint in before this test
    // looks for it.
    await tester.pump();

    expect(box.get(task.id), isNull);
    expect(find.text('Undo'), findsOneWidget);

    await _tapAndSettle(tester, find.text('Undo'));

    final restored = box.get(task.id);
    expect(restored, isNotNull);
    expect(restored!.title, 'Standup');
    expect(restored.durationMinutes, 15);
  });

  testWidgets('Remove on a RECURRING task opens the scope sheet', (
    tester,
  ) async {
    final task = Task.create(
      title: 'Standup',
      scheduledAt: _daysFromToday(0),
      durationMinutes: 15,
      categoryId: BuiltInCategoryIds.work,
      recurrenceId: 'series-1',
      recurrenceRule: RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        daysOfWeek: [DateTime.monday],
      ),
    );
    await tester.runAsync(() => box.put(task.id, task));

    await _pumpActionSheet(
      tester,
      box: box,
      categoryBox: categoryBox,
      trackedBehaviorBox: trackedBehaviorBox,
      task: task,
    );
    await _tapAndSettle(tester, find.text('Remove'));

    expect(
      find.text('This task repeats'),
      findsOneWidget,
      reason: 'scope sheet should appear for a recurring task',
    );
  });

  testWidgets('"Remove this occurrence" cancels only that occurrence, and '
      'Undo brings it back', (tester) async {
    final today = LocalDate.fromDateTime(_daysFromToday(0));
    final occurrence = await _seedWeeklySeries(tester, today);

    await _pumpActionSheet(
      tester,
      box: box,
      categoryBox: categoryBox,
      trackedBehaviorBox: trackedBehaviorBox,
      task: occurrence,
    );
    await _tapAndSettle(tester, find.text('Remove'));
    await _tapAndSettle(tester, find.text('Remove this occurrence'));
    // See the earlier "shows an Undo toast" test's own comment: the
    // toast's OverlayEntry is inserted only once `removeTask`'s own
    // await resolves, a moment after `pumpAndSettle()` already returned.
    await tester.pump();

    expect(_occurrencesOn(today), isEmpty);
    expect(
      _occurrencesOn(today.addDays(7)),
      hasLength(1),
      reason: 'the rest of the series must survive',
    );

    await _tapAndSettle(tester, find.text('Undo'));
    expect(_occurrencesOn(today), hasLength(1));
  });

  testWidgets('"Remove all occurrences" ends the series from today, and '
      'Undo brings it back', (tester) async {
    final today = LocalDate.fromDateTime(_daysFromToday(0));
    final occurrence = await _seedWeeklySeries(tester, today);

    await _pumpActionSheet(
      tester,
      box: box,
      categoryBox: categoryBox,
      trackedBehaviorBox: trackedBehaviorBox,
      task: occurrence,
    );
    await _tapAndSettle(tester, find.text('Remove'));
    await _tapAndSettle(tester, find.text('Remove all occurrences'));
    // See the earlier "shows an Undo toast" test's own comment.
    await tester.pump();

    expect(_occurrencesOn(today), isEmpty);
    expect(_occurrencesOn(today.addDays(7)), isEmpty);
    expect(
      HiveSeriesRepository.opened().getAll().single.endsAfter,
      today.addDays(-1),
    );

    expect(find.text('Undo'), findsOneWidget);
    await _tapAndSettle(tester, find.text('Undo'));

    expect(_occurrencesOn(today), hasLength(1));
    expect(_occurrencesOn(today.addDays(7)), hasLength(1));
  });

  testWidgets(
    'Duplicate opens a pre-filled create screen WITHOUT persisting a copy '
    'until Save is actually tapped',
    (tester) async {
      // Fixed directly: Duplicate used to call TaskList.duplicateTask
      // immediately on tap — a real repository write — so closing the
      // follow-up screen without confirming still left an unwanted
      // duplicate behind. It now opens the same create/edit screen
      // pre-filled from the source task, and nothing is written until the
      // user actually saves. See docs/PROGRESS_LOG.md.
      final task = Task.create(
        title: 'Standup',
        scheduledAt: _daysFromToday(0),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.work,
      );
      await tester.runAsync(() => box.put(task.id, task));

      await _pumpActionSheet(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        task: task,
      );
      await _tapAndSettle(tester, find.text('Duplicate'));

      // Pre-filled with the source task's title, as a new task (Add).
      expect(find.text('Standup'), findsWidgets);
      expect(find.text('New task'), findsNothing);
      expect(find.text('Add'), findsOneWidget);
      // Still exactly ONE task — nothing persisted merely by opening
      // the screen.
      expect(box.values.length, 1);
    },
  );

  testWidgets('Edit task opens the edit screen, pre-filled', (tester) async {
    // "Edit details" was consolidated into a single "Edit task" entry —
    // see docs/PROGRESS_LOG.md — that opens the same screen Create uses,
    // pre-populated, with every field editable in one place.
    final task = Task.create(
      title: 'Standup',
      scheduledAt: _daysFromToday(0),
      durationMinutes: 15,
      categoryId: BuiltInCategoryIds.work,
    );
    await tester.runAsync(() => box.put(task.id, task));

    await _pumpActionSheet(
      tester,
      box: box,
      categoryBox: categoryBox,
      trackedBehaviorBox: trackedBehaviorBox,
      task: task,
    );
    await _tapAndSettle(tester, find.text('Edit task'));

    expect(find.text('Standup'), findsWidgets);
    expect(find.text('Save'), findsOneWidget);
  });
}
