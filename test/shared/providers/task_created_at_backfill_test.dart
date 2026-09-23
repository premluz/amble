import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';

import '../../support/fake_notification_service.dart';

/// Covers `TaskList.backfillCreatedAtIfNeeded` — the one-time migration
/// requested directly: "notes in inbox should have created timestamp if
/// not have already." Existing on-disk [Task] rows saved before
/// `createdAt` existed read back with the field's own constructor
/// default (`DateTime.now()` at LOAD time) rather than `null` — this
/// migration exists to WRITE that value once so it stops silently
/// recomputing to "now" on every future launch (which would otherwise
/// keep old notes jumping back to the top of the newest-first Inbox
/// sort).
void main() {
  late Box<Task> taskBox;
  late Box<dynamic> prefsBox;
  late ProviderContainer container;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_created_at_backfill');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    prefsBox = await Hive.openBox<dynamic>('test_prefs_$stamp');

    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(prefsBox),
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
    await prefsBox.deleteFromDisk();
  });

  test(
    'sets PreferenceKeys.taskCreatedAtBackfilled after running once',
    () async {
      final prefs = container.read(preferencesRepositoryProvider);
      expect(
        prefs.getValue<bool>(PreferenceKeys.taskCreatedAtBackfilled),
        isNull,
      );

      await container
          .read(taskListProvider.notifier)
          .backfillCreatedAtIfNeeded();

      expect(
        prefs.getValue<bool>(PreferenceKeys.taskCreatedAtBackfilled),
        isTrue,
      );
    },
  );

  test('is a genuine no-op the second time it runs', () async {
    final task = Task.captured(title: 'Buy milk');
    await taskBox.put(task.id, task);

    final notifier = container.read(taskListProvider.notifier);
    await notifier.backfillCreatedAtIfNeeded();
    final firstCreatedAt = container.read(taskListProvider).single.createdAt;

    // A second run must not touch anything already backfilled — no
    // re-stamping "now" again on a later launch.
    await notifier.backfillCreatedAtIfNeeded();
    final secondCreatedAt = container.read(taskListProvider).single.createdAt;

    expect(secondCreatedAt, firstCreatedAt);
  });

  test('multiple pre-existing tasks each end up with a distinct, stable '
      'createdAt after backfilling', () async {
    final first = Task.captured(title: 'First');
    final second = Task.captured(title: 'Second');
    await taskBox.put(first.id, first);
    await taskBox.put(second.id, second);

    await container.read(taskListProvider.notifier).backfillCreatedAtIfNeeded();

    final tasks = container.read(taskListProvider);
    expect(tasks.map((t) => t.createdAt).toSet(), hasLength(2));
  });
}
