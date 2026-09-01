import '../models/category.dart';
import '../models/recurrence_frequency.dart';
import '../models/recurrence_rule.dart';

/// The kind of token [QuickCaptureToken] represents — drives which
/// highlight color the live-typing UI applies (see
/// `quick_capture_sheet.dart`'s `_QuickCaptureTextEditingController`).
enum QuickCaptureTokenKind { dateTime, duration, recurrence, category }

/// One matched span of the raw input text, for highlighting. Purely a
/// UI concern — [parseQuickCapture] itself only needs the extracted
/// values, not where in the string they came from, but the live
/// highlighter needs both, so this list is returned alongside the
/// structured result rather than recomputed by the UI with a second,
/// possibly-diverging pass over the same text.
class QuickCaptureToken {
  const QuickCaptureToken({
    required this.start,
    required this.end,
    required this.kind,
  });

  /// Start offset into the ORIGINAL input string, inclusive.
  final int start;

  /// End offset into the original input string, exclusive.
  final int end;

  final QuickCaptureTokenKind kind;
}

/// The result of parsing one Quick Capture input string.
///
/// [isConfident] is the auto-create gate — see [parseQuickCapture]'s own
/// doc comment for the exact rule. Every extracted field is nullable and
/// independently optional; only [title] is guaranteed non-empty (falling
/// back to the trimmed raw input when nothing was extracted).
class QuickCaptureParseResult {
  const QuickCaptureParseResult({
    required this.title,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.recurrenceRule,
    required this.category,
    required this.isConfident,
    required this.tokens,
  });

  final String title;
  final DateTime? scheduledAt;
  final int? durationMinutes;
  final RecurrenceRule? recurrenceRule;

  /// Detected from a category NAME appearing in the text, matched against
  /// the LIVE category list passed into [parseQuickCapture] — independent
  /// of [isConfident], since a category word carries no scheduling
  /// ambiguity the way a bare duration/recurrence phrase does. Null when
  /// no category word was found; the caller defaults to the General
  /// built-in itself, matching the rest of the app's own "uncategorised"
  /// convention.
  final Category? category;

  /// True only when an explicit date/time anchor was found — see
  /// [parseQuickCapture]'s doc comment. Never true with [scheduledAt]
  /// null; the two always agree.
  final bool isConfident;

  /// Every matched span, in the order they appear in the original input —
  /// for live highlighting only, not consumed by the auto-create path.
  final List<QuickCaptureToken> tokens;
}

/// Default duration (minutes) applied to a confident parse that found a
/// date/time anchor but no explicit duration phrase — matches the
/// existing create-flow default so a Quick-Capture-created task looks like
/// any other freshly created task rather than an unusually short one.
const quickCaptureDefaultDurationMinutes = 30;

const _weekdayNames = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

const _weekdayAbbreviations = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// Either the full name or the 3-letter abbreviation for [weekday]
/// (1 = Monday .. 7 = Sunday), matched against [word] case-insensitively.
int? _weekdayIndexOf(String word) {
  final lower = word.toLowerCase();
  final byName = _weekdayNames.indexOf(lower);
  if (byName != -1) return byName + 1;
  final byAbbrev = _weekdayAbbreviations.indexOf(lower);
  if (byAbbrev != -1) return byAbbrev + 1;
  return null;
}

const _weekdayAlternation =
    r'(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|'
    r'mon|tue|wed|thu|fri|sat|sun)';

// Every pattern below is matched case-insensitively against the raw
// input, longest/most-specific alternatives first within each group so a
// phrase like "next monday" isn't partially consumed by a shorter
// "monday"-only pattern before the fuller one gets a chance.

final _todayPattern = RegExp(r'\btoday\b', caseSensitive: false);
final _tomorrowPattern = RegExp(r'\btomorrow\b', caseSensitive: false);
final _nextWeekdayPattern = RegExp(
  r'\bnext\s+('
  '$_weekdayAlternation'
  r')\b',
  caseSensitive: false,
);

// "at 10:30", "at 3pm", "at 3:15 pm", "10:30am" (no leading "at"), "3pm",
// and now also a bare 24h-style time with NO am/pm at all — "11:00",
// "at 11:00". The bare-24h alternative is listed LAST so the am/pm forms
// (which are more specific) are preferred whenever both could match the
// same digits — RegExp alternation is first-match, not longest-match.
final _clockTimePattern = RegExp(
  r'\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b'
  r'|\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b'
  r'|\b(\d{1,2}):(\d{2})\b',
  caseSensitive: false,
);

// "for 30 mins", "for 30 minutes", "for 2 hours", "for 1 hr", "for 1h" —
// the explicit "for"-prefixed form, tried first so it wins the highlight
// span (including the word "for") when a bare form could also match the
// same digits.
final _durationWithForPattern = RegExp(
  r'\bfor\s+(\d+)\s*(minutes|mins|min|hours|hour|hrs|hr|h)\b',
  caseSensitive: false,
);

// Bare "2h", "90m", "1h5m", "1h 5m" (hours+minutes combined, with or
// without a space) — no leading "for" needed. Two alternatives: the
// combined hours+minutes form first (more specific — "1h5m" would
// otherwise match the hours-only branch and leave "5m" as a second,
// separate, confusing match), then either unit alone.
final _bareDurationPattern = RegExp(
  r'\b(\d+)\s*h\s*(\d+)\s*m\b'
  r'|\b(\d+)\s*h\b'
  r'|\b(\d+)\s*m\b',
  caseSensitive: false,
);

// "every weekday" / "weekdays" (Mon-Fri), "weekend" / "weekends" /
// "every weekend" (Sat-Sun) — bare forms need no "every" prefix, matching
// how "daily" already works with no prefix required.
final _weekdayGroupPattern = RegExp(
  r'\b(?:every\s+)?weekdays?\b',
  caseSensitive: false,
);
final _weekendGroupPattern = RegExp(
  r'\b(?:every\s+)?weekends?\b',
  caseSensitive: false,
);

// "mon-fri", "mon to fri", "monday to friday", "mon–fri" (en dash) — a
// weekday RANGE, expanded to every day from the first to the second
// inclusive. No "every" prefix required, confirmed directly: the range
// phrasing itself is unambiguous enough not to need one, the same way
// "weekdays" alone (no "every") already reads as recurring.
final _weekdayRangePattern = RegExp(
  r'\b('
  '$_weekdayAlternation'
  r')\s*(?:-|–|to)\s*('
  '$_weekdayAlternation'
  r')\b',
  caseSensitive: false,
);

// "everyday" (one word) alongside the existing "daily" — both bare, no
// "every" prefix grammatically possible since "everyday" already
// contains it.
final _everydayPattern = RegExp(r'\beveryday\b', caseSensitive: false);
final _dailyPattern = RegExp(r'\bdaily\b', caseSensitive: false);

// "every monday" (a single weekday), "every morning" (daily, no weekday).
final _everyWeekdayPattern = RegExp(
  r'\bevery\s+('
  '$_weekdayAlternation'
  r')\b',
  caseSensitive: false,
);
final _everyMorningPattern = RegExp(
  r'\bevery\s+morning\b',
  caseSensitive: false,
);

/// Builds one word-boundary [RegExp] per [Category], matched against the
/// category's own live [Category.name] — deliberately not against
/// arbitrary synonyms, keeping this exactly as predictable as every other
/// bounded-vocabulary pattern here. Replaces the old hardcoded map keyed
/// by the 4 non-general `TaskCategory` enum values: category is now a
/// real, user-extensible entity, so the match patterns have to be built
/// from whatever categories actually exist rather than a closed static
/// set. The built-in General category is excluded by the caller passing
/// it in already filtered, or simply matches like any other name would —
/// nothing here special-cases it, since "General" is a perfectly normal
/// word a user could type and match on its own name like any other.
///
/// [RegExp.escape] guards a user-typed category name that happens to
/// contain regex metacharacters (e.g. "R&D") from being misinterpreted as
/// a pattern rather than literal text.
Map<Category, RegExp> _buildCategoryPatterns(List<Category> categories) => {
  for (final category in categories)
    category: RegExp(
      '\\b${RegExp.escape(category.name)}\\b',
      caseSensitive: false,
    ),
};

/// Parses free-text Quick Capture input into a structured task shape.
///
/// Pure and widget-free, mirroring `overlap_cluster.dart`'s
/// `detectOverlapClusters` and `recurrence_generator.dart`'s
/// `generateRecurrenceInstances` — no I/O, no persistence, fully
/// unit-testable in isolation. The caller decides what to do with the
/// result (auto-create vs. plain capture); this function only extracts.
///
/// **Confidence rule** (the auto-create gate — flagged for review, not a
/// silent default): [QuickCaptureParseResult.isConfident] is true if and
/// only if an explicit, unambiguous date/time ANCHOR was matched — either
/// a relative-day word (`today`, `tomorrow`, `next <weekday>`) or a clock
/// time (`at 10:30`, `3pm`, or now also a bare 24h time like `11:00` with
/// no am/pm at all). A duration phrase, a recurrence phrase, or a category
/// word found with NO such anchor does not make the parse confident, even
/// though something was extracted — "every morning" alone, or "for 30
/// mins" alone, has no defensible single scheduled instant to auto-create
/// against. Category is the one exception that's surfaced regardless of
/// confidence (see [QuickCaptureParseResult.category]'s own doc comment).
///
/// When an anchor IS found:
/// - A relative-day word with no clock time defaults the time-of-day to
///   09:00 — a reasonable placeholder, not a guess at intent beyond "this
///   day." Flagged the same way: an explicit choice, not a silent one.
/// - Duration defaults to [quickCaptureDefaultDurationMinutes] if no
///   duration phrase is present. Recognizes both the explicit `for ...`
///   form and a bare form with no "for" (`2h`, `90m`, `1h5m`/`1h 5m`).
/// - A recurrence phrase, if present alongside an anchor, becomes the
///   returned [RecurrenceRule]: daily for `every morning`/`daily`/
///   `everyday`; weekly on every weekday (Mon-Fri) for `every weekday`/
///   `weekdays`; weekly on Sat-Sun for `weekend`/`weekends`/`every
///   weekend`; weekly on a single day for `every `<weekday>``` (full name
///   or 3-letter abbreviation); weekly across a range (inclusive) for
///   `mon-fri`/`mon to fri`/`monday to friday`-style phrasing.
///
/// [now] is the reference point for "today"/"tomorrow"/"next `<weekday>`"
/// — injected rather than read from `DateTime.now()` internally, so this
/// stays deterministic and testable like every other date-arithmetic
/// function in this codebase (see `recurrence_generator.dart`).
///
/// [categories] is the live category list to match category words against
/// — this function is otherwise pure/widget-free with no provider
/// dependency, so the caller (`quick_capture_sheet.dart`) reads
/// `categoryListProvider` and passes the current list in, rather than this
/// function reaching for it itself.
QuickCaptureParseResult parseQuickCapture(
  String input, {
  required DateTime now,
  required List<Category> categories,
}) {
  final tokens = <QuickCaptureToken>[];
  final consumed = <bool>[for (var i = 0; i < input.length; i++) false];

  void markConsumed(int start, int end) {
    for (var i = start; i < end && i < consumed.length; i++) {
      consumed[i] = true;
    }
  }

  void addToken(RegExpMatch match, QuickCaptureTokenKind kind) {
    tokens.add(
      QuickCaptureToken(start: match.start, end: match.end, kind: kind),
    );
    markConsumed(match.start, match.end);
  }

  // --- Date/time anchor -----------------------------------------------
  DateTime? anchorDate;
  int? explicitHour;
  int? explicitMinute;

  final nextWeekdayMatch = _nextWeekdayPattern.firstMatch(input);
  final tomorrowMatch = _tomorrowPattern.firstMatch(input);
  final todayMatch = _todayPattern.firstMatch(input);

  // Most-specific match wins if more than one relative-day phrase somehow
  // appears — "next monday" before "tomorrow" before "today" — matching
  // the alternation-order intent described above at the top-level match
  // selection, not just within one pattern's own alternatives.
  if (nextWeekdayMatch != null) {
    final targetWeekday = _weekdayIndexOf(nextWeekdayMatch.group(1)!)!;
    anchorDate = _nextWeekday(now, targetWeekday);
    addToken(nextWeekdayMatch, QuickCaptureTokenKind.dateTime);
  } else if (tomorrowMatch != null) {
    anchorDate = DateTime(now.year, now.month, now.day + 1);
    addToken(tomorrowMatch, QuickCaptureTokenKind.dateTime);
  } else if (todayMatch != null) {
    anchorDate = DateTime(now.year, now.month, now.day);
    addToken(todayMatch, QuickCaptureTokenKind.dateTime);
  }

  final clockMatch = _firstUnconsumedMatch(_clockTimePattern, input, consumed);
  if (clockMatch != null) {
    // Three alternatives share this one pattern (see its own doc comment
    // above): groups 1-3 are the "at ..." form, groups 4-6 the bare
    // "3pm"/"10:30am" form, groups 7-8 the bare 24h "11:00" form with no
    // meridiem at all. Exactly one group of alternatives is non-null.
    final hourStr =
        clockMatch.group(1) ?? clockMatch.group(4) ?? clockMatch.group(7)!;
    final minuteStr =
        clockMatch.group(2) ?? clockMatch.group(5) ?? clockMatch.group(8);
    final meridiem = (clockMatch.group(3) ?? clockMatch.group(6))
        ?.toLowerCase();

    var hour = int.parse(hourStr);
    final minute = minuteStr == null ? 0 : int.parse(minuteStr);
    if (meridiem == 'pm' && hour < 12) hour += 12;
    if (meridiem == 'am' && hour == 12) hour = 0;

    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      explicitHour = hour;
      explicitMinute = minute;
      anchorDate ??= DateTime(now.year, now.month, now.day);
      addToken(clockMatch, QuickCaptureTokenKind.dateTime);
    }
  }

  // --- Duration ---------------------------------------------------------
  int? durationMinutes;
  final withForMatch = _firstUnconsumedMatch(
    _durationWithForPattern,
    input,
    consumed,
  );
  if (withForMatch != null) {
    final amount = int.parse(withForMatch.group(1)!);
    final unit = withForMatch.group(2)!.toLowerCase();
    durationMinutes = unit.startsWith('h') ? amount * 60 : amount;
    addToken(withForMatch, QuickCaptureTokenKind.duration);
  } else {
    final bareMatch = _firstUnconsumedMatch(
      _bareDurationPattern,
      input,
      consumed,
    );
    if (bareMatch != null) {
      final hoursAndMinutes = bareMatch.group(1);
      if (hoursAndMinutes != null) {
        // "1h5m" / "1h 5m" combined form.
        final hours = int.parse(hoursAndMinutes);
        final minutes = int.parse(bareMatch.group(2)!);
        durationMinutes = hours * 60 + minutes;
      } else if (bareMatch.group(3) != null) {
        // Hours-only bare form ("2h").
        durationMinutes = int.parse(bareMatch.group(3)!) * 60;
      } else {
        // Minutes-only bare form ("90m").
        durationMinutes = int.parse(bareMatch.group(4)!);
      }
      addToken(bareMatch, QuickCaptureTokenKind.duration);
    }
  }

  // --- Recurrence ---------------------------------------------------------
  RecurrenceRule? recurrenceRule;

  final everydayMatch = _firstUnconsumedMatch(
    _everydayPattern,
    input,
    consumed,
  );
  final dailyMatch = everydayMatch == null
      ? _firstUnconsumedMatch(_dailyPattern, input, consumed)
      : null;
  final everyMorningMatch = (everydayMatch == null && dailyMatch == null)
      ? _firstUnconsumedMatch(_everyMorningPattern, input, consumed)
      : null;
  final weekdayGroupMatch =
      (everydayMatch == null && dailyMatch == null && everyMorningMatch == null)
      ? _firstUnconsumedMatch(_weekdayGroupPattern, input, consumed)
      : null;
  final weekendGroupMatch =
      (everydayMatch == null &&
          dailyMatch == null &&
          everyMorningMatch == null &&
          weekdayGroupMatch == null)
      ? _firstUnconsumedMatch(_weekendGroupPattern, input, consumed)
      : null;
  final weekdayRangeMatch =
      (everydayMatch == null &&
          dailyMatch == null &&
          everyMorningMatch == null &&
          weekdayGroupMatch == null &&
          weekendGroupMatch == null)
      ? _firstUnconsumedMatch(_weekdayRangePattern, input, consumed)
      : null;
  final everyWeekdayMatch =
      (everydayMatch == null &&
          dailyMatch == null &&
          everyMorningMatch == null &&
          weekdayGroupMatch == null &&
          weekendGroupMatch == null &&
          weekdayRangeMatch == null)
      ? _firstUnconsumedMatch(_everyWeekdayPattern, input, consumed)
      : null;

  if (everydayMatch != null) {
    recurrenceRule = RecurrenceRule(frequency: RecurrenceFrequency.daily);
    addToken(everydayMatch, QuickCaptureTokenKind.recurrence);
  } else if (dailyMatch != null) {
    recurrenceRule = RecurrenceRule(frequency: RecurrenceFrequency.daily);
    addToken(dailyMatch, QuickCaptureTokenKind.recurrence);
  } else if (everyMorningMatch != null) {
    recurrenceRule = RecurrenceRule(frequency: RecurrenceFrequency.daily);
    addToken(everyMorningMatch, QuickCaptureTokenKind.recurrence);
  } else if (weekdayGroupMatch != null) {
    recurrenceRule = RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      daysOfWeek: [1, 2, 3, 4, 5],
    );
    addToken(weekdayGroupMatch, QuickCaptureTokenKind.recurrence);
  } else if (weekendGroupMatch != null) {
    recurrenceRule = RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      daysOfWeek: [6, 7],
    );
    addToken(weekendGroupMatch, QuickCaptureTokenKind.recurrence);
  } else if (weekdayRangeMatch != null) {
    final startDay = _weekdayIndexOf(weekdayRangeMatch.group(1)!)!;
    final endDay = _weekdayIndexOf(weekdayRangeMatch.group(2)!)!;
    // Inclusive range, wrapping if the end names an earlier weekday than
    // the start (e.g. a "fri to mon" phrasing) — not expected as normal
    // usage, but the arithmetic falls out for free rather than needing a
    // guard, so it's left to behave consistently rather than rejected.
    final days = <int>[];
    var day = startDay;
    while (true) {
      days.add(day);
      if (day == endDay) break;
      day = day == 7 ? 1 : day + 1;
    }
    recurrenceRule = RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      daysOfWeek: days,
    );
    addToken(weekdayRangeMatch, QuickCaptureTokenKind.recurrence);
  } else if (everyWeekdayMatch != null) {
    final weekday = _weekdayIndexOf(everyWeekdayMatch.group(1)!)!;
    recurrenceRule = RecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      daysOfWeek: [weekday],
    );
    addToken(everyWeekdayMatch, QuickCaptureTokenKind.recurrence);
  }

  // --- Category -----------------------------------------------------------
  // Surfaced regardless of [isConfident] — a category word carries no
  // scheduling ambiguity, unlike a bare duration/recurrence phrase, so
  // there's no reason to withhold it from a non-confident (plain-capture)
  // result the way those two fields are withheld.
  Category? category;
  final categoryPatterns = _buildCategoryPatterns(categories);
  for (final entry in categoryPatterns.entries) {
    final match = _firstUnconsumedMatch(entry.value, input, consumed);
    if (match != null) {
      category = entry.key;
      addToken(match, QuickCaptureTokenKind.category);
      break;
    }
  }

  final isConfident = anchorDate != null;

  // Title: with NO confident anchor, the fallback contract is the ENTIRE
  // raw input untouched (see this function's own doc comment and
  // docs/DECISIONS.md) — a duration or recurrence phrase found in passing
  // does not get silently stripped out of an otherwise-plain-text
  // capture. Only a confident parse removes the matched spans (including
  // any matched category word), leaving whatever text wasn't consumed.
  String title;
  if (isConfident) {
    final titleBuffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      titleBuffer.write(consumed[i] ? ' ' : input[i]);
    }
    final stripped = titleBuffer
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    title = stripped.isEmpty ? input.trim() : stripped;
  } else {
    title = input.trim();
  }

  DateTime? scheduledAt;
  if (anchorDate != null) {
    final date = anchorDate;
    final hour = explicitHour ?? 9;
    final minute = explicitMinute ?? 0;
    scheduledAt = DateTime(date.year, date.month, date.day, hour, minute);
  }

  // Sort tokens by position so the highlighter can walk them in text
  // order without re-sorting itself.
  tokens.sort((a, b) => a.start.compareTo(b.start));

  return QuickCaptureParseResult(
    title: title,
    scheduledAt: scheduledAt,
    // Not confident => neither field is surfaced, even though something
    // may have been matched (e.g. a bare "every morning" or "for 30
    // mins" with no date/time anchor) — see this function's own doc
    // comment for why an unanchored duration/recurrence phrase must not
    // leak into a result the caller might otherwise treat as meaningful.
    durationMinutes: isConfident
        ? (durationMinutes ?? quickCaptureDefaultDurationMinutes)
        : null,
    recurrenceRule: isConfident ? recurrenceRule : null,
    category: category,
    isConfident: isConfident,
    tokens: tokens,
  );
}

/// The first match of [pattern] in [input] whose full span doesn't
/// overlap any already-[consumed] character — so a later pattern (e.g.
/// duration) can't re-claim text a higher-priority pattern (e.g. the
/// date/time anchor) already matched, which matters when phrasing
/// coincidentally overlaps (not expected in practice given the bounded
/// vocabulary here, but cheap to guard against explicitly rather than
/// leaving it to accident).
RegExpMatch? _firstUnconsumedMatch(
  RegExp pattern,
  String input,
  List<bool> consumed,
) {
  for (final match in pattern.allMatches(input)) {
    var overlaps = false;
    for (var i = match.start; i < match.end; i++) {
      if (consumed[i]) {
        overlaps = true;
        break;
      }
    }
    if (!overlaps) return match;
  }
  return null;
}

/// The next date on or after [from] (EXCLUDING [from] itself — "next
/// monday" said on a Monday means the one seven days out, not today)
/// that falls on [targetWeekday] (1 = Monday .. 7 = Sunday).
DateTime _nextWeekday(DateTime from, int targetWeekday) {
  final today = DateTime(from.year, from.month, from.day);
  var daysAhead = targetWeekday - today.weekday;
  if (daysAhead <= 0) daysAhead += 7;
  return DateTime(today.year, today.month, today.day + daysAhead);
}
