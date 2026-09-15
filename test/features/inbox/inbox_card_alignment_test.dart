import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_top_scroll_fade.dart';
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

/// **2026-09-12 — the Manage screen's sub-tabs (Tasks/Templates/Zones/
/// Categories) were removed**, requested directly: "remove tabs tasks
/// templates zones categories... only keep tasks." This file's own
/// tab-alignment test was removed with them (`inbox_manage_tabs_test.dart`
/// covered the rest of that removed feature and was deleted outright).
/// The remaining tests here — background/fade color, fade-vs-heading
/// layout — are unaffected by the tab removal and still apply to the
/// tasks-only screen.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_inbox_card_alignment');
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

  Future<void> pumpInbox(WidgetTester tester) async {
    await tester.runAsync(() async {
      // Plain Task(...), not Task.create — an Inbox row is UNSCHEDULED
      // (inboxTasksProvider filters to `!task.isScheduled`), and
      // Task.create requires a non-null scheduledAt.
      final task = Task(
        id: const Uuid().v4(),
        title: 'Buy milk',
        categoryId: BuiltInCategoryIds.general,
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

  // Reversed back (2026-09-09), requested directly: "the header cuts the
  // content with a hard edge... the content slides through underneath."
  // A fade confined to the fixed heading (the shape this test used to
  // assert) can only ever blend against that heading's own flat
  // background — never the list actually scrolling underneath it, which
  // is exactly the hard-cut bug being fixed. The fade now overlays the
  // scrolling content directly, matching the Timeline's own fade.
  testWidgets(
    'the top scroll-fade overlays the scrolling list directly, not just '
    "the fixed heading — so content actually fades as it scrolls underneath",
    (tester) async {
      await pumpInbox(tester);

      // The fade must share a Stack with the actual tab content (the
      // Tasks ListView here) so it visually overlays real scrolling
      // content, not a separate ClipRect scoped to the "Manage" heading
      // alone (the old, wrong shape this test used to assert).
      final topFade = find.byWidgetPredicate(
        (w) => w is AppTopScrollFade && !w.fromBottom,
      );
      final sharedStack = find.ancestor(
        of: topFade,
        matching: find.byType(Stack),
      );
      expect(
        find.descendant(of: sharedStack.first, matching: find.byType(ListView)),
        findsWidgets,
        reason:
            'the top fade must share a Stack with the actual scrolling '
            'content, so it visually overlays it rather than only ever '
            "blending against its own separate header's flat background",
      );

      // And the fade is NOT scoped inside any ClipRect wrapping the
      // "Inbox" title — the old header-embedded shape.
      final headingClips = find.ancestor(
        of: find.text('Inbox'),
        matching: find.byType(ClipRect),
      );
      for (final clipElement in headingClips.evaluate()) {
        final headingClip = clipElement.widget as ClipRect;
        expect(
          find.descendant(of: find.byWidget(headingClip), matching: topFade),
          findsNothing,
          reason:
              'the fade must not live inside the fixed heading\'s own '
              'ClipRect any more',
        );
      }
    },
  );

  // Requested directly: "Inbox background should be the same as the
  // timeline background."
  testWidgets("the screen's background and BOTH fades' own colour match the "
      'Timeline surface', (tester) async {
    await pumpInbox(tester);

    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.color, AmbleTheme.light.colorSurfaceTimeline);

    for (final element in find.byType(AppTopScrollFade).evaluate()) {
      expect(
        (element.widget as AppTopScrollFade).color,
        AmbleTheme.light.colorSurfaceTimeline,
      );
    }
  });

  // Requested directly: "use same at the bottom."
  testWidgets(
    'shows a mirrored bottom scroll-fade above the list, in addition to '
    'the top one in the heading',
    (tester) async {
      await pumpInbox(tester);

      expect(find.byType(AppTopScrollFade), findsNWidgets(2));
      final fades = find
          .byType(AppTopScrollFade)
          .evaluate()
          .map((e) => e.widget as AppTopScrollFade)
          .toList();
      expect(fades.where((f) => f.fromBottom).length, 1);
      expect(fades.where((f) => !f.fromBottom).length, 1);
    },
  );

  // **2026-09-12 — reversed.** Requested directly: "remove cards from
  // Manage." Was: "a task card carries the shared shadowPane elevation" —
  // the row is now a plain, undecorated Row (no fill, no shadow, no
  // rounded corners), separated from its neighbours by the list's own
  // separator gap rather than by a card edge.
  testWidgets('a task row carries no card decoration — no fill, no shadow', (
    tester,
  ) async {
    await pumpInbox(tester);

    // No ancestor Container between the row's own title and the
    // ListView at all — the old card wrapper is gone entirely, not just
    // stripped of its shadow.
    final rowContainers = find.ancestor(
      of: find.text('Buy milk'),
      matching: find.byType(Container),
    );
    for (final element in rowContainers.evaluate()) {
      final decoration = (element.widget as Container).decoration;
      expect(
        decoration,
        isNull,
        reason:
            'no Container between the row and the list should carry '
            'a card decoration any more',
      );
    }
  });

  // Reversed back (2026-09-09) alongside the fade-overlays-the-list fix
  // above: originally "the heading in the inbox is also being covered by
  // this gradient" was fixed by moving the fade INTO the heading's own
  // background. Now that the fade lives in the Expanded content area
  // instead (so it can actually blend against scrolling content), the
  // title staying clear of it is no longer a paint-order question within
  // one Stack — it's a LAYOUT question: the fixed heading and the
  // Expanded content area are separate Column children, so the title's
  // own bounds and the fade's own bounds can never overlap at all.
  testWidgets(
    'the "Inbox" title never visually overlaps the top scroll-fade — they '
    'occupy separate, non-overlapping regions of the screen',
    (tester) async {
      await pumpInbox(tester);

      final titleRect = tester.getRect(find.text('Inbox'));
      final topFade = find.byWidgetPredicate(
        (w) => w is AppTopScrollFade && !w.fromBottom,
      );
      final fadeRect = tester.getRect(topFade);

      expect(
        titleRect.overlaps(fadeRect),
        isFalse,
        reason:
            'the title and the fade must occupy separate regions — the '
            'title in the fixed heading above, the fade over the '
            'scrolling content below it',
      );
    },
  );
}
