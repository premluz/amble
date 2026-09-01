import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/tracked_behavior/behavior_outcome_prompt.dart';
import 'package:amble/shared/models/behavior_target_type.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';

import '../../support/fake_notification_service.dart';

void main() {
  late Box<Task> taskBox;
  late Box<TrackedBehavior> behaviorBox;
  late ProviderContainer container;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_behavior_link');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    behaviorBox = await Hive.openBox<TrackedBehavior>('test_behaviors_$stamp');

    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
        trackedBehaviorRepositoryProvider.overrideWithValue(
          HiveTrackedBehaviorRepository(behaviorBox),
        ),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await taskBox.deleteFromDisk();
    await behaviorBox.deleteFromDisk();
  });

  group('ordinary tasks are completely unaffected', () {
    test('createTask without a behaviorId leaves the link null', () async {
      await container
          .read(taskListProvider.notifier)
          .createTask(
            title: 'Ordinary task',
            scheduledAt: DateTime(2026, 8, 21, 9),
            durationMinutes: 30,
            categoryId: BuiltInCategoryIds.work,
          );

      final task = container.read(taskListProvider).single;
      expect(task.behaviorId, isNull);
      expect(task.actualAmount, isNull);
      expect(task.isBehaviorInstance, isFalse);
    });

    test('completing an ordinary task records no amount and behaves exactly as '
        'before — same single-argument call, unchanged result', () async {
      final notifier = container.read(taskListProvider.notifier);
      await notifier.createTask(
        title: 'Ordinary task',
        scheduledAt: DateTime(2026, 8, 21, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );

      await notifier.toggleComplete(container.read(taskListProvider).single);

      final task = container.read(taskListProvider).single;
      expect(task.status, TaskStatus.completed);
      expect(task.completedAt, isNotNull);
      expect(task.actualAmount, isNull);
    });
  });

  group('linking and outcome recording', () {
    test('createTask with a behaviorId links the task', () async {
      await container
          .read(trackedBehaviorListProvider.notifier)
          .createBehavior(
            title: 'Exercise',
            targetType: BehaviorTargetType.duration,
            targetAmount: 60,
            timesPerWeek: 3,
          );
      final behavior = container.read(trackedBehaviorListProvider).single;

      await container
          .read(taskListProvider.notifier)
          .createTask(
            title: 'Morning run',
            scheduledAt: DateTime(2026, 8, 21, 7),
            durationMinutes: 60,
            categoryId: BuiltInCategoryIds.health,
            behaviorId: behavior.id,
          );

      final task = container.read(taskListProvider).single;
      expect(task.behaviorId, behavior.id);
      expect(task.isBehaviorInstance, isTrue);
    });

    test('completing with an actualAmount records it', () async {
      final notifier = container.read(taskListProvider.notifier);
      await notifier.createTask(
        title: 'Morning run',
        scheduledAt: DateTime(2026, 8, 21, 7),
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.health,
        behaviorId: 'behavior-1',
      );

      await notifier.toggleComplete(
        container.read(taskListProvider).single,
        actualAmount: 30,
      );

      final task = container.read(taskListProvider).single;
      expect(task.status, TaskStatus.completed);
      expect(task.actualAmount, 30);
    });

    test('completing a linked task without an amount still completes it — '
        'declining to quantify is not declining to finish', () async {
      final notifier = container.read(taskListProvider.notifier);
      await notifier.createTask(
        title: 'Morning run',
        scheduledAt: DateTime(2026, 8, 21, 7),
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.health,
        behaviorId: 'behavior-1',
      );

      await notifier.toggleComplete(container.read(taskListProvider).single);

      final task = container.read(taskListProvider).single;
      expect(task.status, TaskStatus.completed);
      expect(task.actualAmount, isNull);
    });

    test('un-completing clears a previously recorded amount', () async {
      final notifier = container.read(taskListProvider.notifier);
      await notifier.createTask(
        title: 'Morning run',
        scheduledAt: DateTime(2026, 8, 21, 7),
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.health,
        behaviorId: 'behavior-1',
      );
      await notifier.toggleComplete(
        container.read(taskListProvider).single,
        actualAmount: 45,
      );
      expect(container.read(taskListProvider).single.actualAmount, 45);

      // Toggle back to pending.
      await notifier.toggleComplete(container.read(taskListProvider).single);

      final task = container.read(taskListProvider).single;
      expect(task.status, TaskStatus.pending);
      expect(task.completedAt, isNull);
      expect(
        task.actualAmount,
        isNull,
        reason:
            'an amount describing a completion that no longer stands '
            'would misreport history',
      );
    });
  });

  group('outcome prompt applicability', () {
    test('a binary behavior needs no amount prompt', () {
      final binary = TrackedBehavior.create(
        title: 'Take vitamins',
        targetType: BehaviorTargetType.binary,
        timesPerWeek: 7,
      );
      expect(behaviorNeedsOutcomePrompt(binary), isFalse);
    });

    test('duration and count behaviors do need the prompt', () {
      final duration = TrackedBehavior.create(
        title: 'Exercise',
        targetType: BehaviorTargetType.duration,
        targetAmount: 60,
        timesPerWeek: 3,
      );
      final count = TrackedBehavior.create(
        title: 'Read',
        targetType: BehaviorTargetType.count,
        targetAmount: 20,
        timesPerWeek: 7,
      );
      expect(behaviorNeedsOutcomePrompt(duration), isTrue);
      expect(behaviorNeedsOutcomePrompt(count), isTrue);
    });
  });

  test('a recurring series inherits the behavior link on every instance', () {
    // Composition per CONSTITUTION.md: recurring and tracked-behavior are
    // independent, and a series linked to a behavior means every occurrence
    // is an instance of it.
    final template = Task.create(
      title: 'Morning run',
      scheduledAt: DateTime(2026, 8, 21, 7),
      durationMinutes: 60,
      categoryId: BuiltInCategoryIds.health,
      recurrenceId: 'series-1',
    )..behaviorId = 'behavior-1';

    expect(template.behaviorId, 'behavior-1');
    expect(template.isRecurring, isTrue);
    expect(template.isBehaviorInstance, isTrue);
  });
}
