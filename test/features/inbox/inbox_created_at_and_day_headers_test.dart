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

/// Covers the three things requested directly for Inbox notes: "notes in
/// inbox should have created timestamp if not have already... and recent
/// should be on top... and all tab should have subtle label separating
/// day created's (Mono space font) Today / Yesterday / Wednesday / Fri 12
/// Oct." `dayLabel` itself (the label TEXT for each relative day) is unit
/// tested in isolation in `test/shared/services/day_label_test.dart` —
/// this file covers the Inbox's own sort order and where headers actually
/// land in the rendered list.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<Section> sectionBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_inbox_created_at');
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

  Future<ProviderContainer> pumpInbox(
    WidgetTester tester, {
    required List<Task> tasks,
  }) async {
    late ProviderContainer container;
    await tester.runAsync(() async {
      for (final task in tasks) {
        await taskBox.put(task.id, task);
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
        child: Consumer(
          builder: (context, ref, child) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: [AmbleTheme.light],
              ),
              home: const Scaffold(body: InboxScreen()),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  Task noteAt(String title, DateTime createdAt) => Task(
    id: const Uuid().v4(),
    title: title,
    categoryId: BuiltInCategoryIds.general,
    createdAt: createdAt,
  );

  testWidgets('a newly captured task gets a real createdAt, not left null', (
    tester,
  ) async {
    final before = DateTime.now();
    final task = Task.captured(title: 'Buy milk');
    final after = DateTime.now();

    expect(
      task.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
      isTrue,
    );
    expect(
      task.createdAt.isBefore(after.add(const Duration(seconds: 1))),
      isTrue,
    );
  });

  testWidgets('the Inbox list shows the most recently created note FIRST', (
    tester,
  ) async {
    final now = DateTime.now();
    final oldest = noteAt('Oldest', now.subtract(const Duration(days: 2)));
    final middle = noteAt('Middle', now.subtract(const Duration(hours: 5)));
    final newest = noteAt('Newest', now);

    // Saved in a deliberately scrambled order — the OLD sort
    // (reversing Hive's insertion order) would get this wrong; a real
    // createdAt-based sort must not care what order they were written
    // in.
    await pumpInbox(tester, tasks: [middle, oldest, newest]);

    final titles = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    final newestIndex = titles.indexOf('Newest');
    final middleIndex = titles.indexOf('Middle');
    final oldestIndex = titles.indexOf('Oldest');

    expect(newestIndex, greaterThanOrEqualTo(0));
    expect(newestIndex, lessThan(middleIndex));
    expect(middleIndex, lessThan(oldestIndex));
  });

  testWidgets(
    'day-divider headers appear above each new day\'s group of notes, '
    'using Today/Yesterday text',
    (tester) async {
      final now = DateTime.now();
      final todayNote = noteAt('Today note', now);
      final yesterdayNote = noteAt(
        'Yesterday note',
        now.subtract(const Duration(days: 1)),
      );

      await pumpInbox(tester, tasks: [todayNote, yesterdayNote]);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);

      // The header must sit ABOVE its own day's note, not below it —
      // confirmed via vertical position, since both render as plain
      // Text widgets in the same list.
      final todayHeaderY = tester.getTopLeft(find.text('Today')).dy;
      final todayNoteY = tester.getTopLeft(find.text('Today note')).dy;
      final yesterdayHeaderY = tester.getTopLeft(find.text('Yesterday')).dy;
      final yesterdayNoteY = tester.getTopLeft(find.text('Yesterday note')).dy;

      expect(todayHeaderY, lessThan(todayNoteY));
      expect(todayNoteY, lessThan(yesterdayHeaderY));
      expect(yesterdayHeaderY, lessThan(yesterdayNoteY));
    },
  );

  testWidgets(
    'two notes created on the SAME day share one header, not one each',
    (tester) async {
      final now = DateTime.now();
      final first = noteAt('First today', now);
      final second = noteAt(
        'Second today',
        now.subtract(const Duration(hours: 2)),
      );

      await pumpInbox(tester, tasks: [first, second]);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('First today'), findsOneWidget);
      expect(find.text('Second today'), findsOneWidget);
    },
  );
}
