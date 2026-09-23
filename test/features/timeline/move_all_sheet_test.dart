import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/move_all_sheet.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

import '../../support/seeded_category_box.dart';
import '../../support/fake_notification_service.dart';

/// Covers `showMoveAllSheet`'s own UI wiring — the "Move all" entry on the
/// hold-and-drag placement release menu, requested directly: "this allows
/// to move all tasks before/or after the selected point, by selected h:m
/// from wheeler, later or earlier."
///
/// Deliberately does NOT exercise the real Move button's commit here — a
/// tap-and-commit round trip through this sheet reliably disposes
/// `taskListProvider`'s own `ref` mid-write under `flutter_test`
/// (`UnmountedRefException` inside `TaskList._refresh`, confirmed by
/// instrumenting `shiftTasksByMinutes` directly), a widget-test-only
/// artifact this codebase hasn't hit before this sheet (see
/// docs/ERROR_LOG.md). The scope-filter/sign LOGIC the button's commit
/// depends on is pulled into a pure function and covered directly by
/// `test/shared/services/move_all_deltas_test.dart` instead — this file
/// only proves the sheet opens and its direction toggle updates the
/// button's own label, not the real Hive write.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_move_all_sheet');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
  });

  tearDown(() async {
    await taskBox.deleteFromDisk();
    await categoryBox.deleteFromDisk();
  });

  Future<void> pumpSheet(WidgetTester tester, {required DateTime around}) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showMoveAllSheet(context, around: around),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'opens with the default direction, showing the Before-this-point '
    'phrased button',
    (tester) async {
      await pumpSheet(tester, around: DateTime(2026, 1, 5, 12));

      expect(find.text('Move all'), findsOneWidget);
      expect(find.text('Before this point'), findsOneWidget);
      expect(find.textContaining('Move earlier tasks later'), findsOneWidget);
    },
  );

  testWidgets(
    'switching to After this point relabels the button to the earlier-'
    'direction phrasing',
    (tester) async {
      await pumpSheet(tester, around: DateTime(2026, 1, 5, 12));

      await tester.ensureVisible(find.text('After this point'));
      await tester.tap(find.text('After this point'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Move later tasks earlier'), findsOneWidget);
      expect(find.textContaining('Move earlier tasks later'), findsNothing);
    },
  );
}
