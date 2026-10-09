import 'field_override.dart';
import 'local_date.dart';
import 'occurrence_key.dart';
import 'occurrence_plan_overrides.dart';

/// What the user explicitly said happened. "Omitted" and "upcoming" are not
/// here — they are computed from time, never stored (contract §5).
enum OccurrenceOutcome { none, skipped, done, cancelled }

/// Everything known about one occurrence beyond its series revision
/// (contract §1, §5, §6). Holds current state only — each write replaces it,
/// and nothing records intermediate writes (D7).
///
/// Immutable; every change returns a new value with [version] + 1.
class OccurrenceRecord {
  OccurrenceRecord({
    required this.key,
    required this.updatedAt,
    this.plan = const OccurrencePlanOverrides(),
    this.outcome = OccurrenceOutcome.none,
    this.completionDate,
    this.outcomeRecordedAt,
    this.measuredValue,
    this.note,
    this.version = initialVersion,
  }) {
    if ((outcome == OccurrenceOutcome.done) != (completionDate != null)) {
      throw ArgumentError('completionDate is set exactly when outcome is done');
    }
    if ((outcome == OccurrenceOutcome.none) != (outcomeRecordedAt == null)) {
      throw ArgumentError('outcomeRecordedAt is set exactly with an outcome');
    }
  }

  static const initialVersion = 1;
  static const schemaVersion = 1;

  final OccurrenceKey key;
  final OccurrencePlanOverrides plan;
  final OccurrenceOutcome outcome;

  /// Local date the occurrence was completed — may differ from [key]'s date
  /// when it was moved or completed late. Metrics choose which to credit (D8).
  final LocalDate? completionDate;

  /// When the outcome was recorded; lets "marked done late" be known (D4c).
  final DateTime? outcomeRecordedAt;

  /// A measured amount (e.g. 30 minutes). Independent of [outcome]: a value
  /// can exist without "done", and whether it counts as success is a future
  /// streak policy (D5).
  final num? measuredValue;

  final String? note;
  final DateTime updatedAt;
  final int version;

  /// User-entered facts that keep a record visible even on a date its series
  /// no longer expects (contract §9).
  bool get hasContent =>
      outcome == OccurrenceOutcome.done ||
      outcome == OccurrenceOutcome.skipped ||
      measuredValue != null ||
      note != null;

  /// Nothing differs from the series — indistinguishable from an occurrence
  /// that was never touched (§6).
  bool get isEmpty =>
      plan.isEmpty && outcome == OccurrenceOutcome.none && !hasContent;

  OccurrenceRecord withOutcome(
    OccurrenceOutcome outcome, {
    required DateTime now,
    LocalDate? completionDate,
  }) => _copy(
    now: now,
    outcome: outcome,
    completionDate: completionDate,
    outcomeRecordedAt: outcome == OccurrenceOutcome.none ? null : now,
  );

  OccurrenceRecord withNote(String? note, {required DateTime now}) =>
      _copy(now: now, note: note);

  OccurrenceRecord withMeasuredValue(num? value, {required DateTime now}) =>
      _copy(now: now, measuredValue: value);

  OccurrenceRecord withPlan(
    OccurrencePlanOverrides plan, {
    required DateTime now,
  }) => _copy(now: now, plan: plan);

  OccurrenceRecord _copy({
    required DateTime now,
    OccurrencePlanOverrides? plan,
    OccurrenceOutcome? outcome,
    LocalDate? completionDate,
    DateTime? outcomeRecordedAt,
    Object? measuredValue = _unchanged,
    Object? note = _unchanged,
  }) {
    final changesOutcome = outcome != null;
    return OccurrenceRecord(
      key: key,
      updatedAt: now,
      plan: plan ?? this.plan,
      outcome: outcome ?? this.outcome,
      completionDate: changesOutcome ? completionDate : this.completionDate,
      outcomeRecordedAt: changesOutcome
          ? outcomeRecordedAt
          : this.outcomeRecordedAt,
      measuredValue: measuredValue is num? ? measuredValue : this.measuredValue,
      note: note is String? ? note : this.note,
      version: version + 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key.toJson(),
    'plan': plan.toJson(),
    'outcome': outcome.name,
    'completionDate': completionDate?.toIso(),
    'outcomeRecordedAt': outcomeRecordedAt?.toIso8601String(),
    'measuredValue': measuredValue,
    'note': note,
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
    'schemaVersion': schemaVersion,
  };

  factory OccurrenceRecord.fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    final plan = json['plan'];
    final value = json['measuredValue'];
    if (json['schemaVersion'] != schemaVersion ||
        key is! Map ||
        plan is! Map ||
        (value != null && value is! num)) {
      throw const FormatException('OccurrenceRecord.fromJson: invalid shape');
    }
    try {
      return OccurrenceRecord(
        key: OccurrenceKey.fromJson(Map<String, dynamic>.from(key)),
        plan: OccurrencePlanOverrides.fromJson(Map<String, dynamic>.from(plan)),
        outcome: _decodeOutcome(json['outcome']),
        completionDate: _optional(json['completionDate'], LocalDate.parse),
        outcomeRecordedAt: _optional(json['outcomeRecordedAt'], DateTime.parse),
        measuredValue: value is num ? value : null,
        note: _optional(json['note'], (text) => text),
        updatedAt: DateTime.parse(decodeString(json['updatedAt'])),
        version: decodeInt(json['version']),
      );
    } on ArgumentError catch (error) {
      throw FormatException('OccurrenceRecord.fromJson: ${error.message}');
    }
  }
}

/// Sentinel for "leave unchanged" where null is a meaningful new value.
const Object _unchanged = Object();

OccurrenceOutcome _decodeOutcome(Object? raw) {
  for (final value in OccurrenceOutcome.values) {
    if (value.name == raw) return value;
  }
  throw FormatException('Unknown occurrence outcome "$raw"');
}

T? _optional<T>(Object? raw, T Function(String value) parse) =>
    raw == null ? null : parse(decodeString(raw));
