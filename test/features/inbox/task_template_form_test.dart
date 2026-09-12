import 'dart:async';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_text_field.dart';
import 'package:amble/features/inbox/task_template_form.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/task_template_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

/// Covers the near-full-screen, Name-first-then-reveal interaction model
/// requested directly: "add template ... should follow same modal UI and
/// interaction model as add task and add zone. Near full screen and
/// disclosure first name and them reveal rest." Mirrors
/// `zone_form_screen_test.dart`'s own equivalent test almost exactly.
Finder _nameField() => find.descendant(
  of: find.widgetWithText(AppTextField, 'Template name'),
  matching: find.byType(TextField),
);

Future<GlobalKey<NavigatorState>> _pumpHost(
  WidgetTester tester, {
  required Box<TaskTemplate> box,
  required Box<Category> categoryBox,
  required Box<TrackedBehavior> trackedBehaviorBox,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskTemplateRepositoryProvider.overrideWithValue(
          HiveTaskTemplateRepository(box),
        ),
        categoryRepositoryProvider.overrideWithValue(
          HiveCategoryRepository(categoryBox),
        ),
        trackedBehaviorRepositoryProvider.overrideWithValue(
          HiveTrackedBehaviorRepository(trackedBehaviorBox),
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
  late Box<TaskTemplate> box;
  late Box<Category> categoryBox;
  late Box<TrackedBehavior> trackedBehaviorBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_task_template_form');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    box = await Hive.openBox<TaskTemplate>('test_templates_$stamp');
    categoryBox = await Hive.openBox<Category>('test_categories_$stamp');
    trackedBehaviorBox = await Hive.openBox<TrackedBehavior>(
      'test_tracked_behaviors_$stamp',
    );
    await categoryBox.put(
      BuiltInCategoryIds.general,
      Category(
        id: BuiltInCategoryIds.general,
        name: 'General',
        colorToken: 0,
        emoji: '⚪',
        isBuiltIn: true,
      ),
    );
  });

  tearDown(() async {
    await box.close();
    await categoryBox.close();
    await trackedBehaviorBox.close();
  });

  testWidgets(
    'a fresh create opens on the Name-only stage 1 — Category/Duration are '
    'not in the tree yet, then reveal once Done is tapped',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
      );
      unawaited(showTaskTemplateForm(navigatorKey.currentContext!));
      await tester.pumpAndSettle();

      expect(find.text('New template'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Create template'), findsNothing);
      expect(find.text('Category'), findsNothing);
      expect(find.text('Default duration'), findsNothing);

      await tester.enterText(_nameField(), 'Take a walk');
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Default duration'), findsOneWidget);
      expect(find.text('Create template'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Done with no name typed closes the whole screen, matching the '
    'task/zone creation flow\'s own abandon behavior',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
      );
      unawaited(showTaskTemplateForm(navigatorKey.currentContext!));
      await tester.pumpAndSettle();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('New template'), findsNothing);
      expect(find.text('Category'), findsNothing);
    },
  );

  testWidgets('editing an existing template skips straight to stage 2 — '
      'Category/Duration are already visible', (tester) async {
    final template = TaskTemplate.create(
      title: 'Take a walk',
      categoryId: BuiltInCategoryIds.general,
      durationMinutes: 30,
    );
    await tester.runAsync(() async {
      await box.put(template.id, template);
    });

    final navigatorKey = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
      trackedBehaviorBox: trackedBehaviorBox,
    );
    showTaskTemplateForm(navigatorKey.currentContext!, template: template);
    await tester.pumpAndSettle();

    expect(find.text('Edit template'), findsOneWidget);
    expect(find.text('Save template'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Default duration'), findsOneWidget);
  });

  // Requested directly: "Edit template also remove icon b[u]tton add."
  testWidgets('editing an existing template shows a remove icon button that '
      'deletes it and closes the screen', (tester) async {
    final template = TaskTemplate.create(
      title: 'Take a walk',
      categoryId: BuiltInCategoryIds.general,
      durationMinutes: 30,
    );
    await tester.runAsync(() async {
      await box.put(template.id, template);
    });

    final navigatorKey = await _pumpHost(
      tester,
      box: box,
      categoryBox: categoryBox,
      trackedBehaviorBox: trackedBehaviorBox,
    );
    showTaskTemplateForm(navigatorKey.currentContext!, template: template);
    await tester.pumpAndSettle();

    final deleteButton = find.byIcon(Icons.delete_outline_rounded);
    expect(deleteButton, findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(deleteButton);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(box.get(template.id), isNull);
    expect(find.text('Edit template'), findsNothing);
  });

  testWidgets(
    'the create flow (no existing template) shows no remove icon button',
    (tester) async {
      final navigatorKey = await _pumpHost(
        tester,
        box: box,
        categoryBox: categoryBox,
        trackedBehaviorBox: trackedBehaviorBox,
      );
      showTaskTemplateForm(navigatorKey.currentContext!);
      await tester.pumpAndSettle();

      await tester.enterText(_nameField(), 'Take a walk');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    },
  );
}
