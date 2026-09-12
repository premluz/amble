import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/category.dart';
import 'category_repository.dart';

class HiveCategoryRepository implements CategoryRepository {
  HiveCategoryRepository(this._box);

  final Box<Category> _box;

  @override
  List<Category> getCategories() => _box.values.toList();

  @override
  Category? getCategoryById(String id) => _box.get(id);

  @override
  Future<void> saveCategory(Category category) =>
      _box.put(category.id, category);

  @override
  Future<void> deleteCategory(String id) => _box.delete(id);
}
