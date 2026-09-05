import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/models/zone.dart';

void main() {
  test('toJson -> fromJson round-trips a fully-populated zone', () {
    final zone = Zone(
      id: 'zone-1',
      title: 'Morning ritual',
      startMinutes: 7 * 60,
      endMinutes: 8 * 60,
      schemaVersion: 1,
      recurrenceRule: RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        interval: 1,
        daysOfWeek: [1, 3, 5],
      ),
      notificationsEnabled: false,
    );

    final restored = Zone.fromJson(zone.toJson());

    expect(restored.id, zone.id);
    expect(restored.title, zone.title);
    expect(restored.startMinutes, zone.startMinutes);
    expect(restored.endMinutes, zone.endMinutes);
    expect(restored.schemaVersion, zone.schemaVersion);
    expect(restored.notificationsEnabled, zone.notificationsEnabled);
    expect(restored.hasSameFieldsAs(zone), isTrue);
  });

  test('toJson -> fromJson round-trips a non-recurring zone', () {
    final zone = Zone.create(
      title: 'Evening wind-down',
      startMinutes: 21 * 60,
      endMinutes: 22 * 60,
    );

    final restored = Zone.fromJson(zone.toJson());

    expect(restored.recurrenceRule, isNull);
    expect(restored.hasSameFieldsAs(zone), isTrue);
  });

  test('fromJson throws FormatException for a missing id', () {
    final json = Zone.create(
      title: 'X',
      startMinutes: 0,
      endMinutes: 60,
    ).toJson()..remove('id');
    expect(() => Zone.fromJson(json), throwsFormatException);
  });

  test('fromJson throws FormatException for a missing title', () {
    final json = Zone.create(
      title: 'X',
      startMinutes: 0,
      endMinutes: 60,
    ).toJson()..remove('title');
    expect(() => Zone.fromJson(json), throwsFormatException);
  });

  test('fromJson throws FormatException for a missing startMinutes', () {
    final json = Zone.create(
      title: 'X',
      startMinutes: 0,
      endMinutes: 60,
    ).toJson()..remove('startMinutes');
    expect(() => Zone.fromJson(json), throwsFormatException);
  });

  test('a backup exported before notificationsEnabled existed imports as '
      'true — matching the constructor\'s own historical default', () {
    final legacyJson = Zone.create(
      title: 'Legacy zone',
      startMinutes: 0,
      endMinutes: 60,
    ).toJson()..remove('notificationsEnabled');

    final restored = Zone.fromJson(legacyJson);

    expect(restored.notificationsEnabled, isTrue);
  });

  test('hasSameFieldsAs is false when any field differs', () {
    final a = Zone.create(title: 'Same', startMinutes: 0, endMinutes: 60);
    final b = Zone(id: a.id, title: 'Same', startMinutes: 0, endMinutes: 90);

    expect(a.hasSameFieldsAs(b), isFalse);
  });
}
