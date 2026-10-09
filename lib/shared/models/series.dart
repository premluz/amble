import 'package:uuid/uuid.dart';

import 'field_override.dart';
import 'local_date.dart';
import 'series_revision.dart';

/// One repeating thing ("Run, weekdays 07:00"), owning its rule
/// independently of any occurrence — deleting an occurrence can never delete
/// or orphan it (docs/RECURRENCE_CONTRACT.md §1).
///
/// Immutable. Every change returns a new value with [version] + 1, which the
/// repository checks to reject stale writes (§12).
class Series {
  Series({
    required this.id,
    required this.anchor,
    required List<SeriesRevision> revisions,
    required this.createdAt,
    required this.updatedAt,
    this.endsAfter,
    this.version = initialVersion,
  }) : revisions = List.unmodifiable(revisions) {
    if (revisions.isEmpty) throw ArgumentError('A series needs a revision');
    if (revisions.first.effectiveFrom != anchor) {
      throw ArgumentError('The first revision must start on the anchor');
    }
    for (var i = 1; i < revisions.length; i++) {
      if (!revisions[i].effectiveFrom.isAfter(revisions[i - 1].effectiveFrom)) {
        throw ArgumentError('Revisions must be in strictly increasing order');
      }
    }
  }

  factory Series.create({
    required SeriesRevision firstRevision,
    required DateTime now,
  }) => Series(
    id: const Uuid().v4(),
    anchor: firstRevision.effectiveFrom,
    revisions: [firstRevision],
    createdAt: now,
    updatedAt: now,
  );

  static const initialVersion = 1;
  static const schemaVersion = 1;

  final String id;

  /// The series' first date. Interval cadence (every 2 days/weeks) is always
  /// counted from here, not from a later revision — so a time change from
  /// week 5 keeps an every-other-week rhythm (§8 question 1).
  final LocalDate anchor;

  /// Oldest first; the first starts on [anchor].
  final List<SeriesRevision> revisions;

  /// Last date with occurrences, inclusive. Null = open-ended.
  final LocalDate? endsAfter;

  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  /// The revision that applied on [date]; null before the series started.
  SeriesRevision? revisionOn(LocalDate date) {
    SeriesRevision? applicable;
    for (final revision in revisions) {
      if (revision.effectiveFrom.isAfter(date)) break;
      applicable = revision;
    }
    return applicable;
  }

  /// Adds [revision], replacing any revisions starting on or after its date.
  ///
  /// Callers pick the date with [effectiveDateFor] so a series edit never
  /// reaches the past (D4a).
  Series withRevision(SeriesRevision revision, {required DateTime now}) {
    if (revision.effectiveFrom.isBefore(anchor)) {
      throw ArgumentError('A revision cannot start before the series');
    }
    final kept = revisions
        .where((r) => r.effectiveFrom.isBefore(revision.effectiveFrom))
        .toList();
    return _copy(revisions: [...kept, revision], now: now);
  }

  /// Ends the series after [lastDate] (inclusive).
  Series endedAfter(LocalDate lastDate, {required DateTime now}) =>
      _copy(revisions: revisions, endsAfter: lastDate, now: now);

  /// When an edit made from [occurrenceDate] takes effect: that date, or
  /// [today] if it is in the past (§7 — anything earlier is a historical
  /// correction, D4b).
  static LocalDate effectiveDateFor(
    LocalDate occurrenceDate,
    LocalDate today,
  ) => occurrenceDate.isBefore(today) ? today : occurrenceDate;

  Series _copy({
    required List<SeriesRevision> revisions,
    required DateTime now,
    LocalDate? endsAfter,
  }) => Series(
    id: id,
    anchor: anchor,
    revisions: revisions,
    createdAt: createdAt,
    updatedAt: now,
    endsAfter: endsAfter ?? this.endsAfter,
    version: version + 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'anchor': anchor.toIso(),
    'revisions': revisions.map((r) => r.toJson()).toList(),
    'endsAfter': endsAfter?.toIso(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
    'schemaVersion': schemaVersion,
  };

  factory Series.fromJson(Map<String, dynamic> json) {
    final rawRevisions = json['revisions'];
    final endsAfter = json['endsAfter'];
    if (json['schemaVersion'] != schemaVersion || rawRevisions is! List) {
      throw const FormatException('Series.fromJson: unsupported shape');
    }
    try {
      return Series(
        id: decodeString(json['id']),
        anchor: LocalDate.parse(decodeString(json['anchor'])),
        revisions: [for (final raw in rawRevisions) _decodeRevision(raw)],
        endsAfter: endsAfter == null
            ? null
            : LocalDate.parse(decodeString(endsAfter)),
        createdAt: DateTime.parse(decodeString(json['createdAt'])),
        updatedAt: DateTime.parse(decodeString(json['updatedAt'])),
        version: decodeInt(json['version']),
      );
    } on ArgumentError catch (error) {
      throw FormatException('Series.fromJson: ${error.message}');
    }
  }

  static SeriesRevision _decodeRevision(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Series.fromJson: invalid revision');
    }
    return SeriesRevision.fromJson(Map<String, dynamic>.from(raw));
  }
}
