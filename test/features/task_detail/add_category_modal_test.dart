import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_text_field.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/task_detail/add_category_modal.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';

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

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_add_category_modal');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Category>(
      'test_categories_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await box.close();
  });

  testWidgets('Save is disabled until name, color, and emoji are all set', (
    tester,
  ) async {
    final navigatorKey = await _pumpHost(tester, box: box);
    unawaited(AddCategoryModal.show(context: navigatorKey.currentContext!));
    await tester.pumpAndSettle();

    ElevatedButton saveButton() => tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Save'),
    );

    // Nothing set yet.
    expect(saveButton().onPressed, isNull);

    // Name only.
    await tester.enterText(_nameField(), 'Gardening');
    await tester.pump();
    expect(saveButton().onPressed, isNull);

    // Name + color, still no emoji.
    await tester.tap(find.text('Gardening')); // no-op safety tap, ignored
    final colorSwatch = find.byType(GestureDetector).at(1);
    await tester.tap(colorSwatch);
    await tester.pump();
    expect(saveButton().onPressed, isNull);

    // Name + color + emoji — now enabled. ensureVisible first: the emoji
    // grid scrolls, and the default test viewport doesn't fit every emoji
    // without scrolling to it — same fix as edit_schedule_repeats_test.dart
    // needed for its own scrollable schedule stage (see docs/ERROR_LOG.md).
    final emoji = find.text('🌱');
    await tester.ensureVisible(emoji);
    await tester.pump();
    await tester.tap(emoji);
    await tester.pump();
    expect(saveButton().onPressed, isNotNull);
  });

  testWidgets(
    'creating a category saves it and resolves it back to the caller, '
    'and it appears in categoryListProvider',
    (tester) async {
      final navigatorKey = await _pumpHost(tester, box: box);
      Category? result;
      unawaited(
        AddCategoryModal.show(context: navigatorKey.currentContext!)
            .then((value) => result = value),
      );
      await tester.pumpAndSettle();

      await tester.enterText(_nameField(), 'Gardening');
      await tester.pump();

      // Tap the first color swatch.
      final colorSwatch = find.byType(GestureDetector).at(1);
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
}

/// Fires an async future without awaiting it inline — used for
/// `AddCategoryModal.show`'s Future, which only resolves once the sheet is
/// popped by user interaction later in the same test.
void unawaited(Future<void> future) {}
