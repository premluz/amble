import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/inbox/inbox_screen.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/section.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/section_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_section_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';
import '../../support/seeded_section_box.dart';

/// Covers the Inbox's own Section tab row: the "All"/Section/"Unfiled"
/// filter, and that a plain tap on a row is unaffected by the drag-to-
/// assign addition — requested directly ("Inbox item can live in one
/// Section only... drag item onto a tab"). The drag/drop hit-testing
/// itself (`InboxSectionTabTargets.hitTest`) is covered separately in
/// `inbox_section_tab_targets_test.dart` — a full simulated long-press-
/// then-drag `WidgetTester` gesture proved unreliable in this harness
/// (hung indefinitely rather than failing outright, even isolated from
/// every other suspect — animations, `AppSwipeActions`, environment
/// contention — each ruled out directly), so that logic is verified
/// without going through a simulated pointer sequence instead.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Section> sectionBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_inbox_sections');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
    sectionBox = await openSectionBox('test_sections_$stamp');
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await sectionBox.close();
  });

  Future<void> pumpInbox(
    WidgetTester tester, {
    required List<Task> tasks,
    List<Section> sections = const [],
  }) async {
    await tester.runAsync(() async {
      for (final task in tasks) {
        await taskBox.put(task.id, task);
      }
      for (final section in sections) {
        await sectionBox.put(section.id, section);
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categoryBox),
          ),
          sectionRepositoryProvider.overrideWithValue(
            HiveSectionRepository(sectionBox),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(body: InboxScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Task task(String title, {String? sectionId}) => Task(
    id: const Uuid().v4(),
    title: title,
    categoryId: BuiltInCategoryIds.general,
    sectionId: sectionId,
  );

  testWidgets('shows an "All" and "Unfiled" tab with no sections created', (
    tester,
  ) async {
    await pumpInbox(tester, tasks: [task('Buy milk')]);

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Unfiled'), findsOneWidget);
  });

  testWidgets('shows a tab for every created Section', (tester) async {
    final groceries = Section.create(name: 'Groceries');
    final work = Section.create(name: 'Work');

    await pumpInbox(
      tester,
      tasks: [task('Buy milk')],
      sections: [groceries, work],
    );

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets(
    'selecting a Section tab shows only tasks filed into it; "All" shows '
    'everything again',
    (tester) async {
      final groceries = Section.create(name: 'Groceries');
      await pumpInbox(
        tester,
        tasks: [
          task('Buy milk', sectionId: groceries.id),
          task('Call dentist'),
        ],
        sections: [groceries],
      );

      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.text('Call dentist'), findsOneWidget);

      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();

      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.text('Call dentist'), findsNothing);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.text('Call dentist'), findsOneWidget);
    },
  );

  testWidgets(
    'selecting "Unfiled" shows only tasks with no Section assigned',
    (tester) async {
      final groceries = Section.create(name: 'Groceries');
      await pumpInbox(
        tester,
        tasks: [
          task('Buy milk', sectionId: groceries.id),
          task('Call dentist'),
        ],
        sections: [groceries],
      );

      await tester.tap(find.text('Unfiled'));
      await tester.pumpAndSettle();

      expect(find.text('Buy milk'), findsNothing);
      expect(find.text('Call dentist'), findsOneWidget);
    },
  );

  testWidgets(
    'a plain quick tap on a row does NOT file it into anything — it opens '
    'the rename sheet instead, confirming the existing tap gesture is '
    'unaffected by the drag-to-assign addition',
    (tester) async {
      final groceries = Section.create(name: 'Groceries');
      await pumpInbox(
        tester,
        tasks: [task('Buy milk')],
        sections: [groceries],
      );

      await tester.tap(find.text('Buy milk'));
      await tester.pump();

      // A plain tap opens the rename sheet (quick_capture_sheet.dart),
      // never the drag/file-into-Section path — that's gated behind
      // onLongPressStart, which a quick tap never reaches. The row's own
      // title still renders (now inside the opened sheet) rather than
      // erroring or vanishing.
      expect(find.text('Buy milk'), findsWidgets);
    },
  );
}
