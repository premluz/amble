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

  /// The neutral default a task starts with when the user hasn't picked a
  /// category — grey rather than one of the four meaningful colours, so an
  /// uncategorised task doesn't misrepresent itself as Health/Work/etc.
  ///
  /// Deliberately appended as field 4 rather than inserted first, even
  /// though it renders first in the picker: [HiveField] indices are the
  /// persisted values, so renumbering would silently re-map every existing
  /// task's category. Display order is the picker's concern, not the
  /// enum's — see `orderedForPicker`.
  @HiveField(4)
  general,
}

/// Category order as shown in the create flow's picker: the neutral
/// default first (it's what a new task starts as), then the four
/// meaningful categories in their existing order.
extension TaskCategoryPickerOrder on TaskCategory {
  static List<TaskCategory> get orderedForPicker => const [
    TaskCategory.general,
    TaskCategory.health,
    TaskCategory.work,
    TaskCategory.personal,
    TaskCategory.admin,
  ];
}
