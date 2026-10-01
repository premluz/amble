import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/label_presets.dart';
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

  // What `OnboardingLabelResolver` can resolve on a fresh install: a
  // built-in key, a seeded built-in label's display name, or a label preset.
  test('every template/task categoryName resolves on a fresh install', () {
    final validNames = {
      'general',
      'health',
      'work',
      'personal',
      'admin',
      'General',
      'Health',
      'Work',
      'Home',
      'Admin',
      'Personal',
      'Social',
      'Reading',
      'Learning',
      for (final preset in labelPresets) preset.name,
    };
    final profilesJson = decoded['profiles'] as List;
    final profiles = profilesJson
        .map((p) => OnboardingProfile.fromJson(p as Map<String, dynamic>))
        .toList();
    for (final profile in profiles) {
      for (final entry in [
        ...profile.templates.map((t) => (t.title, t.categoryName)),
        ...profile.tasks.map((t) => (t.title, t.categoryName)),
      ]) {
        expect(
          validNames,
          contains(entry.$2),
          reason: '${profile.id}/"${entry.$1}" has an unresolvable label',
        );
      }
    }
  });

  test('the Demo profile carries every part of a starter set', () {
    final demo = (decoded['profiles'] as List)
        .map((p) => OnboardingProfile.fromJson(p as Map<String, dynamic>))
        .singleWhere((p) => p.id == 'demo');
    expect(demo.quizTags, isEmpty, reason: 'the quiz must never pick it');
    expect(demo.trackedBehaviors, hasLength(6));
    expect(demo.templates.length, greaterThanOrEqualTo(18));
    expect(demo.zones.map((z) => z.title).toSet(), {
      'Morning routine',
      'Commute',
      'Office time',
      'WFH',
      'Available',
    });
    expect(demo.sections.map((s) => s.name), [
      'Work',
      'Personal',
      'Hobbies',
      'Growth',
      'Family',
      'Someday',
    ]);
    expect(
      demo.sections.expand((s) => s.things).length,
      greaterThanOrEqualTo(20),
    );
    final tasks = [...demo.tasks]
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    for (var i = 1; i < tasks.length; i++) {
      final previousEnd =
          tasks[i - 1].startMinutes + tasks[i - 1].durationMinutes;
      expect(
        tasks[i].startMinutes,
        greaterThanOrEqualTo(previousEnd),
        reason: '"${tasks[i].title}" overlaps "${tasks[i - 1].title}"',
      );
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
