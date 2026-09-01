import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/services/quick_capture_parser.dart';

void main() {
  // Tuesday, so "next monday"/"next wednesday" etc. have unambiguous,
  // hand-verifiable expected dates.
  final now = DateTime(2026, 9, 1, 14, 0);

  // The 5 built-in categories, same names/ids the app actually seeds
  // (see BuiltInCategoryIds) — parseQuickCapture matches category words
  // against live Category.name now, not the old fixed TaskCategory enum.
  final categories = [
    Category(
      id: BuiltInCategoryIds.general,
      name: 'General',
      colorToken: 0,
      emoji: '⚪',
      isBuiltIn: true,
    ),
    Category(
      id: BuiltInCategoryIds.health,
      name: 'Health',
      colorToken: 1,
      emoji: '⛑️',
      isBuiltIn: true,
    ),
    Category(
      id: BuiltInCategoryIds.work,
      name: 'Work',
      colorToken: 2,
      emoji: '💼',
      isBuiltIn: true,
    ),
    Category(
      id: BuiltInCategoryIds.personal,
      name: 'Personal',
      colorToken: 3,
      emoji: '🏠',
      isBuiltIn: true,
    ),
    Category(
      id: BuiltInCategoryIds.admin,
      name: 'Admin',
      colorToken: 4,
      emoji: '📋',
      isBuiltIn: true,
    ),
  ];
  final workCategory = categories.firstWhere((c) => c.name == 'Work');
  final healthCategory = categories.firstWhere((c) => c.name == 'Health');
  final personalCategory = categories.firstWhere((c) => c.name == 'Personal');
  final adminCategory = categories.firstWhere((c) => c.name == 'Admin');

  group('date/time extraction', () {
    test('"today" anchors to the current calendar day, default 09:00', () {
      final result = parseQuickCapture(
        'Water plants today',
        now: now,
        categories: categories,
      );

      expect(result.isConfident, isTrue);
      expect(result.scheduledAt, DateTime(2026, 9, 1, 9, 0));
      expect(result.title, 'Water plants');
    });

    test('"tomorrow" anchors to the next calendar day', () {
      final result = parseQuickCapture(
        'Water plants tomorrow',
        now: now,
        categories: categories,
      );

      expect(result.isConfident, isTrue);
      expect(result.scheduledAt, DateTime(2026, 9, 2, 9, 0));
    });

    test('"next monday" resolves to the coming Monday, not today even if '
        'today happened to be Monday', () {
      final result = parseQuickCapture(
        'Call client next monday',
        now: now,
        categories: categories,
      );

      // now is Tuesday 2026-09-01; the next Monday is 2026-09-07.
      expect(result.scheduledAt, DateTime(2026, 9, 7, 9, 0));
    });

    test('"next monday" said ON a Monday means seven days out, not today', () {
      final aMonday = DateTime(2026, 9, 7, 10, 0);
      final result = parseQuickCapture(
        'Call client next monday',
        now: aMonday,
        categories: categories,
      );

      expect(result.scheduledAt, DateTime(2026, 9, 14, 9, 0));
    });

    test(
      '"at 10:30" sets an explicit time on today (no relative-day word)',
      () {
        final result = parseQuickCapture(
          'Call client at 10:30',
          now: now,
          categories: categories,
        );

        expect(result.isConfident, isTrue);
        expect(result.scheduledAt, DateTime(2026, 9, 1, 10, 30));
        expect(result.title, 'Call client');
      },
    );

    test('"3pm" (no colon, no leading "at") is recognized', () {
      final result = parseQuickCapture(
        'Call client 3pm',
        now: now,
        categories: categories,
      );

      expect(result.scheduledAt, DateTime(2026, 9, 1, 15, 0));
    });

    test('"3:15pm" combines minutes with a bare meridiem time', () {
      final result = parseQuickCapture(
        'Call client 3:15pm',
        now: now,
        categories: categories,
      );

      expect(result.scheduledAt, DateTime(2026, 9, 1, 15, 15));
    });

    test('12am is midnight (00:00), 12pm is noon', () {
      final midnight = parseQuickCapture(
        'Reset at 12am',
        now: now,
        categories: categories,
      );
      final noon = parseQuickCapture(
        'Lunch at 12pm',
        now: now,
        categories: categories,
      );

      expect(midnight.scheduledAt!.hour, 0);
      expect(noon.scheduledAt!.hour, 12);
    });

    test('a relative day plus an explicit time combines onto one instant', () {
      final result = parseQuickCapture(
        'Call client tomorrow at 10:30',
        now: now,
        categories: categories,
      );

      expect(result.scheduledAt, DateTime(2026, 9, 2, 10, 30));
      expect(result.title, 'Call client');
    });
  });

  group('duration extraction', () {
    test('"for 30 mins" extracts 30 minutes', () {
      final result = parseQuickCapture(
        'Call client at 10:30 for 30 mins',
        now: now,
        categories: categories,
      );

      expect(result.durationMinutes, 30);
      expect(result.title, 'Call client');
    });

    test('"for 30 minutes" (full word) also matches', () {
      final result = parseQuickCapture(
        'Call client at 10:30 for 30 minutes',
        now: now,
        categories: categories,
      );

      expect(result.durationMinutes, 30);
    });

    test('"for 2 hours" converts to minutes', () {
      final result = parseQuickCapture(
        'Deep work at 9am for 2 hours',
        now: now,
        categories: categories,
      );

      expect(result.durationMinutes, 120);
    });

    test('"for 1 hr" and "for 1h" both match the hour unit', () {
      final hr = parseQuickCapture(
        'Gym at 6pm for 1 hr',
        now: now,
        categories: categories,
      );
      final h = parseQuickCapture(
        'Gym at 6pm for 1h',
        now: now,
        categories: categories,
      );

      expect(hr.durationMinutes, 60);
      expect(h.durationMinutes, 60);
    });

    test('a confident parse with NO duration phrase gets the default', () {
      final result = parseQuickCapture(
        'Call client at 10:30',
        now: now,
        categories: categories,
      );

      expect(result.durationMinutes, quickCaptureDefaultDurationMinutes);
    });
  });

  group('recurrence extraction', () {
    test('"every morning" (with an anchor) becomes a daily rule', () {
      final result = parseQuickCapture(
        'Meditate today every morning',
        now: now,
        categories: categories,
      );

      expect(result.isConfident, isTrue);
      expect(result.recurrenceRule?.frequency, RecurrenceFrequency.daily);
      expect(result.recurrenceRule?.daysOfWeek, isNull);
    });

    test('"daily" (with an anchor) becomes a daily rule', () {
      final result = parseQuickCapture(
        'Stretch at 7am daily',
        now: now,
        categories: categories,
      );

      expect(result.recurrenceRule?.frequency, RecurrenceFrequency.daily);
    });

    test('"every monday" (with an anchor) becomes weekly on Monday', () {
      final result = parseQuickCapture(
        'Standup today every monday',
        now: now,
        categories: categories,
      );

      expect(result.recurrenceRule?.frequency, RecurrenceFrequency.weekly);
      expect(result.recurrenceRule?.daysOfWeek, [DateTime.monday]);
    });
  });

  group('combined input', () {
    test('title + relative day + time + duration all extract together', () {
      final result = parseQuickCapture(
        'Call client tomorrow at 10:30 for 30 mins',
        now: now,
        categories: categories,
      );

      expect(result.isConfident, isTrue);
      expect(result.title, 'Call client');
      expect(result.scheduledAt, DateTime(2026, 9, 2, 10, 30));
      expect(result.durationMinutes, 30);
      expect(result.recurrenceRule, isNull);
    });

    test('every extraction category together in one input', () {
      final result = parseQuickCapture(
        'Team standup next monday at 9am for 15 mins every monday',
        now: now,
        categories: categories,
      );

      expect(result.title, 'Team standup');
      expect(result.scheduledAt, DateTime(2026, 9, 7, 9, 0));
      expect(result.durationMinutes, 15);
      expect(result.recurrenceRule?.frequency, RecurrenceFrequency.weekly);
      expect(result.recurrenceRule?.daysOfWeek, [DateTime.monday]);
    });

    test('extracted phrases are removed cleanly, leaving no double spaces', () {
      final result = parseQuickCapture(
        'Call client tomorrow at 10:30 for 30 mins',
        now: now,
        categories: categories,
      );

      expect(result.title, isNot(contains('  ')));
      expect(result.title, isNot(startsWith(' ')));
      expect(result.title, isNot(endsWith(' ')));
    });
  });

  group('confidence threshold — the auto-create gate', () {
    test('plain text with no date/time token at all is NOT confident', () {
      final result = parseQuickCapture(
        'Book dentist appointment',
        now: now,
        categories: categories,
      );

      expect(result.isConfident, isFalse);
      expect(result.scheduledAt, isNull);
      expect(result.title, 'Book dentist appointment');
    });

    test('a bare recurrence phrase with NO anchor is NOT confident — '
        'the work order\'s own example', () {
      final result = parseQuickCapture(
        'Meditate every morning',
        now: now,
        categories: categories,
      );

      expect(result.isConfident, isFalse);
      expect(result.scheduledAt, isNull);
      // Still extracted for highlighting purposes, just doesn't grant
      // confidence on its own.
      expect(result.recurrenceRule, isNull);
      expect(
        result.tokens.any((t) => t.kind == QuickCaptureTokenKind.recurrence),
        isTrue,
      );
    });

    test('a bare duration phrase with NO anchor is NOT confident', () {
      final result = parseQuickCapture(
        'Nap for 20 mins',
        now: now,
        categories: categories,
      );

      expect(result.isConfident, isFalse);
      expect(result.scheduledAt, isNull);
      expect(result.durationMinutes, isNull);
    });

    test('a bare duration + bare recurrence together, still no anchor, is '
        'still NOT confident', () {
      final result = parseQuickCapture(
        'Meditate every morning for 10 mins',
        now: now,
        categories: categories,
      );

      expect(result.isConfident, isFalse);
      expect(result.scheduledAt, isNull);
    });

    test('"today" alone (no time-of-day) IS confident — a relative-day '
        'word is itself an explicit anchor', () {
      final result = parseQuickCapture(
        'Water plants today',
        now: now,
        categories: categories,
      );

      expect(result.isConfident, isTrue);
    });

    test(
      'an explicit clock time alone (no relative-day word) IS confident',
      () {
        final result = parseQuickCapture(
          'Call client at 4pm',
          now: now,
          categories: categories,
        );

        expect(result.isConfident, isTrue);
      },
    );

    test('when not confident, recurrenceRule/durationMinutes are null even '
        'if phrases were found in the text', () {
      final result = parseQuickCapture(
        'Meditate every morning for 10 mins',
        now: now,
        categories: categories,
      );

      expect(result.recurrenceRule, isNull);
      expect(result.durationMinutes, isNull);
    });
  });

  group('fallback (non-confident) behavior', () {
    test('the ENTIRE input becomes the title, untouched, when not '
        'confident', () {
      final input = 'Meditate every morning for 10 mins';
      final result = parseQuickCapture(input, now: now, categories: categories);

      expect(result.title, input);
    });

    test('empty input produces an empty, non-confident result', () {
      final result = parseQuickCapture('', now: now, categories: categories);

      expect(result.isConfident, isFalse);
      expect(result.title, '');
      expect(result.tokens, isEmpty);
    });
  });

  group('token highlighting spans', () {
    test('each extracted category produces a token whose substring matches '
        'the phrase that was matched', () {
      const input = 'Call client tomorrow at 10:30 for 30 mins every monday';
      final result = parseQuickCapture(input, now: now, categories: categories);

      for (final token in result.tokens) {
        final substring = input.substring(token.start, token.end);
        expect(substring.trim(), isNotEmpty);
      }
    });

    test('tokens are returned in left-to-right order of appearance', () {
      const input = 'Call client tomorrow at 10:30 for 30 mins every monday';
      final result = parseQuickCapture(input, now: now, categories: categories);

      for (var i = 1; i < result.tokens.length; i++) {
        expect(
          result.tokens[i].start,
          greaterThanOrEqualTo(result.tokens[i - 1].end),
        );
      }
    });

    test('no two tokens overlap', () {
      const input = 'Call client tomorrow at 10:30 for 30 mins every monday';
      final result = parseQuickCapture(input, now: now, categories: categories);

      for (var i = 1; i < result.tokens.length; i++) {
        expect(
          result.tokens[i].start,
          greaterThanOrEqualTo(result.tokens[i - 1].end),
        );
      }
    });
  });

  group('bare 24h time (no am/pm)', () {
    test('"11:00" with no am/pm is confident and sets that time', () {
      final result = parseQuickCapture(
        'Call client 11:00',
        now: now,
        categories: categories,
      );

      expect(result.isConfident, isTrue);
      expect(result.scheduledAt, DateTime(2026, 9, 1, 11, 0));
      expect(result.title, 'Call client');
    });

    test('"at 11:00" with no am/pm also works', () {
      final result = parseQuickCapture(
        'Call client at 11:00',
        now: now,
        categories: categories,
      );

      expect(result.scheduledAt, DateTime(2026, 9, 1, 11, 0));
    });

    test('a bare 24h time in the evening (e.g. 18:30) is not reinterpreted '
        'as am/pm — it is taken literally', () {
      final result = parseQuickCapture(
        'Dinner 18:30',
        now: now,
        categories: categories,
      );

      expect(result.scheduledAt, DateTime(2026, 9, 1, 18, 30));
    });

    test('an explicit am/pm form is still preferred over a bare-24h read '
        'when both could apply to the same digits', () {
      final result = parseQuickCapture(
        'Call client 11:00am',
        now: now,
        categories: categories,
      );

      expect(result.scheduledAt, DateTime(2026, 9, 1, 11, 0));
      expect(result.title, 'Call client');
    });
  });

  group('bare duration (no leading "for")', () {
    test('"2h" alone extracts 120 minutes and grants confidence together '
        'with an anchor', () {
      // Deliberately avoids the word "work" in the title here — it's a
      // real category word (see the category-detection group below) and
      // would otherwise be extracted out of the title too, which isn't
      // what this test is isolating.
      final result = parseQuickCapture(
        'Deep focus today 2h',
        now: now,
        categories: categories,
      );

      expect(result.isConfident, isTrue);
      expect(result.durationMinutes, 120);
      expect(result.title, 'Deep focus');
    });

    test('"90m" alone extracts 90 minutes', () {
      final result = parseQuickCapture(
        'Nap today 90m',
        now: now,
        categories: categories,
      );

      expect(result.durationMinutes, 90);
    });

    test('"1h5m" (no space) combines hours and minutes', () {
      final result = parseQuickCapture(
        'Workout today 1h5m',
        now: now,
        categories: categories,
      );

      expect(result.durationMinutes, 65);
    });

    test('"1h 5m" (with a space) also combines', () {
      final result = parseQuickCapture(
        'Workout today 1h 5m',
        now: now,
        categories: categories,
      );

      expect(result.durationMinutes, 65);
    });

    test('a bare duration alone with NO anchor is still not confident, '
        'matching the "for"-prefixed form\'s own rule', () {
      final result = parseQuickCapture(
        'Nap 90m',
        now: now,
        categories: categories,
      );

      expect(result.isConfident, isFalse);
      expect(result.durationMinutes, isNull);
    });

    test('the explicit "for" form is preferred over the bare form when '
        'both could apply to the same digits', () {
      final result = parseQuickCapture(
        'Call client today for 2h',
        now: now,
        categories: categories,
      );

      expect(result.durationMinutes, 120);
      expect(result.title, 'Call client');
    });
  });

  group('recurrence: everyday / weekdays / weekends / ranges', () {
    test('"everyday" (one word) becomes a daily rule', () {
      final result = parseQuickCapture(
        'Meditate today everyday',
        now: now,
        categories: categories,
      );

      expect(result.recurrenceRule?.frequency, RecurrenceFrequency.daily);
    });

    test('"weekdays" (bare, no "every") becomes weekly Mon-Fri', () {
      final result = parseQuickCapture(
        'Standup today weekdays',
        now: now,
        categories: categories,
      );

      expect(result.recurrenceRule?.frequency, RecurrenceFrequency.weekly);
      expect(result.recurrenceRule?.daysOfWeek, [1, 2, 3, 4, 5]);
    });

    test('"every weekday" also becomes weekly Mon-Fri', () {
      final result = parseQuickCapture(
        'Standup today every weekday',
        now: now,
        categories: categories,
      );

      expect(result.recurrenceRule?.daysOfWeek, [1, 2, 3, 4, 5]);
    });

    test('"weekend"/"weekends" (bare) becomes weekly Sat-Sun', () {
      final result = parseQuickCapture(
        'Relax today weekends',
        now: now,
        categories: categories,
      );

      expect(result.recurrenceRule?.frequency, RecurrenceFrequency.weekly);
      expect(result.recurrenceRule?.daysOfWeek, [6, 7]);
    });

    test('"every weekend" also becomes weekly Sat-Sun', () {
      final result = parseQuickCapture(
        'Relax today every weekend',
        now: now,
        categories: categories,
      );

      expect(result.recurrenceRule?.daysOfWeek, [6, 7]);
    });

    test('"mon-fri" (abbreviated, hyphen) expands to weekly Mon-Fri, no '
        '"every" needed', () {
      final result = parseQuickCapture(
        'Standup today mon-fri',
        now: now,
        categories: categories,
      );

      expect(result.recurrenceRule?.frequency, RecurrenceFrequency.weekly);
      expect(result.recurrenceRule?.daysOfWeek, [1, 2, 3, 4, 5]);
    });

    test('"mon to fri" (abbreviated, "to") also expands to weekly Mon-Fri', () {
      final result = parseQuickCapture(
        'Standup today mon to fri',
        now: now,
        categories: categories,
      );

      expect(result.recurrenceRule?.daysOfWeek, [1, 2, 3, 4, 5]);
    });

    test('"monday to friday" (full names) also expands to weekly Mon-Fri', () {
      final result = parseQuickCapture(
        'Standup today monday to friday',
        now: now,
        categories: categories,
      );

      expect(result.recurrenceRule?.daysOfWeek, [1, 2, 3, 4, 5]);
    });

    test('a weekday range narrower than Mon-Fri (e.g. "tue to thu") expands '
        'to exactly that range', () {
      final result = parseQuickCapture(
        'Gym today tue to thu',
        now: now,
        categories: categories,
      );

      expect(result.recurrenceRule?.daysOfWeek, [2, 3, 4]);
    });

    test('"every friday" (full name) still works as a single-day rule', () {
      final result = parseQuickCapture(
        'Standup today every friday',
        now: now,
        categories: categories,
      );

      expect(result.recurrenceRule?.frequency, RecurrenceFrequency.weekly);
      expect(result.recurrenceRule?.daysOfWeek, [5]);
    });

    test('"every fri" (3-letter abbreviation) also works as a single-day '
        'rule', () {
      final result = parseQuickCapture(
        'Standup today every fri',
        now: now,
        categories: categories,
      );

      expect(result.recurrenceRule?.daysOfWeek, [5]);
    });
  });

  group('category detection', () {
    test('"work" in the text sets category to work and is removed from '
        'the title', () {
      final result = parseQuickCapture(
        'Finish report work today at 3pm',
        now: now,
        categories: categories,
      );

      expect(result.category, workCategory);
      expect(result.title, 'Finish report');
    });

    test('"health" sets category to health', () {
      final result = parseQuickCapture(
        'Doctor visit health today',
        now: now,
        categories: categories,
      );

      expect(result.category, healthCategory);
    });

    test('"personal" sets category to personal', () {
      final result = parseQuickCapture(
        'Call mom personal today',
        now: now,
        categories: categories,
      );

      expect(result.category, personalCategory);
    });

    test('"admin" sets category to admin', () {
      final result = parseQuickCapture(
        'File taxes admin today',
        now: now,
        categories: categories,
      );

      expect(result.category, adminCategory);
    });

    test('no category word present leaves category null', () {
      final result = parseQuickCapture(
        'Call client today',
        now: now,
        categories: categories,
      );

      expect(result.category, isNull);
    });

    test('category is detected even when the parse is NOT confident — it '
        'carries no scheduling ambiguity', () {
      final result = parseQuickCapture(
        'Book dentist health',
        now: now,
        categories: categories,
      );

      expect(result.isConfident, isFalse);
      expect(result.category, healthCategory);
    });

    test('a detected category word is highlighted as its own token kind', () {
      final result = parseQuickCapture(
        'Finish report work today',
        now: now,
        categories: categories,
      );

      expect(
        result.tokens.any((t) => t.kind == QuickCaptureTokenKind.category),
        isTrue,
      );
    });
  });
}
