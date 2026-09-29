import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_pane.dart';
import 'package:amble/core/widgets/app_value_chip.dart';
import 'package:amble/core/widgets/app_text_field.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/add_category_modal.dart';
import 'package:amble/features/task_detail/category_color_modal.dart';
import 'package:amble/features/task_detail/category_icon_modal.dart';
import 'package:amble/features/task_detail/category_visual.dart';
import 'package:amble/features/task_detail/task_name_category_modal.dart';
import 'package:amble/core/widgets/app_sheet_flow.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

/// The real, typeable `TextField` inside the "Label name" `AppTextField` —
/// same reasoning as `create_flow_initial_modal_test.dart`'s `_nameField`:
/// `AppFieldShell` renders the floating label and the TextField as
/// siblings, so descending through the labeled `AppTextField` ancestor is
/// what actually finds it.
Finder _nameField() => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is AppTextField && widget.label == 'Label name',
  ),
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

  testWidgets('opens as one sheet with Color and Icon value chips', (
    tester,
  ) async {
    final navigatorKey = await _pumpHost(tester, box: box, taskBox: taskBox);
    unawaited(showAddCategoryModal(navigatorKey.currentContext!));
    await tester.pumpAndSettle();

    expect(find.text('New label'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
    expect(find.byType(AppPane), findsNothing);
    expect(find.byType(AppValueChip), findsNWidgets(2));
    expect(find.widgetWithText(AppValueChip, 'Color'), findsOneWidget);
    expect(find.widgetWithText(AppValueChip, 'Icon'), findsOneWidget);

    final saveButton = find.ancestor(
      of: find.byIcon(Icons.check_rounded),
      matching: find.byType(AppButton),
    );
    expect(tester.widget<AppButton>(saveButton).onPressed, isNull);
  });

  testWidgets('the close button dismisses the blank label sheet', (
    tester,
  ) async {
    final navigatorKey = await _pumpHost(tester, box: box, taskBox: taskBox);
    unawaited(showAddCategoryModal(navigatorKey.currentContext!));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('New label'), findsNothing);
  });

  testWidgets('value chips open color and icon as pages of the same sheet', (
    tester,
  ) async {
    final navigatorKey = await _pumpHost(tester, box: box, taskBox: taskBox);
    unawaited(showAddCategoryModal(navigatorKey.currentContext!));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppValueChip, 'Color'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryColorPage), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(CategoryColorPage),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(CategoryColorPage), findsNothing);
    expect(
      tester
          .widget<AppValueChip>(find.widgetWithText(AppValueChip, 'Color'))
          .hasValue,
      isTrue,
    );

    await tester.tap(find.widgetWithText(AppValueChip, 'Icon'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryIconPage), findsOneWidget);

    final icon = find.descendant(
      of: find.byType(CategoryIconPage),
      matching: find.byIcon(TablerIcons.heart),
    );
    await tester.ensureVisible(icon);
    await tester.tap(icon);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryIconPage), findsNothing);
    expect(
      tester
          .widget<AppValueChip>(find.widgetWithText(AppValueChip, 'Icon'))
          .hasValue,
      isTrue,
    );
  });

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
      await tester.tap(find.widgetWithText(AppValueChip, 'Color'));
      await tester.pumpAndSettle();

      await tester.tap(
        find
            .descendant(
              of: find.byType(CategoryColorPage),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppValueChip, 'Icon'));
      await tester.pumpAndSettle();
      final icon = find.descendant(
        of: find.byType(CategoryIconPage),
        matching: find.byIcon(curatedCategoryIcons.first),
      );
      await tester.ensureVisible(icon);
      await tester.tap(icon);
      await tester.pumpAndSettle();

      final saveButton = find.ancestor(
        of: find.byIcon(Icons.check_rounded),
        matching: find.byType(AppButton),
      );
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
        await tester.tap(find.byIcon(Icons.check_rounded));
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
      expect(result!.iconCodePoint, curatedCategoryIcons.first.codePoint);
      // Superseded field, left empty on a freshly created category — see
      // Category.emoji's own doc comment.
      expect(result!.emoji, '');

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
        expect(find.text('Edit label'), findsNothing);
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

      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });
  });

  testWidgets('from Name and category, New label is a page of the SAME sheet '
      'and saving comes back with it selected', (tester) async {
    final navigatorKey = await _pumpHost(tester, box: box, taskBox: taskBox);
    final title = TextEditingController();
    final notes = TextEditingController();
    addTearDown(title.dispose);
    addTearDown(notes.dispose);
    final picked = <String>[];
    unawaited(
      TaskNameCategoryModal.show(
        context: navigatorKey.currentContext!,
        titleController: title,
        notesController: notes,
        categoryId: null,
        onCategoryChanged: picked.add,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Name and category'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppValueChip, 'New label'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSheetFlow), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

    await tester.enterText(_nameField(), 'Garden');
    await tester.tap(find.widgetWithText(AppValueChip, 'Color'));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(CategoryColorPage),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppValueChip, 'Icon'));
    await tester.pumpAndSettle();
    final icon = find.descendant(
      of: find.byType(CategoryIconPage),
      matching: find.byIcon(TablerIcons.heart),
    );
    await tester.ensureVisible(icon);
    await tester.tap(icon);
    await tester.pumpAndSettle();
    // Save writes to Hive: tap, real delay and settle in ONE runAsync (see
    // the create test above and docs/ERROR_LOG.md).
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Save label'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    });
    // The page slide back runs on the test clock.
    await tester.pumpAndSettle();

    // Back on the first page of the same sheet (× again, not ‹).
    expect(find.byType(AddCategoryPage), findsNothing);
    expect(find.text('Name and category'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(picked, hasLength(1));
    expect(find.text('Garden'), findsOneWidget);
  });
}

/// Fires an async future without awaiting it inline — used for
/// `showAddCategoryModal`'s Future, which only resolves once the screen is
/// popped by user interaction later in the same test.
void unawaited(Future<void> future) {}
