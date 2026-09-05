import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/providers/task_template_providers.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  late Box<TaskTemplate> box;
  late ProviderContainer container;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_task_template_providers');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<TaskTemplate>(
      'test_task_templates_${DateTime.now().microsecondsSinceEpoch}',
    );

    container = ProviderContainer(
      overrides: [
        taskTemplateRepositoryProvider.overrideWithValue(
          HiveTaskTemplateRepository(box),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await box.deleteFromDisk();
  });

  test('createTemplate persists and exposes the new template', () async {
    final notifier = container.read(taskTemplateListProvider.notifier);

    final created = await notifier.createTemplate(
      title: 'Take a walk',
      categoryId: BuiltInCategoryIds.health,
      durationMinutes: 30,
    );

    expect(container.read(taskTemplateListProvider), hasLength(1));
    expect(box.get(created.id)?.title, 'Take a walk');
    expect(box.get(created.id)?.durationMinutes, 30);
  });

  test('updateTemplate writes back to the same id', () async {
    final notifier = container.read(taskTemplateListProvider.notifier);
    final created = await notifier.createTemplate(
      title: 'Take a walk',
      categoryId: BuiltInCategoryIds.health,
    );

    created.title = 'Take a long walk';
    created.durationMinutes = 45;
    await notifier.updateTemplate(created);

    expect(container.read(taskTemplateListProvider), hasLength(1));
    expect(box.get(created.id)?.title, 'Take a long walk');
    expect(box.get(created.id)?.durationMinutes, 45);
  });

  test('deleteTemplate removes it outright, with no guard', () async {
    final notifier = container.read(taskTemplateListProvider.notifier);
    final created = await notifier.createTemplate(
      title: 'Take a walk',
      categoryId: BuiltInCategoryIds.health,
    );

    await notifier.deleteTemplate(created.id);

    expect(container.read(taskTemplateListProvider), isEmpty);
    expect(box.get(created.id), isNull);
  });

  test('deleting one template leaves the others untouched', () async {
    final notifier = container.read(taskTemplateListProvider.notifier);
    final walk = await notifier.createTemplate(
      title: 'Take a walk',
      categoryId: BuiltInCategoryIds.health,
    );
    await notifier.createTemplate(
      title: 'Review inbox',
      categoryId: BuiltInCategoryIds.admin,
    );

    await notifier.deleteTemplate(walk.id);

    final remaining = container.read(taskTemplateListProvider);
    expect(remaining, hasLength(1));
    expect(remaining.single.title, 'Review inbox');
  });
}
