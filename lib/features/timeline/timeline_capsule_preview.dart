import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_category.dart';
import '../../shared/models/task_status.dart';
import 'task_capsule_block.dart';

/// SCAFFOLDING — visual-review checkpoint only, not a real screen.
/// Renders a static, hardcoded set of tasks to prove [TaskCapsuleBlock]
/// works across durations, times, and all four category colors before
/// Phase 3 wires it to real timeline layout/state. Per docs/PROJECT_PLAN.md
/// Phase 3 Step 1: stop here, this is a deliberate pause for review.
class TimelineCapsulePreview extends StatelessWidget {
  const TimelineCapsulePreview({super.key});

  static final List<Task> _seedTasks = [
    Task(
      id: 'preview-1',
      title: 'Morning run',
      scheduledAt: DateTime(2026, 8, 20, 7, 0),
      durationMinutes: 30,
      category: TaskCategory.health,
    ),
    Task(
      id: 'preview-2',
      title: 'Team standup',
      scheduledAt: DateTime(2026, 8, 20, 9, 0),
      durationMinutes: 15,
      category: TaskCategory.work,
    ),
    Task(
      id: 'preview-3',
      title: 'Deep work: Amble timeline',
      scheduledAt: DateTime(2026, 8, 20, 10, 0),
      durationMinutes: 120,
      category: TaskCategory.work,
    ),
    Task(
      id: 'preview-4',
      title: 'Call mom',
      scheduledAt: DateTime(2026, 8, 20, 13, 0),
      durationMinutes: 20,
      category: TaskCategory.personal,
      status: TaskStatus.skipped,
    ),
    Task(
      id: 'preview-5',
      title: 'Pay rent',
      scheduledAt: DateTime(2026, 8, 20, 17, 0),
      durationMinutes: 10,
      category: TaskCategory.admin,
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 8, 20, 17, 5),
    ),
  ];

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
            TaskCapsuleBlock(task: task),
            SizedBox(height: theme.spacingBlockGap),
          ],
        ],
      ),
    );
  }
}
