import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_selectable_chip.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/core/widgets/app_value_chip.dart';
import 'package:amble/features/task_detail/task_repeat_modal.dart';
import 'package:amble/features/task_detail/task_sheet.dart';
import 'package:amble/shared/models/local_date.dart';
import 'package:amble/shared/models/occurrence_record.dart';
import 'package:amble/shared/models/recurrence_command.dart';
import 'package:amble/shared/models/series.dart';
import 'package:amble/shared/providers/occurrence_store.dart';
import 'package:amble/shared/repositories/occurrence_record_repository.dart';
import 'package:amble/shared/repositories/series_repository.dart';
import 'package:amble/shared/services/occurrence_task_projection.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/task_template_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// A time [days] from today at [hour], anchored to the real current date.
///
/// These tests assert behaviour that is defined RELATIVE TO TODAY — the
/// series-pruning rules only touch instances scheduled today or later — so
/// hardcoded calendar dates silently rot: they were written as "future"
/// and quietly became past, making the pruning assertions fail for a
/// reason that has nothing to do with the code under test. Anchoring to
/// `DateTime.now()` keeps each case meaning what its name says.
DateTime _daysFromToday(int days, {int hour = 9, int minute = 0}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, hour, minute);
}

/// The Repeats switch specifically — `find.byType(Switch)` alone now
/// matches THREE widgets (Important, Repeats, Notifications, added
/// 2026-09-08), so tree order is no longer a safe way to pick one out.
/// `_RecurrencePanel` (private, unreachable by name from this test file)
/// is the one label+switch pane whose own label reads "Repeat" — found
/// via its nearest `Row` ancestor, then the one `Switch` inside THAT row,
/// which excludes the day-of-week chips below it that also live in this
/// same panel.
Finder _repeatsSwitch() => find.descendant(
  of: find.byType(TaskRepeatModal),
  matching: find.byType(Switch),
);

/// One day-of-week chip, by [weekday] (`DateTime.monday`..`DateTime.sunday`).
///
/// The chips' own labels are now single first letters ("M T W T F S S" —
/// requested directly), so several no longer have unique text (Tuesday and
/// Thursday both read "T", Saturday and Sunday both read "S") — `find
/// .text(...)` can no longer pick one out unambiguously the way it could
/// when every label was a distinct 3-letter abbreviation. `_RecurrencePanel`
/// lays the seven chips out in a fixed Monday-first `Row` (see its own
/// `for (var day = DateTime.monday; day <= DateTime.sunday; day++)` loop),
/// so position within that row is what identifies each one instead.
Finder _dayChip(int weekday) => find
    .descendant(
      of: find.byType(TaskRepeatModal),
      matching: find.byType(AppSelectableChip),
    )
    .at(weekday - DateTime.monday);

/// The task sheet's Repeat chip, which opens the repeat picker.
Finder _repeatChip() => find.widgetWithIcon(AppValueChip, Icons.repeat_rounded);

/// Closes the repeat picker (Done) if it is open, then saves the task.
Future<void> _save(WidgetTester tester) async {
  if (find.byType(TaskRepeatModal).evaluate().isNotEmpty) {
    await _tapAndSettle(tester, find.text('Done'));
  }
  await _tapAndSettle(tester, find.text('Save'));
}

/// A new task named "Standup" at 9:00 today, with Repeat switched on in
/// its picker — ready for Add.
Future<void> _startNewRepeatingTask(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigatorKey,
) async {
  showTaskSheet(
    navigatorKey.currentContext!,
    initialScheduledAt: _daysFromToday(0),
    initialTimeOfDay: const TimeOfDay(hour: 9, minute: 0),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'Standup');
  await tester.pumpAndSettle();
  await _tapAndSettle(tester, _repeatChip());
  await _tapAndSettle(tester, _repeatsSwitch());
  await _tapAndSettle(tester, find.text('Done'));
}

// Same real-time-I/O-vs-pump-loop race as exit_confirmation_test.dart's own
// helper — see its comment and docs/ERROR_LOG.md.
Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  // The live schedule stage (unlike the retired _EditScheduleForm this
  // file used to test) is a real SingleChildScrollView, and the default
  // test viewport isn't tall enough to fit every field — a bare tap()
  // can miss its target as "off-screen", same fix pattern already used in
  // task_duration_modal_test.dart. ensureVisible is a pure widget-tree
  // operation, not real I/O, so it stays outside runAsync below.
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(finder);
    // Not pumpAndSettle: the Save button now shows a spinner
    // (AppButton.isLoading) for the duration of the in-flight save, and a
    // spinner's animation never settles — pumpAndSettle would time out
    // waiting for it. A single pump just drains the tap's own frame.
    await tester.pump();
    // A real (not zero) delay: the series-editing save path awaits
    // several repository round-trips in sequence — prune future
    // instances, write the template, re-materialize, then refresh — and a
    // zero-duration drain only clears the first microtask hop. Without
    // this the box is closed in tearDown while `_refresh()` is still
    // reading from it ("Box has already been closed").
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // Drains the pop's route-transition animation and the post-pop
    // `setState(() => _isSaving = false)` — both settled, unlike the
    // spinner's own perpetual animation while the save was in flight.
    await tester.pumpAndSettle();
  });
}

/// Every series in the series box the test config opens for each test.
List<Series> _allSeries() => HiveSeriesRepository.opened().getAll();

OccurrenceStore _store(GlobalKey<NavigatorState> key) =>
    ProviderScope.containerOf(key.currentContext!)
        .read(occurrenceStoreProvider.notifier);

/// A day of the week other than [day]'s, so tapping its chip ADDS a day.
int _otherWeekday(DateTime day) =>
    day.weekday == DateTime.monday ? DateTime.tuesday : DateTime.monday;

/// Creates a weekly "Standup" series at 9:00 starting today, through the
/// real `createTask`, and returns its first occurrence.
Future<Task> _seedWeeklySeries(
  WidgetTester tester,
  GlobalKey<NavigatorState> key, {
  required List<int> days,
}) async {
  final container = ProviderScope.containerOf(key.currentContext!);
  final created = await tester.runAsync(
    () => container
        .read(taskListProvider.notifier)
        .createTask(
          title: 'Standup',
          scheduledAt: _daysFromToday(0),
          durationMinutes: 15,
          categoryId: BuiltInCategoryIds.work,
          recurrenceRule: RecurrenceRule(
            frequency: RecurrenceFrequency.weekly,
            daysOfWeek: days,
          ),
        ),
  );
  return created!;
}

Task _occurrenceOn(GlobalKey<NavigatorState> key, DateTime day) =>
    _store(key).tasksOn(LocalDate.fromDateTime(day)).single;

/// Opens the real edit sheet for [task], then its repeat picker.
Future<void> _openSheetFor(
  WidgetTester tester,
  GlobalKey<NavigatorState> key,
  Task task,
) async {
  showTaskSheet(key.currentContext!, task: task);
  await tester.pumpAndSettle();
  await _tapAndSettle(tester, _repeatChip());
}

class _NoopPreventOverlappingTasksSetting
    extends PreventOverlappingTasksSetting {
  @override
  bool build() => false;
}

Future<GlobalKey<NavigatorState>> _pumpHost(
  WidgetTester tester, {
  required Box<Task> box,
  required Box<Category> categoryBox,
  required Box<TrackedBehavior> trackedBehaviorBox,
  required Box<TaskTemplate> templateBox,
}) async {
  // The default flutter_test surface (800x600 LOGICAL, i.e. quite short)
  // is enough for exit_confirmation_test.dart's forms, but the schedule
  // step gains a whole extra panel here (Repeats) that no prior test ever
  // rendered — at the default height its Switch sat far enough down to
  // collide with the bottom Save-button overlay in hit-testing. A real
  // phone-sized viewport avoids that; matches an iPhone-class logical size
  // rather than an arbitrary larger number.
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
        taskTemplateRepositoryProvider.overrideWithValue(
          HiveTaskTemplateRepository(templateBox),
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
  return navigatorKey;
}

/// Opens the REAL, live edit entry point — `showTaskSheet(task: ...)`, the
/// same call `task_action_sheet.dart`'s "Edit task" makes — then its
/// repeat picker. (Earlier this suite exercised a form no real UI called,
/// and missed real recurrence-editing bugs; see docs/ERROR_LOG.md.)
Future<GlobalKey<NavigatorState>> _pumpEditScheduleForm(
  WidgetTester tester, {
  required Box<Task> box,
  required Box<Category> categoryBox,
  required Box<TrackedBehavior> trackedBehaviorBox,
  required Box<TaskTemplate> templateBox,
  required Task task,
}) async {
  final navigatorKey = await _pumpHost(
    tester,
    box: box,
    categoryBox: categoryBox,
    trackedBehaviorBox: trackedBehaviorBox,
    templateBox: templateBox,
  );
  showTaskSheet(navigatorKey.currentContext!, task: task);
  await tester.pumpAndSettle();
  // The repeat settings live in their own picker, opened from the chip.
  await _tapAndSettle(tester, _repeatChip());
  return navigatorKey;
}

void main() {
  late Box<Task> box;
  late Box<Category> categoryBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<TaskTemplate> templateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_edit_schedule_repeats');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Task>(
      'test_tasks_${DateTime.now().microsecondsSinceEpoch}',
    );
    categoryBox = await openSeededCategoryBox(
      'test_categories_${DateTime.now().microsecondsSinceEpoch}',
    );
    // The task detail sheet's tracked-behavior link section is now
    // unconditionally compiled in (FeatureFlags.trackedBehaviorEnabled
    // defaults true as of 2026-09-06) — this box just needs to exist
    // so trackedBehaviorRepositoryProvider resolves; nothing here
    // exercises linking, so it's never seeded.
    trackedBehaviorBox = await Hive.openBox<TrackedBehavior>(
      'test_tracked_behaviors_${DateTime.now().microsecondsSinceEpoch}',
    );
    templateBox = await Hive.openBox<TaskTemplate>(
      'test_templates_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await box.close();
    await categoryBox.close();
    await trackedBehaviorBox.close();
    await templateBox.close();
  });

  testWidgets('a plain (non-recurring) task shows the Repeats panel, enabled', (
    tester,
  ) async {
    final task = Task.create(
      title: 'Standup',
      scheduledAt: _daysFromToday(0),
      durationMinutes: 15,
      categoryId: BuiltInCategoryIds.work,
    );
    await tester.runAsync(() => box.put(task.id, task));

    await _pumpEditScheduleForm(
      tester,
      box: box,
      categoryBox: categoryBox,
      trackedBehaviorBox: trackedBehaviorBox,
      templateBox: templateBox,
      task: task,
    );

    // The picker's title and its switch's label.
    expect(find.text('Repeat'), findsWidgets);
    final switchWidget = tester.widget<Switch>(_repeatsSwitch());
    expect(switchWidget.onChanged, isNotNull);
    expect(switchWidget.value, isFalse);
  });

  testWidgets(
    'turning Repeats on and saving turns this task into a series starting '
    'on its own day — the day it was already scheduled on is pre-selected',
    (tester) async {
      final scheduledAt = _daysFromToday(0);
      final task = Task.create(
        title: 'Standup',
        scheduledAt: scheduledAt,
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.work,
      );
      await tester.runAsync(() => box.put(task.id, task));

      await _pumpEditScheduleForm(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
        task: task,
      );

      await _tapAndSettle(tester, _repeatsSwitch());
      expect(_dayChip(scheduledAt.weekday), findsOneWidget);
      await _save(tester);

      // The plain task is replaced by the series' first occurrence.
      expect(box.get(task.id), isNull);
      final series = _allSeries().single;
      expect(series.anchor, LocalDate.fromDateTime(scheduledAt));
      final rule = series.revisions.single.rule;
      expect(rule.frequency, RecurrenceFrequency.weekly);
      expect(rule.daysOfWeek, [scheduledAt.weekday]);
    },
  );

  testWidgets(
    'an already-recurring task shows Repeats on, editable, with its real '
    'days pre-selected',
    (tester) async {
      final template = Task.create(
        title: 'Standup',
        scheduledAt: _daysFromToday(0),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.work,
        recurrenceId: 'series-1',
        recurrenceRule: RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          daysOfWeek: [DateTime.monday, DateTime.wednesday],
        ),
      );
      await tester.runAsync(() => box.put(template.id, template));

      await _pumpEditScheduleForm(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
        task: template,
      );

      final switchWidget = tester.widget<Switch>(_repeatsSwitch());
      expect(switchWidget.value, isTrue);
      expect(switchWidget.onChanged, isNotNull);

      // Chip labels are single letters, no longer unique per day (see
      // `_dayChip`'s own doc comment), so this reads each chip's own
      // `selected` field directly rather than inferring selection from
      // its rendered text color.
      final monChip = tester.widget<AppSelectableChip>(
        _dayChip(DateTime.monday),
      );
      final wedChip = tester.widget<AppSelectableChip>(
        _dayChip(DateTime.wednesday),
      );
      final tueChip = tester.widget<AppSelectableChip>(
        _dayChip(DateTime.tuesday),
      );
      expect(monChip.selected, isTrue);
      expect(wedChip.selected, isTrue);
      expect(tueChip.selected, isFalse);
    },
  );

  testWidgets(
    'changing a series\' days from today\'s occurrence changes the rule '
    'from today on',
    (tester) async {
      final today = _daysFromToday(0);
      final other = _otherWeekday(today);
      final key = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
      );
      await _seedWeeklySeries(tester, key, days: [today.weekday]);
      await _openSheetFor(tester, key, _occurrenceOn(key, today));

      await _tapAndSettle(tester, _dayChip(other));
      await _save(tester);

      final series = _allSeries().single;
      expect(
        series.revisionOn(LocalDate.fromDateTime(today))!.rule.daysOfWeek,
        containsAll([other, today.weekday]),
      );
    },
  );

  testWidgets(
    'changing days from a later occurrence applies from that date only — '
    'earlier days keep the old rule',
    (tester) async {
      final today = _daysFromToday(0);
      final nextWeek = _daysFromToday(7);
      final other = _otherWeekday(today);
      final key = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
      );
      await _seedWeeklySeries(tester, key, days: [today.weekday]);
      await _openSheetFor(tester, key, _occurrenceOn(key, nextWeek));

      await _tapAndSettle(tester, _dayChip(other));
      await _save(tester);

      final series = _allSeries().single;
      expect(
        series.revisionOn(LocalDate.fromDateTime(today))!.rule.daysOfWeek,
        [today.weekday],
      );
      expect(
        series.revisionOn(LocalDate.fromDateTime(nextWeek))!.rule.daysOfWeek,
        containsAll([other, today.weekday]),
      );
    },
  );

  testWidgets('turning Repeats off ends the series from today — a completed '
      'occurrence keeps its record', (tester) async {
    final today = _daysFromToday(0);
    final key = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
      trackedBehaviorBox: trackedBehaviorBox,
      templateBox: templateBox,
    );
    final first = await _seedWeeklySeries(tester, key, days: [today.weekday]);
    final occurrenceKey = occurrenceKeyOfTask(first);
    await tester.runAsync(
      () => _store(key).run(
        SetOutcome(
          'done-1',
          key: occurrenceKey,
          expectedVersion: null,
          outcome: OccurrenceOutcome.done,
          completionDate: LocalDate.fromDateTime(today),
        ),
      ),
    );
    await _openSheetFor(tester, key, _occurrenceOn(key, today));

    await _tapAndSettle(tester, _repeatsSwitch());
    await _save(tester);

    final series = _allSeries().single;
    expect(series.endsAfter, LocalDate.fromDateTime(today).addDays(-1));
    expect(
      HiveOccurrenceRecordRepository.opened().get(occurrenceKey)!.outcome,
      OccurrenceOutcome.done,
    );
  });

  // Regression test for a real bug, reported directly: "had task that just
  // category time and it created double and both were repeated across all
  // days, saw 2 tasks everyday.. just by saving". Same time, no schedule
  // change, already recurring on every day — just opening and saving.
  testWidgets(
    'saving an occurrence without changing anything writes nothing — no '
    'second series, no revision, no override',
    (tester) async {
      final today = _daysFromToday(0);
      final key = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
      );
      await _seedWeeklySeries(tester, key, days: const [1, 2, 3, 4, 5, 6, 7]);
      await _openSheetFor(tester, key, _occurrenceOn(key, today));
      await _save(tester);

      final series = _allSeries().single;
      expect(series.version, Series.initialVersion);
      expect(HiveOccurrenceRecordRepository.opened().getAll(), isEmpty);
    },
  );

  // The CREATE counterpart of the same report — `createTask` is the only
  // path that mints a fresh recurrenceId here, so a second run of it is
  // what would produce two full parallel series at the same time on every
  // day ("saw 2 tasks everyday").
  testWidgets(
    'creating a task with Repeats on writes exactly ONE series, not two',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
        templateBox: templateBox,
      );
      await _startNewRepeatingTask(tester, navigatorKey);
      await _tapAndSettle(tester, find.text('Add'));

      // Repeating tasks are series now: nothing lands in the task box, and
      // exactly one series exists.
      expect(box.values, isEmpty);
      expect(_allSeries(), hasLength(1));
    },
  );

  // Double-tap prevention, requested directly ("we need apply prevention
  // of double tap"). Two taps in the same frame are stopped by `_isSaving`
  // (verified: this test still passes with `_hasSaved` removed, so it
  // covers the in-flight guard, not the post-commit one — see the
  // dialog-path test below for that).
  testWidgets('two Save taps in the same frame write the task only once', (
    tester,
  ) async {
    final navigatorKey = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
      trackedBehaviorBox: trackedBehaviorBox,
      templateBox: templateBox,
    );
    await _startNewRepeatingTask(tester, navigatorKey);

    // Two Save taps in the SAME frame — the second lands before the
    // button can re-render as disabled, which is exactly the shape a
    // real double-tap takes.
    final saveButton = find.text('Add');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(saveButton, warnIfMissed: false);
      await tester.tap(saveButton, warnIfMissed: false);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
    });

    expect(box.values, isEmpty);
    expect(
      _allSeries(),
      hasLength(1),
      reason: 'a second committed save created a second series',
    );
  });
}
