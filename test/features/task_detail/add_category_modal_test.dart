import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_pane.dart';
import 'package:amble/core/widgets/app_text_field.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/add_category_modal.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

/// The real, typeable `TextField` inside the "Category name" `AppTextField`
/// — same reasoning as `create_flow_initial_modal_test.dart`'s `_nameField`:
/// `AppFieldShell` renders the floating label and the TextField as
/// siblings, so descending through the labeled `AppTextField` ancestor is
/// what actually finds it.
Finder _nameField() => find.descendant(
  of: find.widgetWithText(AppTextField, 'Category name'),
  matching: find.byType(TextField),
);

Future<GlobalKey<NavigatorState>> _pumpHost(
  WidgetTester tester, {
  required Box<Category> box,
  required Box<Task> taskBox,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(
          HiveCategoryRepository(box),
        ),
        // deleteCategory reassigns every referencing task's categoryId
        // to General before deleting the row — needs a real repository
        // here, not the default (unopened-in-test) Hive box.
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  return navigatorKey;
}

void main() {
  late Box<Category> box;
  late Box<Task> taskBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_add_category_modal');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    box = await Hive.openBox<Category>('test_categories_$stamp');
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
  });

  tearDown(() async {
    await box.close();
    await taskBox.close();
  });

  testWidgets(
    'opens on the Name-only stage 1, matching the task/zone creation flows '
    '— color and emoji are not in the tree yet',
    (tester) async {
      // Requested directly: "this would be a pattern of progressive
      // disclosure that applies to task, zone, category."
      final navigatorKey = await _pumpHost(tester, box: box, taskBox: taskBox);
      unawaited(showAddCategoryModal(navigatorKey.currentContext!));
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsNothing);
      expect(find.text('Color'), findsNothing);
      expect(find.text('Emoji'), findsNothing);

      // Done is always enabled at stage 1 (matching the task/zone flows'
      // own _confirmNameStage) — an empty name closes the whole screen
      // rather than the button being disabled.
      await tester.enterText(_nameField(), 'Gardening');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.text('Color'), findsOneWidget);
      expect(find.text('Emoji'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);
    },
  );

  testWidgets('tapping Done with no name typed closes the whole screen', (
    tester,
  ) async {
    final navigatorKey = await _pumpHost(tester, box: box, taskBox: taskBox);
    unawaited(showAddCategoryModal(navigatorKey.currentContext!));
    await tester.pumpAndSettle();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Color'), findsNothing);
    expect(find.text('New category'), findsNothing);
  });

  testWidgets(
    'Save is disabled until color and emoji are both set, once past stage 1',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box, taskBox: taskBox);
      unawaited(showAddCategoryModal(navigatorKey.currentContext!));
      await tester.pumpAndSettle();

      await tester.enterText(_nameField(), 'Gardening');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      ElevatedButton saveButton() => tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Save'),
      );

      // Nothing set yet.
      expect(saveButton().onPressed, isNull);

      // Color, still no emoji.
      final colorSwatch = find
          .descendant(
            of: find.widgetWithText(AppPane, 'Color'),
            matching: find.byType(GestureDetector),
          )
          .first;
      await tester.tap(colorSwatch);
      await tester.pump();
      expect(saveButton().onPressed, isNull);

      // Color + emoji — now enabled. ensureVisible first: the emoji grid
      // scrolls, and the default test viewport doesn't fit every emoji
      // without scrolling to it — same fix as edit_schedule_repeats_test.dart
      // needed for its own scrollable schedule stage (see docs/ERROR_LOG.md).
      final emoji = find.text('🌱');
      await tester.ensureVisible(emoji);
      await tester.pump();
      await tester.tap(emoji);
      await tester.pump();
      expect(saveButton().onPressed, isNotNull);
    },
  );

  testWidgets(
    'creating a category saves it and resolves it back to the caller, '
    'and it appears in categoryListProvider',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box, taskBox: taskBox);
      Category? result;
      unawaited(
        showAddCategoryModal(navigatorKey.currentContext!)
            .then((value) => result = value),
      );
      await tester.pumpAndSettle();

      await tester.enterText(_nameField(), 'Gardening');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      // Tap the first color swatch.
      final colorSwatch = find
          .descendant(
            of: find.widgetWithText(AppPane, 'Color'),
            matching: find.byType(GestureDetector),
          )
          .first;
      await tester.tap(colorSwatch);
      await tester.pump();

      // Tap the first curated emoji. ensureVisible first — same scrollable
      // grid reasoning as the test above.
      final emoji = find.text('⭐');
      await tester.ensureVisible(emoji);
      await tester.pump();
      await tester.tap(emoji);
      await tester.pump();

      final saveButton = find.widgetWithText(ElevatedButton, 'Save');
      await tester.ensureVisible(saveButton);
      await tester.pump();
      // tap, the real-I/O delay, AND the final pumpAndSettle all inside
      // ONE runAsync block — same shape as edit_schedule_repeats_test.dart's
      // own _tapAndSettle helper (see docs/ERROR_LOG.md). Splitting these
      // across real-zone and test-zone calls (tap outside runAsync, only
      // the delay inside, pumpAndSettle outside again) raced across zone
      // boundaries and hung — caught by actually running this, not by
      // reasoning about it.
      await tester.runAsync(() async {
        await tester.tap(saveButton);
        // Not pumpAndSettle immediately: Save shows a spinner
        // (AppButton.isLoading/_isSaving) for the duration of the
        // in-flight createCategory write, and a spinner's animation never
        // settles — pumpAndSettle would hang waiting for it. A single
        // pump just drains the tap's own frame.
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      });

      expect(result, isNotNull);
      expect(result!.name, 'Gardening');
      expect(result!.colorToken, 0);
      expect(result!.emoji, '⭐');

      final container = ProviderScope.containerOf(navigatorKey.currentContext!);
      final categories = container.read(categoryListProvider);
      expect(categories, hasLength(1));
      expect(categories.single.name, 'Gardening');
    },
  );

  // Requested directly: "Edit category also [remove icon button]."
  group('delete', () {
    testWidgets(
      'editing a user-defined category shows a remove icon button that '
      'deletes it, reassigns referencing tasks to General, and closes '
      'the screen',
      (tester) async {
        final category = Category.create(
          name: 'Gardening',
          colorToken: 0,
          emoji: '🌱',
        );
        final task = Task.create(
          title: 'Water the tomatoes',
          scheduledAt: DateTime(2026, 9, 10, 9),
          durationMinutes: 15,
          categoryId: category.id,
        );
        await tester.runAsync(() async {
          await box.put(category.id, category);
          await taskBox.put(task.id, task);
        });

        final navigatorKey = await _pumpHost(
          tester,
          box: box,
          taskBox: taskBox,
        );
        unawaited(
          showAddCategoryModal(
            navigatorKey.currentContext!,
            category: category,
          ),
        );
        await tester.pumpAndSettle();

        final deleteButton = find.byIcon(Icons.delete_outline_rounded);
        expect(deleteButton, findsOneWidget);

        await tester.runAsync(() async {
          await tester.tap(deleteButton);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();

        expect(box.get(category.id), isNull);
        expect(find.text('Edit category'), findsNothing);
        expect(taskBox.get(task.id)!.categoryId, BuiltInCategoryIds.general);
      },
    );

    testWidgets('editing a built-in category shows no remove icon button', (
      tester,
    ) async {
      final builtIn = Category(
        id: BuiltInCategoryIds.general,
        name: 'General',
        colorToken: 0,
        emoji: '⚪',
        isBuiltIn: true,
      );
      await tester.runAsync(() => box.put(builtIn.id, builtIn));

      final navigatorKey = await _pumpHost(tester, box: box, taskBox: taskBox);
      unawaited(
        showAddCategoryModal(navigatorKey.currentContext!, category: builtIn),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    testWidgets('the create flow (no existing category) shows no remove icon '
        'button', (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box, taskBox: taskBox);
      unawaited(showAddCategoryModal(navigatorKey.currentContext!));
      await tester.pumpAndSettle();

      await tester.enterText(_nameField(), 'Gardening');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });
  });
}

/// Fires an async future without awaiting it inline — used for
/// `showAddCategoryModal`'s Future, which only resolves once the screen is
/// popped by user interaction later in the same test.
void unawaited(Future<void> future) {}
