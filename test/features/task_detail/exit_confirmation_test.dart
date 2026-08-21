import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/task_detail_sheet.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_category.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

import '../../support/fake_notification_service.dart';

// Hive's real disk I/O hangs under flutter_test's synchronous pump-based
// zone unless routed through WidgetTester.runAsync — see docs/ERROR_LOG.md.
// Every tap that can trigger a save/delete, and the settle that follows it,
// runs inside the same runAsync zone so the real-time Hive write and the
// pump loop that observes its result don't race across zone boundaries.
Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
    // pumpAndSettle only waits for frames, not real-zone I/O — a mutator's
    // continuation after `await saveTask(...)` (TaskList._refresh) can
    // still be queued on the real event loop here. Drain it explicitly
    // before this runAsync block (and the test) returns, or it resolves
    // later against an already-disposed ProviderContainer. See
    // docs/ERROR_LOG.md.
    await Future<void>.delayed(Duration.zero);
  });
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required Box<Task> box,
  Task? task,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        // TaskDetailForm.close() pops its own route (matching the real app's
        // showTaskDetailSheet, which always pushes it on top of something) —
        // it can't be the Navigator's only route, or popping it has nowhere
        // to go.
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      builder: (context) => TaskDetailForm(
        task: task,
        initialScheduledAt: DateTime(2026, 8, 20, 9),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late Box<Task> box;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_exit_confirmation');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Task>(
      'test_tasks_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await box.close();
  });

  testWidgets(
    'create flow: closing with an empty title closes silently, no dialog',
    (tester) async {
      await _pumpForm(tester, box: box);

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      expect(find.text('Schedule this?'), findsNothing);
      expect(find.byType(TaskDetailForm), findsNothing);
    },
  );

  testWidgets(
    'create flow: title typed but nothing else touched still prompts, '
    'since a title is itself a real change from the empty default',
    (tester) async {
      await _pumpForm(tester, box: box);

      await tester.enterText(find.byType(TextField).first, 'Buy milk');
      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      expect(find.text('Schedule this?'), findsOneWidget);
      expect(find.text('Delete draft'), findsOneWidget);
      expect(find.text('Discard changes'), findsNothing);
    },
  );

  testWidgets(
    'create flow: "Schedule this" saves via the same path as Continue',
    (tester) async {
      await _pumpForm(tester, box: box);

      await tester.enterText(find.byType(TextField).first, 'Buy milk');
      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      await _tapAndSettle(tester, find.text('Schedule this'));

      expect(box.values.single.title, 'Buy milk');
      expect(box.values.single.isScheduled, isTrue);
    },
  );

  testWidgets(
    'create flow: "Delete draft" closes without persisting anything',
    (tester) async {
      await _pumpForm(tester, box: box);

      await tester.enterText(find.byType(TextField).first, 'Buy milk');
      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      await _tapAndSettle(tester, find.text('Delete draft'));

      expect(box.values, isEmpty);
    },
  );

  testWidgets(
    'edit flow: closing with no changes made closes silently, no dialog',
    (tester) async {
      final task = Task.create(
        title: 'Existing task',
        scheduledAt: DateTime(2026, 8, 20, 9),
        durationMinutes: 30,
        category: TaskCategory.personal,
      );
      await tester.runAsync(() => box.put(task.id, task));

      await _pumpForm(tester, box: box, task: task);

      await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

      expect(find.text('Schedule this?'), findsNothing);
    },
  );

  testWidgets('edit flow: a changed field prompts with "Discard changes", not '
      '"Delete draft"', (tester) async {
    final task = Task.create(
      title: 'Existing task',
      scheduledAt: DateTime(2026, 8, 20, 9),
      durationMinutes: 30,
      category: TaskCategory.personal,
    );
    await tester.runAsync(() => box.put(task.id, task));

    await _pumpForm(tester, box: box, task: task);

    await tester.enterText(find.byType(TextField).first, 'Renamed task');
    await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

    expect(find.text('Schedule this?'), findsOneWidget);
    expect(find.text('Discard changes'), findsOneWidget);
    expect(find.text('Delete draft'), findsNothing);
  });

  testWidgets('edit flow: "Discard changes" leaves the originally saved task '
      'untouched — it is not deleted', (tester) async {
    final task = Task.create(
      title: 'Existing task',
      scheduledAt: DateTime(2026, 8, 20, 9),
      durationMinutes: 30,
      category: TaskCategory.personal,
    );
    await tester.runAsync(() => box.put(task.id, task));

    await _pumpForm(tester, box: box, task: task);

    await tester.enterText(find.byType(TextField).first, 'Renamed task');
    await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

    await _tapAndSettle(tester, find.text('Discard changes'));

    expect(box.values.single.title, 'Existing task');
  });

  testWidgets('edit flow: "Schedule this" saves the changed field', (
    tester,
  ) async {
    final task = Task.create(
      title: 'Existing task',
      scheduledAt: DateTime(2026, 8, 20, 9),
      durationMinutes: 30,
      category: TaskCategory.personal,
    );
    await tester.runAsync(() => box.put(task.id, task));

    await _pumpForm(tester, box: box, task: task);

    await tester.enterText(find.byType(TextField).first, 'Renamed task');
    await _tapAndSettle(tester, find.byIcon(Icons.close_rounded));

    await _tapAndSettle(tester, find.text('Schedule this'));

    expect(box.values.single.title, 'Renamed task');
  });
}
