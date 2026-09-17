import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/onboarding_profile.dart';

/// Parses the REAL bundled catalog asset directly off disk (not a
/// synthetic fixture) — this is the schema-validation pass the work order
/// asked for: "write 3-4 real example profiles ... so the mechanism can be
/// verified end-to-end, not just schema-validated against an empty
/// catalog." Reads the file directly via `dart:io` rather than
/// `rootBundle` — this test doesn't need a widget binding, just the raw
/// JSON on disk, so it stays a plain `test()` rather than `testWidgets()`.
void main() {
  late Map<String, dynamic> decoded;

  setUpAll(() {
    final raw = File('assets/onboarding/profiles.json').readAsStringSync();
    decoded = jsonDecode(raw) as Map<String, dynamic>;
  });

  test('the bundled catalog has at least 3 profiles, per the work order', () {
    final profilesJson = decoded['profiles'] as List;
    expect(profilesJson.length, greaterThanOrEqualTo(3));
  });

  test('every bundled profile parses without throwing', () {
    final profilesJson = decoded['profiles'] as List;
    final profiles = profilesJson
        .map((p) => OnboardingProfile.fromJson(p as Map<String, dynamic>))
        .toList();
    expect(profiles, hasLength(profilesJson.length));
  });

  test('every profile id is unique', () {
    final profilesJson = decoded['profiles'] as List;
    final profiles = profilesJson
        .map((p) => OnboardingProfile.fromJson(p as Map<String, dynamic>))
        .toList();
    final ids = profiles.map((p) => p.id).toSet();
    expect(ids, hasLength(profiles.length));
  });

  test('every profile has at least one entry across its bundle — no silently '
      'empty profile', () {
    final profilesJson = decoded['profiles'] as List;
    final profiles = profilesJson
        .map((p) => OnboardingProfile.fromJson(p as Map<String, dynamic>))
        .toList();
    for (final profile in profiles) {
      final totalEntries =
          profile.zones.length +
          profile.templates.length +
          profile.tasks.length +
          profile.trackedBehaviors.length +
          profile.notes.length;
      expect(
        totalEntries,
        greaterThan(0),
        reason: '${profile.id} has an empty bundle',
      );
    }
  });

  test('every template/task categoryName is one of the 5 built-in category '
      'names', () {
    const validNames = {'general', 'health', 'work', 'personal', 'admin'};
    final profilesJson = decoded['profiles'] as List;
    final profiles = profilesJson
        .map((p) => OnboardingProfile.fromJson(p as Map<String, dynamic>))
        .toList();
    for (final profile in profiles) {
      for (final template in profile.templates) {
        expect(
          validNames,
          contains(template.categoryName),
          reason:
              '${profile.id}/"${template.title}" has an invalid '
              'categoryName',
        );
      }
      for (final task in profile.tasks) {
        expect(
          validNames,
          contains(task.categoryName),
          reason: '${profile.id}/"${task.title}" has an invalid categoryName',
        );
      }
    }
  });

  test('every zone weekday is within the 1 (Monday) - 7 (Sunday) range', () {
    final profilesJson = decoded['profiles'] as List;
    final profiles = profilesJson
        .map((p) => OnboardingProfile.fromJson(p as Map<String, dynamic>))
        .toList();
    for (final profile in profiles) {
      for (final zone in profile.zones) {
        for (final day in zone.weekdays) {
          expect(day, inInclusiveRange(1, 7));
        }
      }
    }
  });

  test('parseTimeOfDayMinutes converts "HH:mm" to minutes since midnight', () {
    expect(parseTimeOfDayMinutes('00:00'), 0);
    expect(parseTimeOfDayMinutes('09:30'), 570);
    expect(parseTimeOfDayMinutes('23:59'), 1439);
  });

  test('parseTimeOfDayMinutes rejects an out-of-range time', () {
    expect(() => parseTimeOfDayMinutes('24:00'), throwsFormatException);
    expect(() => parseTimeOfDayMinutes('12:60'), throwsFormatException);
  });

  test('OnboardingProfile.fromJson throws on a missing required field', () {
    expect(
      () => OnboardingProfile.fromJson({'id': 'x', 'title': 'X'}),
      throwsFormatException,
    );
  });
}
