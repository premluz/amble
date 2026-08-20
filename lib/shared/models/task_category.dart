import 'package:hive_ce/hive_ce.dart';

part 'task_category.g.dart';

/// Semantic task category, mapped to colors via the Tier 2 token layer.
/// Not a free-pick color value — see DECISIONS.md.
@HiveType(typeId: 2)
enum TaskCategory {
  @HiveField(0)
  health,
  @HiveField(1)
  work,
  @HiveField(2)
  personal,
  @HiveField(3)
  admin,
}
