import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feature_flags.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_status.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import '../tracked_behavior/behavior_outcome_prompt.dart';

/// Completes (or un-completes) [task], asking for an outcome amount first
/// when it's linked to a tracked behavior.
///
/// **Ordinary tasks are untouched.** Every guard below fails fast for a
/// task with no `behaviorId`, so the ordinary path is exactly the single
/// `toggleComplete(task)` call it has always been — no prompt, no extra
/// await, no added friction (design principle 2). The prompt also never
/// appears when *un*-completing, or for a binary behavior, which has
/// nothing to quantify.
Future<void> completeTask(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final notifier = ref.read(taskListProvider.notifier);

  final isCompleting = task.status != TaskStatus.completed;
  final behaviorId = task.behaviorId;
  if (!FeatureFlags.trackedBehaviorEnabled ||
      !isCompleting ||
      behaviorId == null) {
    await notifier.toggleComplete(task);
    return;
  }

  final behavior = ref
      .read(trackedBehaviorListProvider)
      .where((candidate) => candidate.id == behaviorId)
      .firstOrNull;
  // A dangling link (behavior deleted) must not block completing the task.
  if (behavior == null || !behaviorNeedsOutcomePrompt(behavior)) {
    await notifier.toggleComplete(task);
    return;
  }

  final amount = await showBehaviorOutcomePrompt(context, behavior: behavior);
  // A dismissed prompt still completes the task — `actualAmount` just stays
  // null. Declining to quantify is not declining to finish.
  await notifier.toggleComplete(task, actualAmount: amount);
}
