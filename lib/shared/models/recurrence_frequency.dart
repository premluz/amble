import 'package:hive_ce/hive_ce.dart';

part 'recurrence_frequency.g.dart';

/// How often a recurring task repeats.
///
/// Deliberately only two values for MVP — monthly/yearly and complex
/// RRULE-style patterns are explicitly deferred (see SCOPE.md's "Deferred
/// beyond MVP"). Kept as its own file/typeId, mirroring how [TaskStatus]
/// and [TaskCategory] are already split out.
@HiveType(typeId: 6)
enum RecurrenceFrequency {
  @HiveField(0)
  daily,
  @HiveField(1)
  weekly,
}
