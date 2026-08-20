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
    required this.scheduledAt,
    required this.durationMinutes,
    this.originalScheduledAt,
    this.status = TaskStatus.pending,
    this.completedAt,
    required this.category,
    this.schemaVersion = 1,
  });

  /// Creates a new task with a client-generated UUID.
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

  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? notes;

  @HiveField(3)
  DateTime scheduledAt;

  @HiveField(4)
  int durationMinutes;

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
}
