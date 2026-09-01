import '../models/category.dart';

/// Persistence interface for [Category], mirroring
/// [TrackedBehaviorRepository]'s shape. UI and state never call Hive
/// directly — see CONSTITUTION.md's access-pattern rule.
///
/// No delete method — v1 scope is create + list only, per the confirmed
/// decision recorded in docs/DECISIONS.md.
abstract class CategoryRepository {
  List<Category> getCategories();
  Category? getCategoryById(String id);
  Future<void> saveCategory(Category category);
}
