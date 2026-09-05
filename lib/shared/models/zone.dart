import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

import 'recurrence_rule.dart';

part 'zone.g.dart';

const _uuid = Uuid();

/// A named, time-boxed container a [Task] can optionally be assigned into
/// (e.g. "Morning ritual," 07:00–08:00) — a separate, persistent entity,
/// same "own model, own Hive box, own repository" shape as
/// [TrackedBehavior]. See CONSTITUTION.md's "Zone" section for the full
/// design.
///
/// [startMinutes]/[endMinutes] describe one time-of-day window, not a
/// specific date. [recurrenceRule] optionally repeats that same window on
/// a schedule (same time every occurrence) — see its own doc comment for
/// what's implemented vs. still deferred.
///
/// Additive and inert until a Zone UI exists — see `core/feature_flags.dart`.
@HiveType(typeId: 9)
class Zone extends HiveObject {
  Zone({
    required this.id,
    required this.title,
    required this.startMinutes,
    required this.endMinutes,
    this.schemaVersion = 1,
    this.recurrenceRule,
    this.notificationsEnabled = true,
  }) : assert(
         startMinutes >= 0 && startMinutes < _minutesPerDay,
         'startMinutes must be within a single day (0-1439)',
       ),
       assert(
         endMinutes > startMinutes && endMinutes <= _minutesPerDay,
         'endMinutes must be after startMinutes and within the day',
       );

  /// Creates a new zone with a client-generated UUID — same `uuid` call
  /// [Task.create] and [TrackedBehavior.create] use, per the Constitution's
  /// "IDs are client-generated UUIDs from day one" rule.
  Zone.create({
    required String title,
    required int startMinutes,
    required int endMinutes,
    RecurrenceRule? recurrenceRule,
    bool notificationsEnabled = true,
  }) : this(
         id: _uuid.v4(),
         title: title,
         startMinutes: startMinutes,
         endMinutes: endMinutes,
         recurrenceRule: recurrenceRule,
         notificationsEnabled: notificationsEnabled,
       );

  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  /// Start of the window, in minutes since midnight (0-1439). Time-of-day,
  /// not a specific date — see the class doc comment.
  ///
  /// Stored as a plain minutes-since-midnight [int] rather than Flutter's
  /// `TimeOfDay` — `TimeOfDay` has no Hive adapter, and the codebase already
  /// treats "hours * 60 + minutes" as the boundary representation for time
  /// of day (see `AppSegmentedTimeField`'s doc comment). Flagged here as the
  /// chosen representation, not assumed.
  @HiveField(2)
  int startMinutes;

  /// End of the window, in minutes since midnight (1-1440). Always greater
  /// than [startMinutes] — enforced by the constructor's assert.
  @HiveField(3)
  int endMinutes;

  @HiveField(4)
  int schemaVersion;

  /// Simple recurrence only: reuses [RecurrenceRule]'s shape as-is (same
  /// start/end time on every occurrence) — confirmed directly with the user
  /// as the scope for this pass, NOT the per-occurrence-adjustable-times
  /// version CONSTITUTION.md flags as a still-deferred future fork. Null
  /// means non-recurring, today's only behavior, unaffected default.
  @HiveField(5)
  RecurrenceRule? recurrenceRule;

  /// Whether an alert fires at this zone's start time — same mechanism as
  /// [Task.notificationsEnabled]. Defaults true (notified by default,
  /// opt-out not opt-in), matching a newly created task's own default.
  @HiveField(6)
  bool notificationsEnabled;

  /// Derived, never stored — so duration can never drift from the two times
  /// that define it, per CONSTITUTION.md.
  int get durationMinutes => endMinutes - startMinutes;

  /// Serializes every persisted field to a JSON-safe map, for export.
  /// Hand-written, matching [Task.toJson]/[Category.toJson]'s style — not
  /// generated, per the same "small and stable enough to avoid a new
  /// dependency" reasoning.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
    'schemaVersion': schemaVersion,
    'recurrenceRule': recurrenceRule?.toJson(),
    'notificationsEnabled': notificationsEnabled,
  };

  /// Reconstructs a [Zone] from [toJson]'s output, for import. Throws
  /// [FormatException] if a required field is missing or malformed —
  /// matches [Task.fromJson]/[Category.fromJson]'s fail-loud-on-malformed-
  /// input convention.
  factory Zone.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final startMinutes = json['startMinutes'];
    final endMinutes = json['endMinutes'];
    final schemaVersion = json['schemaVersion'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Zone.fromJson: missing or invalid "id"');
    }
    if (title is! String) {
      throw const FormatException('Zone.fromJson: missing or invalid "title"');
    }
    if (startMinutes is! int) {
      throw const FormatException(
        'Zone.fromJson: missing or invalid "startMinutes"',
      );
    }
    if (endMinutes is! int) {
      throw const FormatException(
        'Zone.fromJson: missing or invalid "endMinutes"',
      );
    }
    if (schemaVersion is! int) {
      throw const FormatException(
        'Zone.fromJson: missing or invalid "schemaVersion"',
      );
    }
    final recurrenceRuleJson = json['recurrenceRule'];
    RecurrenceRule? recurrenceRule;
    if (recurrenceRuleJson != null) {
      if (recurrenceRuleJson is! Map) {
        throw const FormatException('Zone.fromJson: invalid "recurrenceRule"');
      }
      recurrenceRule = RecurrenceRule.fromJson(
        Map<String, dynamic>.from(recurrenceRuleJson),
      );
    }
    return Zone(
      id: id,
      title: title,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      schemaVersion: schemaVersion,
      recurrenceRule: recurrenceRule,
      // Deliberately optional, not required — a backup exported before
      // this field existed simply omits it, and must still import cleanly,
      // matching the historical unconditional-notification default (the
      // constructor's own `= true`), same "old exports still import"
      // contract every other optional Task/Category field already has.
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }

  /// Field-by-field equality, deliberately not `==` — this is a
  /// [HiveObject] subclass, and overriding `==`/`hashCode` would risk
  /// interfering with Hive's own key-based identity semantics. Used by
  /// import to distinguish "already have this exact zone" from "same id,
  /// different content" (a real conflict) — matches [Task.hasSameFieldsAs]'s
  /// exact contract; confirmed directly, since Zone (unlike Category) has
  /// real edit capability, so a re-imported zone with the same id but
  /// changed fields is a genuinely reachable case, not a hypothetical.
  /// Compares every persisted field except [id] itself, which the caller
  /// already knows matches.
  bool hasSameFieldsAs(Zone other) {
    return title == other.title &&
        startMinutes == other.startMinutes &&
        endMinutes == other.endMinutes &&
        schemaVersion == other.schemaVersion &&
        _sameRule(recurrenceRule, other.recurrenceRule) &&
        notificationsEnabled == other.notificationsEnabled;
  }

  static const _minutesPerDay = 24 * 60;
}

bool _sameRule(RecurrenceRule? a, RecurrenceRule? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a.hasSameFieldsAs(b);
}
