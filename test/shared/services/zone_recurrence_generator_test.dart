import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/services/zone_recurrence_generator.dart';

/// A template anchored at a known day, so window maths is deterministic
/// rather than dependent on the day the suite happens to run. Mirrors
/// `recurrence_generator_test.dart`'s own `_template` helper.
Zone _template({
  required DateTime anchorDate,
  required RecurrenceRule rule,
  String seriesId = 'series-1',
  String title = 'Repeating zone',
  int startMinutes = 7 * 60,
  int endMinutes = 8 * 60,
}) {
  return Zone.create(
    title: title,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    recurrenceId: seriesId,
    recurrenceRule: rule,
    anchorDate: anchorDate,
  );
}

void main() {
  // Monday.
  final anchor = DateTime(2026, 8, 3);
  final now = anchor;

  group('daily recurrence', () {
    test('materializes one instance per day across the window', () {
      final template = _template(
        anchorDate: anchor,
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );

      final generated = generateZoneRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 2,
      );

      // 15 days inclusive of the anchor; the anchor itself is already
      // materialized as the template, so 14 are generated.
      expect(generated, hasLength(14));
      expect(generated.first.anchorDate, DateTime(2026, 8, 4));
      expect(generated.last.anchorDate, DateTime(2026, 8, 17));
    });

    test('interval skips days — every 3 days', () {
      final template = _template(
        anchorDate: anchor,
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily, interval: 3),
      );

      final generated = generateZoneRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 2,
      );

      expect(generated.map((z) => z.anchorDate), [
        DateTime(2026, 8, 6),
        DateTime(2026, 8, 9),
        DateTime(2026, 8, 12),
        DateTime(2026, 8, 15),
      ]);
    });
  });

  group('weekly recurrence', () {
    test('null daysOfWeek repeats on the anchor weekday', () {
      final template = _template(
        anchorDate: anchor,
        rule: RecurrenceRule(frequency: RecurrenceFrequency.weekly),
      );

      final generated = generateZoneRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 4,
      );

      expect(generated.map((z) => z.anchorDate), [
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 17),
        DateTime(2026, 8, 24),
        DateTime(2026, 8, 31),
      ]);
      for (final zone in generated) {
        expect(zone.anchorDate!.weekday, DateTime.monday);
      }
    });

    test('daysOfWeek produces several instances per week', () {
      final template = _template(
        anchorDate: anchor,
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          daysOfWeek: [DateTime.monday, DateTime.wednesday, DateTime.friday],
        ),
      );

      final generated = generateZoneRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 2,
      );

      expect(generated.map((z) => z.anchorDate), [
        DateTime(2026, 8, 5),
        DateTime(2026, 8, 7),
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 12),
        DateTime(2026, 8, 14),
        DateTime(2026, 8, 17),
      ]);
    });
  });

  group('endDate', () {
    test('stops generating past the end date', () {
      final template = _template(
        anchorDate: anchor,
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          endDate: DateTime(2026, 8, 6),
        ),
      );

      final generated = generateZoneRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 4,
      );

      expect(generated.map((z) => z.anchorDate), [
        DateTime(2026, 8, 4),
        DateTime(2026, 8, 5),
        DateTime(2026, 8, 6),
      ]);
    });
  });

  group('idempotency — regenerating must not duplicate', () {
    test('a second run over an already-materialized window adds nothing', () {
      final template = _template(
        anchorDate: anchor,
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );

      final first = generateZoneRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 2,
      );
      expect(first, isNotEmpty);

      final second = generateZoneRecurrenceInstances(
        template: template,
        existingInstances: [template, ...first],
        now: now,
        windowWeeks: 2,
      );

      expect(second, isEmpty);
    });

    test('advancing time tops the window up by exactly the elapsed days', () {
      final template = _template(
        anchorDate: anchor,
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );

      final first = generateZoneRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 2,
      );

      final second = generateZoneRecurrenceInstances(
        template: template,
        existingInstances: [template, ...first],
        now: now.add(const Duration(days: 3)),
        windowWeeks: 2,
      );

      expect(second, hasLength(3));
      expect(second.map((z) => z.anchorDate), [
        DateTime(2026, 8, 18),
        DateTime(2026, 8, 19),
        DateTime(2026, 8, 20),
      ]);
    });
  });

  group('generated instance shape', () {
    test('instances copy the template\'s time/title but carry no rule of '
        'their own', () {
      final template = _template(
        anchorDate: anchor,
        rule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
        title: 'Morning ritual',
        startMinutes: 6 * 60,
        endMinutes: 7 * 60,
      );

      final generated = generateZoneRecurrenceInstances(
        template: template,
        existingInstances: [template],
        now: now,
        windowWeeks: 1,
      );

      for (final instance in generated) {
        expect(instance.title, 'Morning ritual');
        expect(instance.startMinutes, 6 * 60);
        expect(instance.endMinutes, 7 * 60);
        expect(instance.recurrenceId, template.recurrenceId);
        expect(instance.isRecurring, isTrue);
        // Only the template carries the rule.
        expect(instance.recurrenceRule, isNull);
        expect(instance.isRecurrenceTemplate, isFalse);
        // Each instance is a real, independent zone with its own id.
        expect(instance.id, isNotEmpty);
        expect(instance.id, isNot(template.id));
      }
      expect(
        generated.map((z) => z.id).toSet(),
        hasLength(generated.length),
        reason: 'every instance must have a unique id',
      );
    });

    test('a zone with no rule generates nothing', () {
      final ordinary = Zone.create(
        title: 'Ordinary',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
      );

      expect(
        generateZoneRecurrenceInstances(
          template: ordinary,
          existingInstances: const [],
          now: now,
        ),
        isEmpty,
      );
    });

    test('a template with a rule but no anchorDate generates nothing — an '
        'anchor day is required to know where to start', () {
      final noAnchor = Zone(
        id: 'no-anchor',
        title: 'No anchor',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
        recurrenceId: 'series-x',
        recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );

      expect(
        generateZoneRecurrenceInstances(
          template: noAnchor,
          existingInstances: const [],
          now: now,
        ),
        isEmpty,
      );
    });
  });
}
