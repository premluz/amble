import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/inbox/template_list_view.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/task_template_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<TaskTemplate> templateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_template_list');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
    templateBox = await Hive.openBox<TaskTemplate>('test_templates_$stamp');
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await templateBox.close();
  });

  // Seeding writes to a real Hive box, so it runs inside runAsync — see
  // docs/ERROR_LOG.md: Hive's disk I/O completes on the real event loop,
  // which flutter_test's synchronous pump-based zone can starve
  // indefinitely. Everything real-I/O stays inside ONE runAsync block,
  // matching the established `_tapAndSettle` shape rather than
  // reconstructing it.
  Future<void> pumpList(
    WidgetTester tester, {
    List<TaskTemplate> templates = const [],
  }) async {
    await tester.runAsync(() async {
      for (final template in templates) {
        await templateBox.put(template.id, template);
      }
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
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(body: TemplateListView()),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('shows an empty state when no templates exist', (tester) async {
    await pumpList(tester);

    expect(find.byType(TemplateRow), findsNothing);
    expect(find.textContaining('No templates yet'), findsOneWidget);
  });

  testWidgets('renders one row per template, with its title', (tester) async {
    await pumpList(
      tester,
      templates: [
        TaskTemplate.create(
          title: 'Take a walk',
          categoryId: BuiltInCategoryIds.health,
          durationMinutes: 30,
        ),
        TaskTemplate.create(
          title: 'Review inbox',
          categoryId: BuiltInCategoryIds.admin,
        ),
      ],
    );

    expect(find.byType(TemplateRow), findsNWidgets(2));
    expect(find.text('Take a walk'), findsOneWidget);
    expect(find.text('Review inbox'), findsOneWidget);
  });

  // Reported directly: template cards had a hard visible edge against the
  // page background, same issue as the Inbox task cards — fixed with the
  // same existing shadowPane token AppPane already uses for it.
  testWidgets(
    'a template card carries the shared shadowPane elevation, softening '
    'its edge against the page background',
    (tester) async {
      await pumpList(
        tester,
        templates: [
          TaskTemplate.create(
            title: 'Take a walk',
            categoryId: BuiltInCategoryIds.health,
          ),
        ],
      );

      final card = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Take a walk'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.boxShadow, AmbleTheme.light.shadowPane);
    },
  );

  testWidgets('shows the duration only when the template sets one', (
    tester,
  ) async {
    await pumpList(
      tester,
      templates: [
        TaskTemplate.create(
          title: 'Take a walk',
          categoryId: BuiltInCategoryIds.health,
          durationMinutes: 30,
        ),
        TaskTemplate.create(
          title: 'Review inbox',
          categoryId: BuiltInCategoryIds.admin,
        ),
      ],
    );

    expect(find.text('30 min'), findsOneWidget);
    // The duration-less template contributes no second duration line —
    // an unset duration is a real state, not a "0 min" to render.
    expect(find.textContaining(' min'), findsOneWidget);
  });

  testWidgets(
    'a template whose category no longer resolves still renders a row, '
    'so it can be deleted rather than becoming unreachable',
    (tester) async {
      await pumpList(
        tester,
        templates: [
          TaskTemplate.create(
            title: 'Orphaned',
            categoryId: 'no-such-category',
          ),
        ],
      );

      expect(find.byType(TemplateRow), findsOneWidget);
      expect(find.text('Orphaned'), findsOneWidget);
    },
  );
}
