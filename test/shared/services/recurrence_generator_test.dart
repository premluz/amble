import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/services/recurrence_generator.dart';

/// A template anchored at a known instant, so window maths is deterministic
/// rather than dependent on the day the suite happens to run.
Task _template({
  required DateTime scheduledAt,
  required RecurrenceRule rule,
  String seriesId = 'series-1',
  String title = 'Repeating task',
}) {
  return Task.create(
    title: title,
    scheduledAt: scheduledAt,
    durationMinutes: 30,
    categoryId: BuiltInCategoryIds.health,
    recurrenceId: seriesId,
    recurrenceRule: rule,
  );
}

void main() {
  // Monday.
  final anchor = DateTime(2026, 8, 3, 9, 0);
  final now = anchor;

  group('daily recurrence', () {
    test('materializes one instance per day across the window', () {
      final template = _template(
        scheduledAt: anchor,
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );

      final generated = generateRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 2,
      );

      // 15 days inclusive of the anchor; the anchor itself is already
      // materialized as the template, so 14 are generated.
      expect(generated, hasLength(14));
      expect(generated.first.scheduledAt, DateTime(2026, 8, 4, 9, 0));
      expect(generated.last.scheduledAt, DateTime(2026, 8, 17, 9, 0));
    });

    test('interval skips days — every 3 days', () {
      final template = _template(
        scheduledAt: anchor,
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily, interval: 3),
      );

      final generated = generateRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 2,
      );

      expect(generated.map((t) => t.scheduledAt), [
        DateTime(2026, 8, 6, 9, 0),
        DateTime(2026, 8, 9, 9, 0),
        DateTime(2026, 8, 12, 9, 0),
        DateTime(2026, 8, 15, 9, 0),
      ]);
    });

    test('every instance keeps the anchor time of day', () {
      final template = _template(
        scheduledAt: DateTime(2026, 8, 3, 7, 45),
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );

      final generated = generateRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 1,
      );

      for (final task in generated) {
        expect(task.scheduledAt!.hour, 7);
        expect(task.scheduledAt!.minute, 45);
      }
    });
  });

  group('weekly recurrence', () {
    test('null daysOfWeek repeats on the anchor weekday', () {
      final template = _template(
        scheduledAt: anchor,
        rule: RecurrenceRule(frequency: RecurrenceFrequency.weekly),
      );

      final generated = generateRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 4,
      );

      expect(generated.map((t) => t.scheduledAt), [
        DateTime(2026, 8, 10, 9, 0),
        DateTime(2026, 8, 17, 9, 0),
        DateTime(2026, 8, 24, 9, 0),
        DateTime(2026, 8, 31, 9, 0),
      ]);
      for (final task in generated) {
        expect(task.scheduledAt!.weekday, DateTime.monday);
      }
    });

    test('daysOfWeek produces several instances per week', () {
      final template = _template(
        scheduledAt: anchor,
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          daysOfWeek: [DateTime.monday, DateTime.wednesday, DateTime.friday],
        ),
      );

      final generated = generateRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 2,
      );

      // Mon 3rd is the template. Remaining: Wed 5, Fri 7, Mon 10, Wed 12,
      // Fri 14, Mon 17 (17th is exactly the window edge).
      expect(generated.map((t) => t.scheduledAt), [
        DateTime(2026, 8, 5, 9, 0),
        DateTime(2026, 8, 7, 9, 0),
        DateTime(2026, 8, 10, 9, 0),
        DateTime(2026, 8, 12, 9, 0),
        DateTime(2026, 8, 14, 9, 0),
        DateTime(2026, 8, 17, 9, 0),
      ]);
    });

    test('interval skips whole weeks, keeping the selected days', () {
      final template = _template(
        scheduledAt: anchor,
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
          daysOfWeek: [DateTime.monday, DateTime.wednesday],
        ),
      );

      final generated = generateRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 5,
      );

      // Weeks of Aug 3, Aug 17, Aug 31 — the weeks of Aug 10 and Aug 24 are
      // skipped by the interval. A 5-week window from Aug 3 reaches Sep 7,
      // so the Wednesday of the Aug 31 week (Sep 2) is still inside it.
      expect(generated.map((t) => t.scheduledAt), [
        DateTime(2026, 8, 5, 9, 0),
        DateTime(2026, 8, 17, 9, 0),
        DateTime(2026, 8, 19, 9, 0),
        DateTime(2026, 8, 31, 9, 0),
        DateTime(2026, 9, 2, 9, 0),
      ]);
    });

    test('never generates an occurrence before the series starts', () {
      // Anchor is a Wednesday, but Monday is also selected — the Monday of
      // that first week is in the past relative to the series start.
      final template = _template(
        scheduledAt: DateTime(2026, 8, 5, 9, 0),
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          daysOfWeek: [DateTime.monday, DateTime.wednesday],
        ),
      );

      final generated = generateRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: DateTime(2026, 8, 5, 9, 0),
        windowWeeks: 1,
      );

      expect(
        generated.every((t) => !t.scheduledAt!.isBefore(template.scheduledAt!)),
        isTrue,
      );
      expect(generated.map((t) => t.scheduledAt), [
        DateTime(2026, 8, 10, 9, 0),
        DateTime(2026, 8, 12, 9, 0),
      ]);
    });
  });

  group('endDate', () {
    test('stops generating past the end date', () {
      final template = _template(
        scheduledAt: anchor,
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          endDate: DateTime(2026, 8, 6),
        ),
      );

      final generated = generateRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 4,
      );

      expect(generated.map((t) => t.scheduledAt), [
        DateTime(2026, 8, 4, 9, 0),
        DateTime(2026, 8, 5, 9, 0),
        DateTime(2026, 8, 6, 9, 0),
      ]);
    });

    test('an occurrence falling exactly on the end date is included', () {
      final template = _template(
        scheduledAt: anchor,
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          endDate: DateTime(2026, 8, 10),
        ),
      );

      final generated = generateRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 4,
      );

      expect(generated.map((t) => t.scheduledAt), [
        DateTime(2026, 8, 10, 9, 0),
      ]);
    });

    test('an end date already in the past generates nothing', () {
      final template = _template(
        scheduledAt: anchor,
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          endDate: DateTime(2026, 8, 3),
        ),
      );

      final generated = generateRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 4,
      );

      expect(generated, isEmpty);
    });
  });

  group('idempotency — regenerating must not duplicate', () {
    test('a second run over an already-materialized window adds nothing', () {
      final template = _template(
        scheduledAt: anchor,
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );

      final first = generateRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 2,
      );
      expect(first, isNotEmpty);

      // Simulates the next app launch: everything from run one is now
      // persisted, and `now` hasn't moved.
      final second = generateRecurrenceInstances(
        template: template,
        existingInstances: [template, ...first],
        now: now,
        windowWeeks: 2,
      );

      expect(second, isEmpty);
    });

    test('advancing time tops the window up by exactly the elapsed days', () {
      final template = _template(
        scheduledAt: anchor,
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );

      final first = generateRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 2,
      );

      // Three days later, the window has slid forward by three days.
      final second = generateRecurrenceInstances(
        template: template,
        existingInstances: [template, ...first],
        now: now.add(const Duration(days: 3)),
        windowWeeks: 2,
      );

      expect(second, hasLength(3));
      expect(second.map((t) => t.scheduledAt), [
        DateTime(2026, 8, 18, 9, 0),
        DateTime(2026, 8, 19, 9, 0),
        DateTime(2026, 8, 20, 9, 0),
      ]);
    });

    test('a rescheduled instance does not cause its slot to be refilled', () {
      // Guards the dedup key: an instance moved to a different time on the
      // same day must not leave its original slot looking vacant.
      final template = _template(
        scheduledAt: anchor,
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      final generated = generateRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 1,
      );
      // Reschedule exactly as TaskList.rescheduleTask does: preserve the
      // slot the series generated this instance for, then move it.
      final moved = generated.first
        ..originalScheduledAt = generated.first.scheduledAt
        ..scheduledAt = DateTime(2026, 8, 4, 15, 30);

      final second = generateRecurrenceInstances(
        template: template,
        existingInstances: [template, moved, ...generated.skip(1)],
        now: now,
        windowWeeks: 1,
      );

      // Nothing is regenerated: `originalScheduledAt` still claims the
      // 09:00 slot, so moving an instance doesn't leave a hole that gets
      // refilled with a duplicate. Caught on-device — an earlier version
      // deduped on `scheduledAt` alone and produced exactly that duplicate.
      expect(second, isEmpty);
    });
  });

  group('generated instance shape', () {
    test('instances copy the template but carry no rule of their own', () {
      final template = _template(
        scheduledAt: anchor,
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
        title: 'Morning run',
      );

      final generated = generateRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 1,
      );

      for (final instance in generated) {
        expect(instance.title, 'Morning run');
        expect(instance.category, template.category);
        expect(instance.durationMinutes, template.durationMinutes);
        expect(instance.recurrenceId, template.recurrenceId);
        expect(instance.isRecurring, isTrue);
        // Only the template carries the rule.
        expect(instance.recurrenceRule, isNull);
        expect(instance.isRecurrenceTemplate, isFalse);
        // Each instance is a real, independent task with its own id.
        expect(instance.id, isNotEmpty);
        expect(instance.id, isNot(template.id));
      }
      expect(
        generated.map((t) => t.id).toSet(),
        hasLength(generated.length),
        reason: 'every instance must have a unique id',
      );
    });

    test('a task with no rule generates nothing', () {
      final ordinary = Task.create(
        title: 'Ordinary',
        scheduledAt: anchor,
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );

      expect(
        generateRecurrenceInstances(
          template: ordinary,
          existingInstances: const [],
          now: now,
        ),
        isEmpty,
      );
    });
  });
}
