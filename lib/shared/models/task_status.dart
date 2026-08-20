import 'package:hive_ce/hive_ce.dart';

part 'task_status.g.dart';

@HiveType(typeId: 1)
enum TaskStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  completed,
  @HiveField(2)
  skipped,
  @HiveField(3)
  rescheduled,
}
