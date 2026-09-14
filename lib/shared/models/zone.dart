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
    this.recurrenceId,
    this.anchorDate,
    this.weekday,
    this.facetId,
    this.archived = false,
    this.effectiveFrom,
    this.sourceId,
    this.effectiveUntil,
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
    String? recurrenceId,
    DateTime? anchorDate,
  }) : this(
         id: _uuid.v4(),
         title: title,
         startMinutes: startMinutes,
         endMinutes: endMinutes,
         recurrenceRule: recurrenceRule,
         notificationsEnabled: notificationsEnabled,
         recurrenceId: recurrenceId,
         anchorDate: anchorDate,
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

  /// The series link for a materialized recurring instance — same shape as
  /// [Task.recurrenceId]: null for a non-recurring zone (unaffected, still
  /// just one row, no series concept applies), set to the same id shared by
  /// every instance of a series otherwise. See
  /// `shared/services/zone_recurrence_generator.dart` for how instances are
  /// generated.
  @HiveField(7)
  String? recurrenceId;

  /// The specific calendar day this materialized instance occupies. Null
  /// for a non-recurring zone — that shape is UNCHANGED from before this
  /// session: a single dateless row that applies to every day (see
  /// `resolveZoneContainment`'s `_zoneAppliesOnDay`). Set on every instance
  /// of a recurring series, including its own template — mirrors
  /// [Task.scheduledAt] acting as both "this instance's own occurrence"
  /// and the anchor `zone_recurrence_generator.dart` walks forward from.
  /// Confirmed directly: giving even non-recurring zones a date was ruled
  /// out as out-of-scope broadening — see docs/DECISIONS.md.
  @HiveField(8)
  DateTime? anchorDate;

  /// Weekly placements are independent windows; the facet owns only the name.
  @HiveField(9)
  int? weekday;

  @HiveField(10)
  String? facetId;

  /// Retained legacy rows preserve IDs/export history without rendering twice.
  @HiveField(11)
  bool archived;

  @HiveField(12)
  DateTime? effectiveFrom;

  /// Original series/plain-row ID, for preserved dated exceptions and aliases.
  @HiveField(13)
  String? sourceId;

  @HiveField(14)
  DateTime? effectiveUntil;

  bool get isWeeklyPlacement => weekday != null;

  bool appliesOn(DateTime day) {
    if (archived) return false;
    final date = DateTime(day.year, day.month, day.day);
    if (effectiveUntil != null && !date.isBefore(effectiveUntil!)) return false;
    if (weekday != null) {
      return day.weekday == weekday &&
          (effectiveFrom == null || !date.isBefore(effectiveFrom!));
    }
    final anchor = anchorDate;
    return anchor == null ||
        (anchor.year == day.year && anchor.month == day.month && anchor.day == day.day);
  }

  /// True when this row belongs to a recurring series (materialized
  /// instance or template) — mirrors [Task.isRecurring] exactly.
  bool get isRecurring => recurrenceId != null;

  /// True when this row is the template carrying the series' own
  /// [recurrenceRule] — mirrors [Task.isRecurrenceTemplate] exactly. Later
  /// instances share [recurrenceId] but never repeat the rule.
  bool get isRecurrenceTemplate => recurrenceRule != null;

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
    'recurrenceId': recurrenceId,
    'anchorDate': anchorDate?.toIso8601String(),
    'weekday': weekday,
    'facetId': facetId,
    'archived': archived,
    'effectiveFrom': effectiveFrom?.toIso8601String(),
    'sourceId': sourceId,
    'effectiveUntil': effectiveUntil?.toIso8601String(),
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
    final weekday = json['weekday'];
    if (weekday != null && (weekday is! int || weekday < 1 || weekday > 7)) {
      throw const FormatException('Invalid zone weekday');
    }
    return Zone(
      weekday: weekday as int?,
      facetId: json['facetId'] as String?,
      archived: json['archived'] as bool? ?? false,
      effectiveFrom: json['effectiveFrom'] == null ? null : DateTime.parse(json['effectiveFrom'] as String),
      sourceId: json['sourceId'] as String?,
      effectiveUntil: json['effectiveUntil'] == null ? null : DateTime.parse(json['effectiveUntil'] as String),
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
      // Both deliberately optional, not required — a backup exported
      // before this session still imports cleanly as a non-recurring zone,
      // same "old exports still import" contract as every other optional
      // field on this model.
      recurrenceId: json['recurrenceId'] as String?,
      anchorDate: (json['anchorDate'] as String?) == null
          ? null
          : DateTime.parse(json['anchorDate'] as String),
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
    return effectiveUntil == other.effectiveUntil && weekday == other.weekday && facetId == other.facetId &&
        archived == other.archived && effectiveFrom == other.effectiveFrom &&
        sourceId == other.sourceId && title == other.title &&
        startMinutes == other.startMinutes &&
        endMinutes == other.endMinutes &&
        schemaVersion == other.schemaVersion &&
        _sameRule(recurrenceRule, other.recurrenceRule) &&
        notificationsEnabled == other.notificationsEnabled &&
        recurrenceId == other.recurrenceId &&
        anchorDate == other.anchorDate;
  }

  static const _minutesPerDay = 24 * 60;
}

bool _sameRule(RecurrenceRule? a, RecurrenceRule? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a.hasSameFieldsAs(b);
}
