import '../models/category.dart';

/// Persistence interface for [Category], mirroring
/// [TrackedBehaviorRepository]'s shape. UI and state never call Hive
/// directly — see CONSTITUTION.md's access-pattern rule.
///
/// [deleteCategory] added — requested directly ("Edit category also [add
/// remove icon button]"), reversing the earlier "v1 scope is create +
/// list only, no delete" decision recorded in docs/DECISIONS.md. See
/// [CategoryList.deleteCategory]'s own doc comment for the orphaned-task
/// reassignment this now requires at the notifier layer.
abstract class CategoryRepository {
  List<Category> getCategories();
  Category? getCategoryById(String id);
  Future<void> saveCategory(Category category);
  Future<void> deleteCategory(String id);
}
