import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

import 'recurrence_rule.dart';
import 'scheduled_block.dart';
import 'task_category.dart';
import 'task_status.dart';

part 'task.g.dart';

const _uuid = Uuid();

@HiveType(typeId: 0)
class Task extends HiveObject implements ScheduledBlock {
  Task({
    required this.id,
    required this.title,
    this.notes,
    this.scheduledAt,
    this.durationMinutes,
    this.originalScheduledAt,
    this.status = TaskStatus.pending,
    this.completedAt,
    this.category = TaskCategory.general,
    this.schemaVersion = 1,
    this.behaviorId,
    this.actualAmount,
    this.recurrenceId,
    this.recurrenceRule,
    this.notificationsEnabled = true,
    this.categoryId,
    this.zoneId,
    this.externalEventId,
    this.templateId,
    this.isImportant = false,
  });

  /// Creates a new scheduled task with a client-generated UUID.
  ///
  /// [categoryId] is required — every NEW task must reference a real
  /// persisted [Category] row (see `shared/models/category.dart`); the old
  /// [category] enum parameter is no longer accepted here. [category]
  /// itself stays at its default (`TaskCategory.general`) for disk-compat
  /// only — see its own field doc comment.
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
    required String categoryId,
    String? recurrenceId,
    RecurrenceRule? recurrenceRule,
    bool notificationsEnabled = true,
    String? templateId,
    bool isImportant = false,
  }) : this(
         id: _uuid.v4(),
         title: title,
         notes: notes,
         scheduledAt: scheduledAt,
         durationMinutes: durationMinutes,
         recurrenceId: recurrenceId,
         recurrenceRule: recurrenceRule,
         notificationsEnabled: notificationsEnabled,
         categoryId: categoryId,
         templateId: templateId,
         isImportant: isImportant,
       );

  /// Creates a new unscheduled (Inbox) task with a client-generated UUID.
  /// Per design principle 2 (capture is frictionless), only a title is
  /// required — [categoryId] stays null (uncategorised) and can be set
  /// later, when/if the task is scheduled.
  Task.captured({required String title, String? notes})
    : this(id: _uuid.v4(), title: title, notes: notes);

  @override
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

  /// The old fixed-taxonomy category. Superseded by [categoryId], which
  /// references a real, user-extensible [Category] row instead.
  ///
  /// Deliberately NOT removed, renumbered, or repurposed — Hive adapters
  /// key on field number, so retiring or reusing `@HiveField(8)` would
  /// silently corrupt/misread already-installed users' persisted data (see
  /// docs/ERROR_LOG.md and docs/DECISIONS.md's established rule on this,
  /// most recently exercised by the `notificationsEnabled` addition). Kept
  /// on the model for disk-compat only: still populated on old rows, still
  /// serialized in [toJson]/[fromJson] for backward-compatible export, but
  /// no longer read by any real UI — [categoryId] is authoritative for
  /// every current task. See docs/DECISIONS.md for the seed/backfill
  /// migration that resolves old [category] values to a [categoryId] once,
  /// at launch.
  @Deprecated(
    'Superseded by categoryId. Kept only for Hive field-index stability '
    'and old-export JSON compat — do not read this for new UI.',
  )
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

  /// References a persisted [Category] row (`shared/models/category.dart`)
  /// — the replacement for the deprecated [category] enum field. Null only
  /// for an unscheduled Inbox task that hasn't been categorised yet (see
  /// [Task.captured]) or a pre-migration row not yet backfilled; every
  /// task created via [Task.create] has one. Resolved through
  /// `categoryListProvider`/[CategoryRepository], never read directly off
  /// this id — the id is just the link.
  @HiveField(15)
  String? categoryId;

  /// Links this task to a [Zone] it's assigned into. Null for an ordinary
  /// task — the unchanged default, same pattern as [behaviorId]. A real
  /// reference (`taskId` → `zoneId`), never derived from checking whether
  /// [scheduledAt] falls inside a zone's window: a task can be assigned to a
  /// zone with no [scheduledAt] at all. See CONSTITUTION.md's "Zone"
  /// section.
  @HiveField(16)
  String? zoneId;

  /// The id of the device calendar event this task was pushed to via manual
  /// "Sync to Calendar" (see CONSTITUTION.md's "Calendar" section, Feature
  /// 2). Null for a task that has never been synced — the unchanged
  /// default, same pattern as [zoneId]/[behaviorId]. Set the first time
  /// `CalendarSyncService` creates a device event for this task, then
  /// reused on every later sync to update that same event rather than
  /// creating a duplicate. Strictly one-directional (Amble -> device
  /// calendar) — never read back to detect calendar-side edits.
  @HiveField(17)
  String? externalEventId;

  /// The id of the [TaskTemplate] this task was spawned from. Null for an
  /// ordinary task — the unchanged default, same additive/inert pattern as
  /// [zoneId]/[behaviorId].
  ///
  /// **Informational only.** Recorded purely so a future quick-drop drawer
  /// can frequency-rank templates by how often each has been used. It is
  /// never consulted for cascade, delete, or validation logic: spawning is
  /// a COPY, not a reference (see CONSTITUTION.md's "TaskTemplate"
  /// section), so deleting the template this points at is a no-op for this
  /// task, and a dangling id here is expected rather than an error.
  @HiveField(18)
  String? templateId;

  /// Marks the small set of tasks that matter most on a given day.
  /// Additive and inert when unset — same pattern as [zoneId]/[behaviorId]/
  /// [templateId] above: `false` on every existing row, and nothing in the
  /// app's behavior changes until a task is actually marked.
  ///
  /// **Display-only.** Confirmed directly, narrowing an earlier draft that
  /// also gave important tasks cascade-anchor priority and a soft cap at 3
  /// per day: "actually.. no restrictions. just icon in front of the task".
  /// So this is deliberately NOT consulted by `computeCascadeMoves`, by any
  /// overlap check, or by any validation — an important task is pushed,
  /// moved, resized, and edited exactly like any other, and there is no
  /// limit on how many can be marked. It renders a marker icon and nothing
  /// more.
  ///
  /// Orthogonal to [behaviorId] and to recurrence: a tracked task can also
  /// be important, and (per CONSTITUTION.md's recurring-edit scope) marking
  /// one materialized instance important does not mark its whole series —
  /// it is an ordinary per-instance field like any other.
  @HiveField(19)
  bool isImportant;

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

  /// [ScheduledBlock] conformance — every call site already requires
  /// [isScheduled] before touching layout (`layoutOverlappingTasks`/
  /// `detectOverlapClusters`'s own doc comments), so asserting here (via
  /// `!`) rather than returning a nullable matches the precondition that
  /// already existed everywhere these values were read directly.
  @override
  DateTime get scheduledStart => scheduledAt!;

  @override
  DateTime get scheduledEnd =>
      scheduledAt!.add(Duration(minutes: durationMinutes!));

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
    // ignore: deprecated_member_use_from_same_package
    'category': category.name,
    'schemaVersion': schemaVersion,
    'behaviorId': behaviorId,
    'actualAmount': actualAmount,
    'recurrenceId': recurrenceId,
    'recurrenceRule': recurrenceRule?.toJson(),
    'notificationsEnabled': notificationsEnabled,
    'categoryId': categoryId,
    'zoneId': zoneId,
    'externalEventId': externalEventId,
    'templateId': templateId,
    'isImportant': isImportant,
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
      // ignore: deprecated_member_use_from_same_package
      category: category,
      schemaVersion: schemaVersion,
      // Deliberately not validated as required: backup files exported
      // before these fields existed simply omit them, and must still
      // import cleanly. A wrong *type* still fails loudly via the cast,
      // consistent with how every other optional field here behaves.
      behaviorId: json['behaviorId'] as String?,
      // Also deliberately optional/nullable, not required — a backup
      // exported before Category existed has no categoryId at all, and
      // must still import cleanly per the same "old exports still import"
      // contract as every other field added after Task's initial shape.
      categoryId: json['categoryId'] as String?,
      actualAmount: json['actualAmount'] as num?,
      recurrenceId: json['recurrenceId'] as String?,
      recurrenceRule: _parseNullableRule(json['recurrenceRule']),
      // A backup exported before this field existed simply omits it —
      // matching the historical unconditional-notification behavior on
      // import is what `?? true` gives, the same default the constructor
      // and the Hive adapter both use for old data.
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      // Deliberately optional, not required — a backup exported before
      // Zone existed has no zoneId at all, and must still import cleanly,
      // same "old exports still import" contract as categoryId/behaviorId.
      zoneId: json['zoneId'] as String?,
      // Same "old exports still import" contract — a backup exported
      // before Calendar sync existed has no externalEventId at all.
      externalEventId: json['externalEventId'] as String?,
      // Same "old exports still import" contract — a backup exported
      // before TaskTemplate existed has no templateId at all.
      templateId: json['templateId'] as String?,
      // Same "old exports still import" contract — a backup exported
      // before the important flag existed has no isImportant at all, and
      // must import as an ordinary (unmarked) task rather than failing.
      isImportant: json['isImportant'] as bool? ?? false,
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
        // ignore: deprecated_member_use_from_same_package
        category == other.category &&
        schemaVersion == other.schemaVersion &&
        behaviorId == other.behaviorId &&
        actualAmount == other.actualAmount &&
        recurrenceId == other.recurrenceId &&
        _sameRule(recurrenceRule, other.recurrenceRule) &&
        notificationsEnabled == other.notificationsEnabled &&
        categoryId == other.categoryId &&
        zoneId == other.zoneId &&
        externalEventId == other.externalEventId &&
        templateId == other.templateId &&
        isImportant == other.isImportant;
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
