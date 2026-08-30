import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

import 'recurrence_rule.dart';
import 'task_category.dart';
import 'task_status.dart';

part 'task.g.dart';

const _uuid = Uuid();

@HiveType(typeId: 0)
class Task extends HiveObject {
  Task({
    required this.id,
    required this.title,
    this.notes,
    this.scheduledAt,
    this.durationMinutes,
    this.originalScheduledAt,
    this.status = TaskStatus.pending,
    this.completedAt,
    required this.category,
    this.schemaVersion = 1,
    this.behaviorId,
    this.actualAmount,
    this.recurrenceId,
    this.recurrenceRule,
    this.notificationsEnabled = true,
  });

  /// Creates a new scheduled task with a client-generated UUID.
  ///
  /// [recurrenceId]/[recurrenceRule] are how a recurring series is built:
  /// the template instance carries both, and every materialized instance
  /// carries the same [recurrenceId] with a null rule. Both default to
  /// null, so an ordinary task is entirely unaffected.
  Task.create({
    required String title,
    String? notes,
    required DateTime scheduledAt,
    required int durationMinutes,
    required TaskCategory category,
    String? recurrenceId,
    RecurrenceRule? recurrenceRule,
    bool notificationsEnabled = true,
  }) : this(
         id: _uuid.v4(),
         title: title,
         notes: notes,
         scheduledAt: scheduledAt,
         durationMinutes: durationMinutes,
         category: category,
         recurrenceId: recurrenceId,
         recurrenceRule: recurrenceRule,
         notificationsEnabled: notificationsEnabled,
       );

  /// Creates a new unscheduled (Inbox) task with a client-generated UUID.
  /// Per design principle 2 (capture is frictionless), only a title is
  /// required — category defaults to [TaskCategory.personal] and can be
  /// changed later, when/if the task is scheduled.
  Task.captured({required String title, String? notes})
    : this(
        id: _uuid.v4(),
        title: title,
        notes: notes,
        category: TaskCategory.personal,
      );

  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? notes;

  /// Null for an unscheduled (Inbox) task. See [isScheduled].
  @HiveField(3)
  DateTime? scheduledAt;

  /// Null for an unscheduled (Inbox) task. See [isScheduled].
  @HiveField(4)
  int? durationMinutes;

  @HiveField(5)
  DateTime? originalScheduledAt;

  @HiveField(6)
  TaskStatus status;

  @HiveField(7)
  DateTime? completedAt;

  @HiveField(8)
  TaskCategory category;

  @HiveField(9)
  int schemaVersion;

  /// Links this task to a [TrackedBehavior] it belongs to. Null for an
  /// ordinary task — the unchanged default, so nothing about an ordinary
  /// task's lifecycle is affected. See CONSTITUTION.md.
  @HiveField(10)
  String? behaviorId;

  /// The recorded outcome against the behavior's target (e.g. 30 of a
  /// 60-minute target). Meaningful only when [behaviorId] is set; null
  /// otherwise. Partial performance is expressed numerically here rather
  /// than as a fifth [TaskStatus] value, so ordinary tasks are never
  /// affected by tracked-behavior concerns — see CONSTITUTION.md.
  @HiveField(11)
  num? actualAmount;

  /// Identifies the recurring series this task belongs to. Null for an
  /// ordinary, non-repeating task — the unchanged default. Every
  /// materialized instance of a series shares this value.
  @HiveField(12)
  String? recurrenceId;

  /// The repeat rule, present **only** on the template (first) instance of
  /// a series — later instances reference the series via [recurrenceId]
  /// alone, per CONSTITUTION.md. Null on an ordinary task and on every
  /// non-template instance.
  @HiveField(13)
  RecurrenceRule? recurrenceRule;

  /// Whether a reminder notification should fire for this task's start
  /// time. Defaults to `true` — matching [NotificationService]'s previous
  /// unconditional behavior, so a task saved before this field existed
  /// (which Hive deserializes with the default) keeps getting notified
  /// exactly as it always did. `false` is a real, deliberate opt-out, not
  /// the historical default.
  @HiveField(14)
  bool notificationsEnabled;

  /// True when this task is an instance of a [TrackedBehavior] rather than
  /// a standalone task.
  bool get isBehaviorInstance => behaviorId != null;

  /// True when this task belongs to a recurring series — used by the
  /// Timeline to show its recurrence indicator. True for every instance,
  /// template or not.
  bool get isRecurring => recurrenceId != null;

  /// True only for the one instance that carries the series' rule.
  bool get isRecurrenceTemplate => recurrenceRule != null;

  /// True once this task has a [scheduledAt]/[durationMinutes] — i.e. it
  /// has left the Inbox and appears on the Timeline. Both fields are set
  /// together (see [TaskList.scheduleTask]), so checking either suffices.
  bool get isScheduled => scheduledAt != null && durationMinutes != null;

  /// Serializes every persisted field to a JSON-safe map, for export. Not
  /// generated (`json_serializable`) — the model is small and stable enough
  /// that hand-writing this avoids a new dependency, per CLAUDE.md.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'scheduledAt': scheduledAt?.toIso8601String(),
    'durationMinutes': durationMinutes,
    'originalScheduledAt': originalScheduledAt?.toIso8601String(),
    'status': status.name,
    'completedAt': completedAt?.toIso8601String(),
    'category': category.name,
    'schemaVersion': schemaVersion,
    'behaviorId': behaviorId,
    'actualAmount': actualAmount,
    'recurrenceId': recurrenceId,
    'recurrenceRule': recurrenceRule?.toJson(),
    'notificationsEnabled': notificationsEnabled,
  };

  /// Reconstructs a [Task] from [toJson]'s output, for import. Throws
  /// [FormatException] if a required field is missing or malformed — the
  /// caller (import validation) is expected to catch this per-task and
  /// report it, never let a bad record corrupt the rest of the import.
  factory Task.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final categoryName = json['category'];
    final statusName = json['status'];
    final schemaVersion = json['schemaVersion'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Task.fromJson: missing or invalid "id"');
    }
    if (title is! String) {
      throw const FormatException('Task.fromJson: missing or invalid "title"');
    }
    if (categoryName is! String) {
      throw const FormatException(
        'Task.fromJson: missing or invalid "category"',
      );
    }
    if (statusName is! String) {
      throw const FormatException('Task.fromJson: missing or invalid "status"');
    }
    if (schemaVersion is! int) {
      throw const FormatException(
        'Task.fromJson: missing or invalid "schemaVersion"',
      );
    }

    final category = _enumValueByName(TaskCategory.values, categoryName);
    if (category == null) {
      throw FormatException(
        'Task.fromJson: unrecognized "category" value "$categoryName"',
      );
    }
    final status = _enumValueByName(TaskStatus.values, statusName);
    if (status == null) {
      throw FormatException(
        'Task.fromJson: unrecognized "status" value "$statusName"',
      );
    }

    return Task(
      id: id,
      title: title,
      notes: json['notes'] as String?,
      scheduledAt: _parseNullableDateTime(json['scheduledAt']),
      durationMinutes: json['durationMinutes'] as int?,
      originalScheduledAt: _parseNullableDateTime(json['originalScheduledAt']),
      status: status,
      completedAt: _parseNullableDateTime(json['completedAt']),
      category: category,
      schemaVersion: schemaVersion,
      // Deliberately not validated as required: backup files exported
      // before these fields existed simply omit them, and must still
      // import cleanly. A wrong *type* still fails loudly via the cast,
      // consistent with how every other optional field here behaves.
      behaviorId: json['behaviorId'] as String?,
      actualAmount: json['actualAmount'] as num?,
      recurrenceId: json['recurrenceId'] as String?,
      recurrenceRule: _parseNullableRule(json['recurrenceRule']),
      // A backup exported before this field existed simply omits it —
      // matching the historical unconditional-notification behavior on
      // import is what `?? true` gives, the same default the constructor
      // and the Hive adapter both use for old data.
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    );
  }

  /// Field-by-field equality, deliberately not `==` — this is a
  /// [HiveObject] subclass, and overriding `==`/`hashCode` would risk
  /// interfering with Hive's own key-based identity semantics. Used by
  /// import to distinguish "already have this exact task" from "same id,
  /// different content" (a real conflict). Compares every persisted field
  /// except [id] itself, which the caller already knows matches.
  bool hasSameFieldsAs(Task other) {
    return title == other.title &&
        notes == other.notes &&
        scheduledAt == other.scheduledAt &&
        durationMinutes == other.durationMinutes &&
        originalScheduledAt == other.originalScheduledAt &&
        status == other.status &&
        completedAt == other.completedAt &&
        category == other.category &&
        schemaVersion == other.schemaVersion &&
        behaviorId == other.behaviorId &&
        actualAmount == other.actualAmount &&
        recurrenceId == other.recurrenceId &&
        _sameRule(recurrenceRule, other.recurrenceRule) &&
        notificationsEnabled == other.notificationsEnabled;
  }
}

/// Reads an optional embedded [RecurrenceRule]. Absent/null is valid (an
/// ordinary task, or a backup exported before recurrence existed); a
/// present-but-malformed value still fails loudly, matching how every other
/// field here behaves.
RecurrenceRule? _parseNullableRule(dynamic value) {
  if (value == null) return null;
  if (value is! Map) {
    throw const FormatException('Task.fromJson: invalid "recurrenceRule"');
  }
  return RecurrenceRule.fromJson(Map<String, dynamic>.from(value));
}

bool _sameRule(RecurrenceRule? a, RecurrenceRule? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a.hasSameFieldsAs(b);
}

DateTime? _parseNullableDateTime(dynamic value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Task.fromJson: invalid date field');
  }
  return DateTime.parse(value);
}

T? _enumValueByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
