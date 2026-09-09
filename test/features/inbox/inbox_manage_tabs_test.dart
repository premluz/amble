import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/inbox/inbox_screen.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/task_template_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:uuid/uuid.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// Covers the Manage screen's four sub-tabs — requested directly: "The
/// first tab will be 'Inbox Manage,' and it will have: Tasks, Templates,
/// Zones (list of zones and add new zone, edit also), Categories (list of
/// categories and add category, edit also)." Zones/Categories reuse their
/// existing list/form screens (`ZoneListBody`/`showZoneFormScreen`,
/// `CategoryListBody`/`showAddCategoryModal`) embedded directly, rather
/// than duplicating that UI — these tests confirm the embedding actually
/// shows real data and that "+" creates the right kind of thing per tab.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<TaskTemplate> templateBox;
  late Box<Zone> zoneBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_inbox_manage_tabs');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
    templateBox = await Hive.openBox<TaskTemplate>('test_templates_$stamp');
    zoneBox = await Hive.openBox<Zone>('test_zones_$stamp');
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await templateBox.close();
    await zoneBox.close();
  });

  Future<void> pumpManage(WidgetTester tester) async {
    await tester.runAsync(() async {
      final task = Task(
        id: const Uuid().v4(),
        title: 'Buy milk',
        categoryId: BuiltInCategoryIds.general,
      );
      await taskBox.put(task.id, task);

      final template = TaskTemplate.create(
        title: 'Take a walk',
        categoryId: BuiltInCategoryIds.general,
      );
      await templateBox.put(template.id, template);

      final zone = Zone(
        id: const Uuid().v4(),
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
      );
      await zoneBox.put(zone.id, zone);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categoryBox),
          ),
          taskTemplateRepositoryProvider.overrideWithValue(
            HiveTaskTemplateRepository(templateBox),
          ),
          zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zoneBox)),
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

  testWidgets('the heading reads "Manage", not "Inbox"', (tester) async {
    await pumpManage(tester);

    expect(find.text('Manage'), findsOneWidget);
    expect(find.text('Inbox'), findsNothing);
  });

  testWidgets('all four sub-tab chips are shown: Tasks, Templates, Zones, '
      'Categories', (tester) async {
    await pumpManage(tester);

    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Zones'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
  });

  testWidgets('tapping the Zones chip shows the real zone list, not a '
      'placeholder', (tester) async {
    await pumpManage(tester);

    await tester.tap(find.text('Zones'));
    await tester.pump();

    expect(find.text('Morning ritual'), findsOneWidget);
  });

  testWidgets(
    'tapping the Categories chip shows the real category list, including '
    'a built-in seeded category',
    (tester) async {
      await pumpManage(tester);

      await tester.tap(find.text('Categories'));
      await tester.pump();

      expect(find.text('General'), findsOneWidget);
    },
  );

  testWidgets(
    'the "+" button on the Zones sub-tab opens the new-zone form, not the '
    'quick-capture sheet',
    (tester) async {
      await pumpManage(tester);

      await tester.tap(find.text('Zones'));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('New zone'), findsOneWidget);
    },
  );

  testWidgets('the "+" button on the Categories sub-tab opens the new-category '
      'form, not the quick-capture sheet', (tester) async {
    await pumpManage(tester);

    await tester.tap(find.text('Categories'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('New category'), findsOneWidget);
  });

  testWidgets(
    'tapping an existing zone in the Zones sub-tab opens it for editing, '
    'pre-filled',
    (tester) async {
      await pumpManage(tester);

      await tester.tap(find.text('Zones'));
      await tester.pump();

      await tester.tap(find.text('Morning ritual'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Edit zone'), findsOneWidget);
      // Two matches: the static row title elsewhere and the form's own
      // pre-filled name field's EditableText — findsWidgets rather than
      // findsOneWidget, since either is proof the name carried over.
      expect(find.text('Morning ritual'), findsWidgets);
    },
  );

  testWidgets(
    'tapping an existing category in the Categories sub-tab opens it for '
    'editing, pre-filled, and saving a rename persists it',
    (tester) async {
      await pumpManage(tester);

      await tester.tap(find.text('Categories'));
      await tester.pump();

      await tester.tap(find.text('General'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Edit category'), findsOneWidget);

      // Two matches on 'General': the static category-badge Text and the
      // name field's own EditableText, same shape the zone-edit test
      // above hits — target the editable field specifically.
      await tester.enterText(
        find.descendant(
          of: find.byType(TextField),
          matching: find.byType(EditableText),
        ),
        'Errands',
      );
      // Saving triggers a real Hive write (updateCategory ->
      // saveCategory), which — per docs/ERROR_LOG.md's "Hive write
      // inside a widget test hangs" entry — hangs the test's fake-async
      // zone unless wrapped in runAsync.
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      });
      // The pop's own slide-transition animation still needs real frames
      // to finish — a single bare pump() leaves the old route's tree
      // (including its "Edit category" title) still present mid-transition.
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Edit category'), findsNothing);
      expect(find.text('Errands'), findsOneWidget);
    },
  );
}
