import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/task_category.dart';

/// Bridges the persisted [TaskCategory] enum (shared/models/) to the
/// design-system [TaskCategoryToken] enum (core/tokens/) so a [Task] can be
/// rendered without either layer depending on the other.
extension TaskCategoryTokenMapping on TaskCategory {
  TaskCategoryToken get token => switch (this) {
    TaskCategory.general => TaskCategoryToken.general,
    TaskCategory.health => TaskCategoryToken.health,
    TaskCategory.work => TaskCategoryToken.work,
    TaskCategory.personal => TaskCategoryToken.personal,
    TaskCategory.admin => TaskCategoryToken.admin,
  };

  IconData get icon => switch (this) {
    // A neutral mark for "no category chosen" — deliberately not a
    // meaningful glyph, since the whole point is the absence of one.
    TaskCategory.general => Icons.circle_outlined,
    TaskCategory.health => Icons.favorite_rounded,
    TaskCategory.work => Icons.work_rounded,
    TaskCategory.personal => Icons.person_rounded,
    TaskCategory.admin => Icons.checklist_rounded,
  };

  /// The category's emoji glyph — what the user actually sees on a chip
  /// and in a task's badge.
  ///
  /// Emoji rather than [icon]'s Material glyphs, per direct request: they
  /// read as chosen labels rather than system iconography, and they carry
  /// their own colour, which the pale category tints can't. [icon] is
  /// retained for the places a monochrome vector is still the right
  /// primitive (anywhere the glyph must take a tint from its context).
  String get emoji => switch (this) {
    // A plain marker for "no category chosen" — deliberately the least
    // loaded glyph available, since the point is the absence of a
    // category, not a fifth meaning.
    TaskCategory.general => '⚪',
    TaskCategory.health => '⛑️',
    TaskCategory.work => '💼',
    TaskCategory.personal => '🏠',
    TaskCategory.admin => '📋',
  };

  String get label => switch (this) {
    TaskCategory.general => 'General',
    TaskCategory.health => 'Health',
    TaskCategory.work => 'Work',
    TaskCategory.personal => 'Personal',
    TaskCategory.admin => 'Admin',
  };
}
