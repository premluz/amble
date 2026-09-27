import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/task_detail/category_list_screen.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../support/seeded_category_box.dart';

/// Requested directly: "No chevron on tags" and "zones templates tags can
/// be slided left to be removed (we have that pattern on tasks and notes
/// in inbox)." Tags' tap-opens-edit-modal shape was already correct
/// before this — only the trailing chevron's removal and the new
/// swipe-to-remove (built-in tags excepted) are covered here.
void main() {
  late Box<Category> categoryBox;
  late Box<Task> taskBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_category_list_screen');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
  });

  tearDown(() async {
    await categoryBox.close();
    await taskBox.close();
  });

  Future<void> pumpList(WidgetTester tester) async {
    // Tall enough that all 9 visible rows (General is filtered out) fit
    // without scrolling — scrolling to reveal a row first would leave
    // residual scroll-position state that risks interfering with the
    // swipe gesture's own horizontal-drag arena right after.
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categoryBox),
          ),
          taskRepositoryProvider.overrideWithValue(
            HiveTaskRepository(taskBox),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(body: CategoryListBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no chevron is shown on any tag row', (tester) async {
    await pumpList(tester);

    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets(
    'swiping a user-created tag left past the threshold removes it',
    (tester) async {
      final custom = Category.create(name: 'Errands', colorToken: 9, emoji: '🛒');
      await tester.runAsync(() => categoryBox.put(custom.id, custom));
      await pumpList(tester);
      expect(find.text('Errands'), findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Errands')),
      );
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(-40, 0));
        await tester.pump();
      }
      // Same real-Hive-write-vs-fake-async-zone gotcha fixed in
      // template_list_view_test.dart: `deleteCategory` awaits a real box
      // write (and a task-reassignment loop) before returning, so the
      // release must run inside `runAsync` or `pumpAndSettle` never
      // observes it completing.
      await tester.runAsync(() async {
        await gesture.up();
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      expect(find.text('Errands'), findsNothing);
    },
  );

  testWidgets('a built-in tag cannot be swiped at all', (tester) async {
    await pumpList(tester);
    expect(find.text('Health'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Health')),
    );
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    // No endAction at all for a built-in row — the swipe is disabled
    // outright, so the row never moves and stays exactly where it was.
    expect(find.text('Health'), findsOneWidget);
  });
}
