import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/section.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/repositories/category_repository.dart';
import 'package:amble/shared/repositories/section_repository.dart';
import 'package:amble/shared/repositories/task_repository.dart';

/// Session-scoped repositories for Atlas previews; they never open Amble's Hive boxes.
class AtlasMemoryTaskRepository implements TaskRepository {
  AtlasMemoryTaskRepository(Iterable<Task> tasks)
    : _tasks = {for (final task in tasks) task.id: task};

  final Map<String, Task> _tasks;

  @override
  List<Task> getTasks() => List<Task>.unmodifiable(_tasks.values);

  @override
  Task? getTaskById(String id) => _tasks[id];

  @override
  Future<void> saveTask(Task task) async {
    _tasks[task.id] = task;
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }
}

class AtlasMemorySectionRepository implements SectionRepository {
  AtlasMemorySectionRepository(Iterable<Section> sections)
    : _sections = {for (final section in sections) section.id: section};

  final Map<String, Section> _sections;

  @override
  List<Section> getSections() => List<Section>.unmodifiable(_sections.values);

  @override
  Section? getSectionById(String id) => _sections[id];

  @override
  Future<void> saveSection(Section section) async {
    _sections[section.id] = section;
  }

  @override
  Future<void> deleteSection(String id) async {
    _sections.remove(id);
  }
}

class AtlasMemoryCategoryRepository implements CategoryRepository {
  AtlasMemoryCategoryRepository(Iterable<Category> categories)
    : _categories = {for (final category in categories) category.id: category};

  final Map<String, Category> _categories;

  @override
  List<Category> getCategories() =>
      List<Category>.unmodifiable(_categories.values);

  @override
  Category? getCategoryById(String id) => _categories[id];

  @override
  Future<void> saveCategory(Category category) async {
    _categories[category.id] = category;
  }

  @override
  Future<void> deleteCategory(String id) async {
    _categories.remove(id);
  }
}
