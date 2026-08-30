import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/task_detail_sheet.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_category.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

import '../../support/fake_notification_service.dart';

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

/// The Repeats switch specifically — the schedule screen now also shows a
/// Notifications switch, so a bare `find.byType(Switch)` matches two
/// widgets. The Repeats switch is the FIRST `Switch` in the tree (it sits
/// in the Date pane, above the separate Notifications pane below it).
Finder _repeatsSwitch() => find.byType(Switch).first;

// Same real-time-I/O-vs-pump-loop race as exit_confirmation_test.dart's own
// helper — see its comment and docs/ERROR_LOG.md.
Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
    // A real (not zero) delay: the series-editing save path awaits
    // several repository round-trips in sequence — prune future
    // instances, write the template, re-materialize, then refresh — and a
    // zero-duration drain only clears the first microtask hop. Without
    // this the box is closed in tearDown while `_refresh()` is still
    // reading from it ("Box has already been closed").
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
}

class _NoopPreventOverlappingTasksSetting
    extends PreventOverlappingTasksSetting {
  @override
  bool build() => false;
}

Future<GlobalKey<NavigatorState>> _pumpHost(
  WidgetTester tester, {
  required Box<Task> box,
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

Future<GlobalKey<NavigatorState>> _pumpEditScheduleForm(
  WidgetTester tester, {
  required Box<Task> box,
  required Task task,
}) async {
  final navigatorKey = await _pumpHost(tester, box: box);
  showEditScheduleSheet(navigatorKey.currentContext!, task: task);
  await tester.pumpAndSettle();
  return navigatorKey;
}

void main() {
  late Box<Task> box;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_edit_schedule_repeats');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Task>(
      'test_tasks_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await box.close();
  });

  testWidgets(
    'a plain (non-recurring) task shows the Repeats panel, enabled',
    (tester) async {
      final task = Task.create(
        title: 'Standup',
        scheduledAt: _daysFromToday(0),
        durationMinutes: 15,
        category: TaskCategory.work,
      );
      await tester.runAsync(() => box.put(task.id, task));

      await _pumpEditScheduleForm(tester, box: box, task: task);

      expect(find.text('Repeat'), findsOneWidget);
      final switchWidget = tester.widget<Switch>(_repeatsSwitch());
      expect(switchWidget.onChanged, isNotNull);
      expect(switchWidget.value, isFalse);
    },
  );

  testWidgets(
    'turning Repeats on and saving materializes a new series from this '
    'task — the day it was already scheduled on is pre-selected',
    (tester) async {
      final scheduledAt = _daysFromToday(0);
      final task = Task.create(
        title: 'Standup',
        scheduledAt: scheduledAt,
        durationMinutes: 15,
        category: TaskCategory.work,
      );
      await tester.runAsync(() => box.put(task.id, task));

      await _pumpEditScheduleForm(tester, box: box, task: task);

      await _tapAndSettle(tester, _repeatsSwitch());
      // The task's own weekday is pre-selected, so enabling Repeats with
      // no further taps already produces a real weekly rule. Derived from
      // the task's date rather than hardcoded, since the date is now
      // relative to today.
      const abbreviations = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      expect(
        find.text(abbreviations[scheduledAt.weekday - 1]),
        findsOneWidget,
      );

      await _tapAndSettle(tester, find.text('Save'));

      final saved = box.values.toList();
      final template = saved.firstWhere((t) => t.id == task.id);
      expect(template.isRecurring, isTrue);
      expect(template.isRecurrenceTemplate, isTrue);
      expect(template.recurrenceRule!.frequency, RecurrenceFrequency.weekly);
      expect(template.recurrenceRule!.daysOfWeek, [scheduledAt.weekday]);

      // A future instance should have been materialized in the same save,
      // sharing the template's recurrenceId but carrying no rule of its
      // own.
      final generatedInstances = saved.where(
        (t) => t.recurrenceId == template.recurrenceId && t.id != template.id,
      );
      expect(generatedInstances, isNotEmpty);
      for (final instance in generatedInstances) {
        expect(instance.recurrenceRule, isNull);
      }
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
        category: TaskCategory.work,
        recurrenceId: 'series-1',
        recurrenceRule: RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          daysOfWeek: [DateTime.monday, DateTime.wednesday],
        ),
      );
      await tester.runAsync(() => box.put(template.id, template));

      await _pumpEditScheduleForm(tester, box: box, task: template);

      final switchWidget = tester.widget<Switch>(_repeatsSwitch());
      expect(switchWidget.value, isTrue);
      expect(switchWidget.onChanged, isNotNull);

      final monChip = tester.widget<Text>(find.text('MON'));
      final wedChip = tester.widget<Text>(find.text('WED'));
      final tueChip = tester.widget<Text>(find.text('TUE'));
      // Selected chips render with the accent fill (see _DayChip) — spot
      // the pre-selection by color rather than a separate test hook.
      expect(monChip.style!.color, isNot(tueChip.style!.color));
      expect(monChip.style!.color, wedChip.style!.color);
    },
  );

  testWidgets(
    'changing an existing series\' days updates the TEMPLATE\'s rule and '
    'regenerates untouched future instances under it — a touched one is '
    'left alone',
    (tester) async {
      final template = Task.create(
        title: 'Standup',
        scheduledAt: _daysFromToday(0), // a Thursday
        durationMinutes: 15,
        category: TaskCategory.work,
        recurrenceId: 'series-1',
        recurrenceRule: RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          daysOfWeek: [DateTime.thursday],
        ),
      );
      // A future, untouched instance under the OLD rule — should be
      // pruned once the rule changes.
      final futureUntouched = Task.create(
        title: 'Standup',
        scheduledAt: _daysFromToday(7),
        durationMinutes: 15,
        category: TaskCategory.work,
        recurrenceId: 'series-1',
      );
      // A future instance the user already rescheduled — must survive the
      // prune even though it's still "future" and part of the same series.
      final futureTouched = Task.create(
        title: 'Standup (moved)',
        scheduledAt: _daysFromToday(14, hour: 10),
        durationMinutes: 15,
        category: TaskCategory.work,
        recurrenceId: 'series-1',
      )..originalScheduledAt = _daysFromToday(14);
      await tester.runAsync(() async {
        await box.put(template.id, template);
        await box.put(futureUntouched.id, futureUntouched);
        await box.put(futureTouched.id, futureTouched);
      });

      // Edited from the TEMPLATE instance itself here — the other test
      // below exercises editing from a non-template instance.
      await _pumpEditScheduleForm(tester, box: box, task: template);

      // Add Monday alongside the existing Thursday.
      await _tapAndSettle(tester, find.text('MON'));
      await _tapAndSettle(tester, find.text('Save'));

      final saved = box.values.toList();
      final savedTemplate = saved.firstWhere((t) => t.id == template.id);
      expect(
        savedTemplate.recurrenceRule!.daysOfWeek,
        containsAll([DateTime.monday, DateTime.thursday]),
      );

      expect(saved.any((t) => t.id == futureUntouched.id), isFalse);
      expect(saved.any((t) => t.id == futureTouched.id), isTrue);

      // Fresh instances regenerated under the new rule.
      final regenerated = saved.where(
        (t) =>
            t.recurrenceId == 'series-1' &&
            t.id != template.id &&
            t.id != futureTouched.id,
      );
      expect(regenerated, isNotEmpty);
    },
  );

  testWidgets(
    'editing days from a NON-template instance still updates the shared '
    'template',
    (tester) async {
      final template = Task.create(
        title: 'Standup',
        scheduledAt: _daysFromToday(0),
        durationMinutes: 15,
        category: TaskCategory.work,
        recurrenceId: 'series-1',
        recurrenceRule: RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          daysOfWeek: [DateTime.thursday],
        ),
      );
      final instance = Task.create(
        title: 'Standup',
        scheduledAt: _daysFromToday(7),
        durationMinutes: 15,
        category: TaskCategory.work,
        recurrenceId: 'series-1',
      );
      await tester.runAsync(() async {
        await box.put(template.id, template);
        await box.put(instance.id, instance);
      });

      await _pumpEditScheduleForm(tester, box: box, task: instance);
      await _tapAndSettle(tester, find.text('MON'));
      await _tapAndSettle(tester, find.text('Save'));

      final savedTemplate = box.get(template.id)!;
      expect(
        savedTemplate.recurrenceRule!.daysOfWeek,
        containsAll([DateTime.monday, DateTime.thursday]),
      );
    },
  );

  testWidgets(
    'turning Repeats off on an existing series detaches the template and '
    'prunes untouched future instances — a completed one survives',
    (tester) async {
      final template = Task.create(
        title: 'Standup',
        scheduledAt: _daysFromToday(0),
        durationMinutes: 15,
        category: TaskCategory.work,
        recurrenceId: 'series-1',
        recurrenceRule: RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          daysOfWeek: [DateTime.thursday],
        ),
      );
      final futureUntouched = Task.create(
        title: 'Standup',
        scheduledAt: _daysFromToday(7),
        durationMinutes: 15,
        category: TaskCategory.work,
        recurrenceId: 'series-1',
      );
      final futureCompleted = Task.create(
        title: 'Standup',
        scheduledAt: _daysFromToday(14),
        durationMinutes: 15,
        category: TaskCategory.work,
        recurrenceId: 'series-1',
      )..status = TaskStatus.completed;
      await tester.runAsync(() async {
        await box.put(template.id, template);
        await box.put(futureUntouched.id, futureUntouched);
        await box.put(futureCompleted.id, futureCompleted);
      });

      await _pumpEditScheduleForm(tester, box: box, task: template);
      await _tapAndSettle(tester, _repeatsSwitch());
      await _tapAndSettle(tester, find.text('Save'));

      final saved = box.values.toList();
      final savedTemplate = saved.firstWhere((t) => t.id == template.id);
      expect(savedTemplate.isRecurring, isFalse);
      expect(savedTemplate.recurrenceRule, isNull);

      expect(saved.any((t) => t.id == futureUntouched.id), isFalse);
      final survivingCompleted = saved.firstWhere(
        (t) => t.id == futureCompleted.id,
      );
      // The completed instance itself keeps ITS OWN recurrenceId — only
      // the template detaches (confirmed via AskUserQuestion); a past
      // action on one occurrence still shows it was part of a series.
      expect(survivingCompleted.recurrenceId, 'series-1');
    },
  );
}
