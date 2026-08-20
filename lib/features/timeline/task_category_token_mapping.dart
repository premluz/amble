import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/task_category.dart';

/// Bridges the persisted [TaskCategory] enum (shared/models/) to the
/// design-system [TaskCategoryToken] enum (core/tokens/) so a [Task] can be
/// rendered without either layer depending on the other.
extension TaskCategoryTokenMapping on TaskCategory {
  TaskCategoryToken get token => switch (this) {
    TaskCategory.health => TaskCategoryToken.health,
    TaskCategory.work => TaskCategoryToken.work,
    TaskCategory.personal => TaskCategoryToken.personal,
    TaskCategory.admin => TaskCategoryToken.admin,
  };

  IconData get icon => switch (this) {
    TaskCategory.health => Icons.favorite_rounded,
    TaskCategory.work => Icons.work_rounded,
    TaskCategory.personal => Icons.person_rounded,
    TaskCategory.admin => Icons.checklist_rounded,
  };

  String get label => switch (this) {
    TaskCategory.health => 'Health',
    TaskCategory.work => 'Work',
    TaskCategory.personal => 'Personal',
    TaskCategory.admin => 'Admin',
  };
}
