import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

part 'task_template.g.dart';

const _uuid = Uuid();

/// A reusable, non-schedulable blueprint for tasks the user creates
/// repeatedly (e.g. "Take a walk") — its own entity, own Hive box
/// (`task_templates`), own repository, exactly the shape [Category]/`Zone`
/// already established.
///
/// Deliberately task-shaped but never itself schedulable or completable:
/// no `scheduledAt`, no `status`, no `completedAt`. Spawning a task from a
/// template is a COPY, not a reference — see `TaskList.createTask`'s
/// `templateId`, which is recorded on the spawned [Task] purely so a
/// future quick-drop drawer can frequency-rank templates. Nothing points
/// back at a template, which is why (unlike [Category]/`Zone`) a template
/// is freely deletable with no orphaned-reference problem to solve. See
/// CONSTITUTION.md's "TaskTemplate" section.
@HiveType(typeId: 12)
class TaskTemplate extends HiveObject {
  TaskTemplate({
    required this.id,
    required this.title,
    required this.categoryId,
    this.durationMinutes,
    this.notes,
    this.behaviorId,
    this.schemaVersion = 1,
  });

  /// Creates a new template with a client-generated UUID — the same `uuid`
  /// call [Task.create]/[Category.create] use, per the Constitution's "IDs
  /// are client-generated UUIDs from day one" rule.
  TaskTemplate.create({
    required String title,
    required String categoryId,
    int? durationMinutes,
    String? notes,
    String? behaviorId,
  }) : this(
         id: _uuid.v4(),
         title: title,
         categoryId: categoryId,
         durationMinutes: durationMinutes,
         notes: notes,
         behaviorId: behaviorId,
       );

  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  /// References a persisted [Category] row — required, same as [Task]'s own
  /// `categoryId` on [Task.create]. Resolved through `categoryListProvider`,
  /// never read as anything but a link.
  @HiveField(2)
  String categoryId;

  /// A default duration to prefill on a spawned task, not an enforced one —
  /// null means "no suggestion," and the detail sheet's own duration field
  /// stays empty for the user to fill in.
  @HiveField(3)
  int? durationMinutes;

  @HiveField(4)
  String? notes;

  /// Links this template to a `TrackedBehavior`, carried forward onto any
  /// [Task] spawned from it. Null for an ordinary template — the unchanged
  /// default, same pattern as [Task.behaviorId].
  @HiveField(5)
  String? behaviorId;

  @HiveField(6)
  int schemaVersion;

  /// Serializes every persisted field to a JSON-safe map. Hand-written,
  /// matching [Task.toJson]/[Category.toJson]'s style — the model is small
  /// and stable enough that this avoids a new dependency, per CLAUDE.md.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'categoryId': categoryId,
    'durationMinutes': durationMinutes,
    'notes': notes,
    'behaviorId': behaviorId,
    'schemaVersion': schemaVersion,
  };

  /// Reconstructs a [TaskTemplate] from [toJson]'s output. Throws
  /// [FormatException] if a required field is missing or malformed —
  /// matches [Category.fromJson]'s fail-loud-on-malformed-input convention.
  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final categoryId = json['categoryId'];
    final schemaVersion = json['schemaVersion'];
    if (id is! String || id.isEmpty) {
      throw const FormatException(
        'TaskTemplate.fromJson: missing or invalid "id"',
      );
    }
    if (title is! String) {
      throw const FormatException(
        'TaskTemplate.fromJson: missing or invalid "title"',
      );
    }
    if (categoryId is! String || categoryId.isEmpty) {
      throw const FormatException(
        'TaskTemplate.fromJson: missing or invalid "categoryId"',
      );
    }
    if (schemaVersion is! int) {
      throw const FormatException(
        'TaskTemplate.fromJson: missing or invalid "schemaVersion"',
      );
    }
    return TaskTemplate(
      id: id,
      title: title,
      categoryId: categoryId,
      durationMinutes: json['durationMinutes'] as int?,
      notes: json['notes'] as String?,
      behaviorId: json['behaviorId'] as String?,
      schemaVersion: schemaVersion,
    );
  }

  /// Field-by-field equality, deliberately not `==` — this is a
  /// [HiveObject] subclass, and overriding `==`/`hashCode` would risk
  /// interfering with Hive's own key-based identity semantics. Mirrors
  /// [Task.hasSameFieldsAs]'s role and reasoning exactly.
  bool hasSameFieldsAs(TaskTemplate other) {
    return title == other.title &&
        categoryId == other.categoryId &&
        durationMinutes == other.durationMinutes &&
        notes == other.notes &&
        behaviorId == other.behaviorId &&
        schemaVersion == other.schemaVersion;
  }
}
