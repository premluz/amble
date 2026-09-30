import 'package:amble/features/task_detail/task_sheet_form.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/models/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Task plain() => Task(
    id: 'a',
    title: 'Read',
    scheduledAt: DateTime(2026, 9, 30, 9, 15),
    durationMinutes: 30,
    categoryId: BuiltInCategoryIds.general,
  );

  test('seeds an edit from the task and starts unchanged', () {
    final task = plain();
    final form = TaskSheetForm(allTasks: [task], task: task);
    addTearDown(form.dispose);
    expect(form.title.text, 'Read');
    expect(form.scheduledAt, DateTime(2026, 9, 30, 9, 15));
    expect(form.durationMinutes, 30);
    expect(form.canSave, isTrue);
    expect(form.hasChanges, isFalse);
    form.durationMinutes = 45;
    expect(form.hasChanges, isTrue);
  });

  test('a fresh create needs a name, a time and a duration to save', () {
    final form = TaskSheetForm(allTasks: const [], date: DateTime(2026, 9, 30));
    addTearDown(form.dispose);
    expect(form.canSave, isFalse);
    form.title.text = 'Walk';
    form.time = const TimeOfDay(hour: 8, minute: 0);
    expect(form.canSave, isFalse);
    form.durationMinutes = 15;
    expect(form.canSave, isTrue);
  });

  test('a duplicate is a plain new task even from a recurring one', () {
    final template = Task(
      id: 't',
      title: 'Gym',
      scheduledAt: DateTime(2026, 9, 28, 7),
      durationMinutes: 60,
      recurrenceId: 't',
      recurrenceRule: RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        daysOfWeek: const [1, 3],
      ),
    );
    final form = TaskSheetForm(allTasks: [template], duplicateFrom: template);
    addTearDown(form.dispose);
    expect(form.task, isNull);
    expect(form.repeats, isFalse);
    expect(form.title.text, 'Gym');
  });

  test('editing a series seeds its real days, and offers the future choice '
      'only once its start or length moves', () {
    final template = Task(
      id: 't',
      title: 'Gym',
      scheduledAt: DateTime(2026, 9, 28, 7),
      durationMinutes: 60,
      recurrenceId: 't',
      recurrenceRule: RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        daysOfWeek: const [1, 3],
      ),
    );
    final form = TaskSheetForm(allTasks: [template], task: template);
    addTearDown(form.dispose);
    expect(form.repeats, isTrue);
    expect(form.selectedDays, {1, 3});
    expect(form.showFutureInstancesChoice, isFalse);
    form.time = const TimeOfDay(hour: 8, minute: 0);
    expect(form.showFutureInstancesChoice, isTrue);
  });

  test('days map to daily for all seven, weekly otherwise', () {
    expect(
      recurrenceRuleFromDays({1, 2, 3, 4, 5, 6, 7}).frequency,
      RecurrenceFrequency.daily,
    );
    final weekly = recurrenceRuleFromDays({5, 1});
    expect(weekly.frequency, RecurrenceFrequency.weekly);
    expect(weekly.daysOfWeek, [1, 5]);
    expect(daysFromRecurrenceRule(weekly), {1, 5});
  });
}
