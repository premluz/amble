import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/section.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/section_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_section_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';

import '../../support/fake_notification_service.dart';

/// `SectionList.deleteSection`'s own doc comment flags this as the one
/// genuinely new piece of logic in the Sections feature — unlike every
/// other part (model/repository/provider shape), there is no existing
/// "delete → unassign" implementation elsewhere in this codebase to
/// mirror, so this gets direct, dedicated coverage rather than relying on
/// a structural similarity to `CategoryList.deleteCategory`'s own tests.
void main() {
  late Box<Task> taskBox;
  late Box<Section> sectionBox;
  late ProviderContainer container;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_section_providers');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final suffix = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_section_tasks_$suffix');
    sectionBox = await Hive.openBox<Section>('test_section_sections_$suffix');

    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
        sectionRepositoryProvider.overrideWithValue(
          HiveSectionRepository(sectionBox),
        ),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await taskBox.deleteFromDisk();
    await sectionBox.deleteFromDisk();
  });

  test('createSection persists and returns the new Section', () async {
    final section = await container
        .read(sectionListProvider.notifier)
        .createSection(name: 'Errands');

    expect(section.name, 'Errands');
    expect(container.read(sectionListProvider), hasLength(1));
    expect(container.read(sectionListProvider).first.id, section.id);
  });

  test('renameSection updates the persisted row', () async {
    final section = await container
        .read(sectionListProvider.notifier)
        .createSection(name: 'Old name');

    await container
        .read(sectionListProvider.notifier)
        .renameSection(section.id, 'New name');

    expect(container.read(sectionListProvider).first.name, 'New name');
  });

  test(
    'deleteSection unassigns every Task filed into it (sectionId -> null)',
    () async {
      final section = await container
          .read(sectionListProvider.notifier)
          .createSection(name: 'Groceries');

      final filed = Task(id: 't1', title: 'Buy milk', sectionId: section.id);
      final alsoFiled = Task(id: 't2', title: 'Buy eggs', sectionId: section.id);
      final unrelated = Task(id: 't3', title: 'Unrelated', sectionId: null);
      await taskBox.put(filed.id, filed);
      await taskBox.put(alsoFiled.id, alsoFiled);
      await taskBox.put(unrelated.id, unrelated);
      // Refresh TaskList's own state now that the box has real rows —
      // it reads once at `build()`, before this setup ran.
      container.invalidate(taskListProvider);

      await container.read(sectionListProvider.notifier).deleteSection(
        section.id,
      );

      final tasks = container.read(taskListProvider);
      expect(tasks.firstWhere((t) => t.id == 't1').sectionId, isNull);
      expect(tasks.firstWhere((t) => t.id == 't2').sectionId, isNull);
      // Never touched this task's sectionId in the first place — confirms
      // the bulk pass is scoped to affected tasks only.
      expect(tasks.firstWhere((t) => t.id == 't3').sectionId, isNull);
    },
  );

  test('deleteSection removes the Section row itself', () async {
    final section = await container
        .read(sectionListProvider.notifier)
        .createSection(name: 'Groceries');

    await container.read(sectionListProvider.notifier).deleteSection(
      section.id,
    );

    expect(container.read(sectionListProvider), isEmpty);
  });

  test(
    'deleteSection leaves tasks in OTHER sections untouched',
    () async {
      final target = await container
          .read(sectionListProvider.notifier)
          .createSection(name: 'Target');
      final other = await container
          .read(sectionListProvider.notifier)
          .createSection(name: 'Other');

      final inOther = Task(id: 't1', title: 'Stays put', sectionId: other.id);
      await taskBox.put(inOther.id, inOther);
      container.invalidate(taskListProvider);

      await container.read(sectionListProvider.notifier).deleteSection(
        target.id,
      );

      expect(
        container
            .read(taskListProvider)
            .firstWhere((t) => t.id == 't1')
            .sectionId,
        other.id,
      );
    },
  );
}
