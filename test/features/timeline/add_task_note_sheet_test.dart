import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/add_task_note_sheet.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

import '../../support/fake_notification_service.dart';

/// The quick note-entry sheet opened by swiping right on a Timeline task
/// row — see task_capsule_swipe_test.dart for the swipe gesture itself.
/// Real Hive writes here (per docs/ERROR_LOG.md, hang under flutter_test's
/// synchronous zone without runAsync), so every save is wrapped in it.
void main() {
  late Box<Task> box;
  late ProviderContainer container;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_add_task_note_sheet');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    box = await Hive.openBox<Task>('test_tasks_$stamp');
    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await box.deleteFromDisk();
  });

  Future<void> pumpSheet(WidgetTester tester, Task task) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAddTaskNoteSheet(context, task),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the task title and starts empty for a task with no '
      'existing note', (tester) async {
    final task = Task.create(
      title: 'Deep work',
      scheduledAt: DateTime(2026, 9, 4, 9),
      durationMinutes: 90,
      categoryId: BuiltInCategoryIds.work,
    );
    await tester.runAsync(() => box.put(task.id, task));

    await pumpSheet(tester, task);

    expect(find.text('Deep work'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('starts pre-filled with the task\'s existing note', (
    tester,
  ) async {
    final task = Task.create(
      title: 'Deep work',
      scheduledAt: DateTime(2026, 9, 4, 9),
      durationMinutes: 90,
      categoryId: BuiltInCategoryIds.work,
    )..notes = 'Already has a note';
    await tester.runAsync(() => box.put(task.id, task));

    await pumpSheet(tester, task);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Already has a note');
  });

  testWidgets('typing a note and saving persists it to the task\'s own '
      'per-occurrence row and closes the sheet', (tester) async {
    final task = Task.create(
      title: 'Deep work',
      scheduledAt: DateTime(2026, 9, 4, 9),
      durationMinutes: 90,
      categoryId: BuiltInCategoryIds.work,
    );
    await tester.runAsync(() => box.put(task.id, task));

    await pumpSheet(tester, task);
    await tester.enterText(find.byType(TextField), 'Went well today');

    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await tester.pump();
      await Future<void>.delayed(Duration.zero);
      await tester.pumpAndSettle();
    });

    final saved = box.get(task.id)!;
    expect(saved.notes, 'Went well today');
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('saving an emptied note clears it back to null, matching '
      'the Task Detail sheet\'s own empty-means-null convention', (
    tester,
  ) async {
    final task = Task.create(
      title: 'Deep work',
      scheduledAt: DateTime(2026, 9, 4, 9),
      durationMinutes: 90,
      categoryId: BuiltInCategoryIds.work,
    )..notes = 'Old note';
    await tester.runAsync(() => box.put(task.id, task));

    await pumpSheet(tester, task);
    await tester.enterText(find.byType(TextField), '');

    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await tester.pump();
      await Future<void>.delayed(Duration.zero);
      await tester.pumpAndSettle();
    });

    final saved = box.get(task.id)!;
    expect(saved.notes, isNull);
  });
}
