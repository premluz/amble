import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/category.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_status.dart';
import 'task_capsule_block.dart';

/// SCAFFOLDING — visual-review checkpoint only, not a real screen.
/// Renders a static, hardcoded set of tasks to prove [TaskCapsuleBlock]
/// works across durations, times, and all four category colors before
/// Phase 3 wires it to real timeline layout/state. Per docs/PROJECT_PLAN.md
/// Phase 3 Step 1: stop here, this is a deliberate pause for review.
///
/// Uses `categoryId` (the fixed built-in UUIDs) rather than the deprecated
/// `Task.category` enum field — this file is a real, checked-in fixture
/// (the golden test renders it), not a `*_main.dart` dev scaffold, so it's
/// held to the same "don't read the deprecated field" bar as production
/// code. [TaskCapsuleBlock] resolves the built-in's color/emoji from a
/// [Category] passed straight in, mirroring how [TimelineScreen] resolves
/// one via `categoryListProvider` for a real, running app.
class TimelineCapsulePreview extends StatelessWidget {
  const TimelineCapsulePreview({super.key});

  static final List<Task> _seedTasks = [
    Task(
      id: 'preview-1',
      title: 'Morning run',
      scheduledAt: DateTime(2026, 8, 20, 7, 0),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.health,
    ),
    Task(
      id: 'preview-2',
      title: 'Team standup',
      scheduledAt: DateTime(2026, 8, 20, 9, 0),
      durationMinutes: 15,
      categoryId: BuiltInCategoryIds.work,
    ),
    Task(
      id: 'preview-3',
      title: 'Deep work: Amble timeline',
      scheduledAt: DateTime(2026, 8, 20, 10, 0),
      durationMinutes: 120,
      categoryId: BuiltInCategoryIds.work,
    ),
    Task(
      id: 'preview-4',
      title: 'Call mom',
      scheduledAt: DateTime(2026, 8, 20, 13, 0),
      durationMinutes: 20,
      categoryId: BuiltInCategoryIds.personal,
      status: TaskStatus.skipped,
    ),
    Task(
      id: 'preview-5',
      title: 'Pay rent',
      scheduledAt: DateTime(2026, 8, 20, 17, 0),
      durationMinutes: 10,
      categoryId: BuiltInCategoryIds.admin,
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 8, 20, 17, 5),
    ),
  ];

  static final Map<String, Category> _builtInCategories = {
    BuiltInCategoryIds.general: Category(
      id: BuiltInCategoryIds.general,
      name: 'General',
      colorToken: 0,
      emoji: '⚪',
      isBuiltIn: true,
    ),
    BuiltInCategoryIds.health: Category(
      id: BuiltInCategoryIds.health,
      name: 'Health',
      colorToken: 0,
      emoji: '⛑️',
      isBuiltIn: true,
    ),
    BuiltInCategoryIds.work: Category(
      id: BuiltInCategoryIds.work,
      name: 'Work',
      colorToken: 0,
      emoji: '💼',
      isBuiltIn: true,
    ),
    BuiltInCategoryIds.personal: Category(
      id: BuiltInCategoryIds.personal,
      name: 'Personal',
      colorToken: 0,
      emoji: '🏠',
      isBuiltIn: true,
    ),
    BuiltInCategoryIds.admin: Category(
      id: BuiltInCategoryIds.admin,
      name: 'Admin',
      colorToken: 0,
      emoji: '📋',
      isBuiltIn: true,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Container(
      color: theme.colorSurfaceTimeline,
      padding: EdgeInsets.all(theme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final task in _seedTasks) ...[
            TaskCapsuleBlock(
              task: task,
              category: _builtInCategories[task.categoryId],
            ),
            SizedBox(height: theme.spacingBlockGap),
          ],
        ],
      ),
    );
  }
}
