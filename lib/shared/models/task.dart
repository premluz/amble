import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

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
  });

  /// Creates a new scheduled task with a client-generated UUID.
  Task.create({
    required String title,
    String? notes,
    required DateTime scheduledAt,
    required int durationMinutes,
    required TaskCategory category,
  }) : this(
         id: _uuid.v4(),
         title: title,
         notes: notes,
         scheduledAt: scheduledAt,
         durationMinutes: durationMinutes,
         category: category,
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
        schemaVersion == other.schemaVersion;
  }
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
