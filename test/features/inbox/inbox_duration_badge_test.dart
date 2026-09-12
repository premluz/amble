import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/inbox/inbox_screen.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// Requested directly: "duration in tasks move to the right but text size
/// 10px (smallest scale) in a 'badge' surface color next to current bg."
/// `10px` confirmed via AskUserQuestion to mean the existing smallest
/// type-scale rung (`textTaskTitleSm`, 11px), not a new literal primitive.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_inbox_duration_badge');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
  });

  Future<void> pumpInbox(WidgetTester tester, {int? durationMinutes}) async {
    await tester.runAsync(() async {
      // Plain Task(...), not Task.create — an Inbox row is UNSCHEDULED
      // (inboxTasksProvider filters to `!task.isScheduled`), and
      // Task.create requires a non-null scheduledAt. durationMinutes can
      // still be set independently on an otherwise-unscheduled task.
      final task = Task(
        id: const Uuid().v4(),
        title: 'Buy milk',
        categoryId: BuiltInCategoryIds.general,
        durationMinutes: durationMinutes,
      );
      await taskBox.put(task.id, task);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categoryBox),
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

  testWidgets('shows the formatted duration when the task has one', (
    tester,
  ) async {
    await pumpInbox(tester, durationMinutes: 45);

    expect(find.text('45m'), findsOneWidget);
  });

  testWidgets(
    'formats an hours-and-minutes duration the same way the rest of the '
    'app does',
    (tester) async {
      await pumpInbox(tester, durationMinutes: 100);

      expect(find.text('1h 40m'), findsOneWidget);
    },
  );

  testWidgets('renders nothing extra when the task has no duration set', (
    tester,
  ) async {
    await pumpInbox(tester);

    // The row has exactly ONE DecoratedBox — the category badge circle
    // (a Container with a decoration, which always builds one). No
    // duration set means no second one for the duration pill.
    final rowFinder = find.ancestor(
      of: find.text('Buy milk'),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: rowFinder.first, matching: find.byType(DecoratedBox)),
      findsOneWidget,
      reason: 'only the category badge circle, no duration pill',
    );
    expect(find.text('Buy milk'), findsOneWidget);
  });

  testWidgets(
    'the badge renders at the smallest task-title font, not the row\'s '
    'own title size',
    (tester) async {
      await pumpInbox(tester, durationMinutes: 45);

      final badgeText = tester.widget<Text>(find.text('45m'));
      expect(
        badgeText.style?.fontSize,
        AmbleTheme.light.textTaskTitleSm.fontSize,
      );

      final titleText = tester.widget<Text>(find.text('Buy milk'));
      expect(
        badgeText.style?.fontSize,
        lessThan(titleText.style!.fontSize!),
        reason: 'the badge must read as smaller than the task title beside it',
      );
    },
  );

  testWidgets(
    'the badge is filled with colorSurfaceSecondary, one step up from the '
    "screen's own background",
    (tester) async {
      await pumpInbox(tester, durationMinutes: 45);

      final badgeDecoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .ancestor(
                          of: find.text('45m'),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;

      expect(badgeDecoration.color, AmbleTheme.light.colorSurfaceSecondary);
      expect(
        badgeDecoration.color,
        isNot(AmbleTheme.light.colorSurfaceTimeline),
        reason: 'the badge must read as a distinct surface from the page',
      );
    },
  );

  testWidgets(
    'the row\'s category badge and title track the shared "Task size" '
    'tokens (theme.sizeTaskBadge/theme.textTaskTitle) — reported '
    'directly: "manage items should have same size as zone view"',
    (tester) async {
      await pumpInbox(tester);

      final theme = AmbleTheme.light;
      final titleText = tester.widget<Text>(find.text('Buy milk'));
      expect(titleText.style?.fontSize, theme.textTaskTitle.fontSize);

      // The row's own circular category badge — the ONE Container that
      // builds a BoxShape.circle decoration when no duration badge is
      // present (see the "renders nothing extra" case above for the same
      // "only the category badge" premise).
      final circleContainer = tester
          .widgetList<Container>(find.byType(Container))
          .firstWhere(
            (c) => (c.decoration as BoxDecoration?)?.shape == BoxShape.circle,
          );

      expect(circleContainer.constraints?.maxWidth, theme.sizeTaskBadge);
      expect(circleContainer.constraints?.maxHeight, theme.sizeTaskBadge);
    },
  );

  testWidgets(
    'the duration badge sits between the title and the trailing + button, '
    'to the right of the row',
    (tester) async {
      await pumpInbox(tester, durationMinutes: 45);

      final rowFinder = find.ancestor(
        of: find.text('Buy milk'),
        matching: find.byType(Row),
      );
      final titleRect = tester.getRect(find.text('Buy milk'));
      final badgeRect = tester.getRect(find.text('45m'));
      final plusRect = tester.getRect(
        find.descendant(
          of: rowFinder.first,
          matching: find.byIcon(Icons.add_rounded),
        ),
      );

      expect(
        badgeRect.left,
        greaterThan(titleRect.right),
        reason: 'badge must sit to the right of the title text',
      );
      expect(
        badgeRect.right,
        lessThan(plusRect.left),
        reason: 'badge must sit to the left of the trailing + button',
      );
    },
  );
}
