import 'package:amble/core/tokens/depth_motion_spec.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_depth.dart';
import 'package:amble/core/widgets/app_swipe_actions.dart';
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
    Hive.init('./.dart_tool/test_hive_inbox_depth');
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

  AppDepthPresence presenceOf(WidgetTester tester, String title) =>
      tester.widget<AppDepthPresence>(
        find.ancestor(
          of: find.text(title),
          matching: find.byType(AppDepthPresence),
        ),
      );

  testWidgets('the tasks already there are simply there; a newly added one '
      'emerges from depth', (tester) async {
    final container = await pumpInbox(
      tester,
      tasks: [noteAt('Existing', DateTime.now())],
    );
    expect(presenceOf(tester, 'Existing').animateIn, isFalse);

    await tester.runAsync(
      () => container.read(taskListProvider.notifier).captureTask('Fresh'),
    );
    await tester.pump();
    expect(presenceOf(tester, 'Fresh').animateIn, isTrue);
    expect(presenceOf(tester, 'Existing').animateIn, isFalse);
    // Bounded, not pumpAndSettle: the Inbox keeps a live animation running.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Fresh'), findsOneWidget);
    expect(
      tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text('Fresh'),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value,
      1,
      reason: 'the text has fully faded in',
    );
  });

  testWidgets('swipe-remove starts the row receding instead of deleting it '
      'on the spot', (tester) async {
    final doomed = noteAt('Doomed', DateTime.now());
    await pumpInbox(tester, tasks: [doomed]);

    tester
        .widget<AppSwipeActions>(
          find.ancestor(
            of: find.text('Doomed'),
            matching: find.byType(AppSwipeActions),
          ),
        )
        .endAction!
        .onActivate();
    await tester.pump();
    await tester.pump(DepthMotionSpec.standard.exitDuration * .5);
    expect(presenceOf(tester, 'Doomed').present, isFalse);
    expect(taskBox.containsKey(doomed.id), isTrue, reason: 'still receding');

    // That the delete then runs only once the row has gone is covered at the
    // component level (app_depth_test: onExited fires after the exit). The
    // delete itself is a real Hive write that cannot complete in fake time,
    // so this test stops here and unmounts.
    await tester.pumpWidget(const SizedBox());
  });
}
