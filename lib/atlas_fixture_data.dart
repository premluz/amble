import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/section.dart';
import 'package:amble/shared/models/task.dart';

const atlasInboxScenarioId = 'seeded-inbox';

abstract final class AtlasInboxFixtureIds {
  static const String workSection = '00000000-0000-4000-8000-000000000201';
  static const String personalSection = '00000000-0000-4000-8000-000000000202';
  static const String launchTask = '00000000-0000-4000-8000-000000000301';
  static const String dentistTask = '00000000-0000-4000-8000-000000000302';
  static const String walkTask = '00000000-0000-4000-8000-000000000303';
  static const String workCategory = BuiltInCategoryIds.work;
  static const String personalCategory = BuiltInCategoryIds.personalNew;
  static const int generalColorToken = 0;
  static const int workColorToken = 2;
  static const int personalColorToken = 4;
}

class AtlasInboxFixtureData {
  const AtlasInboxFixtureData({
    required this.tasks,
    required this.sections,
    required this.categories,
  });

  final List<Task> tasks;
  final List<Section> sections;
  final List<Category> categories;

  factory AtlasInboxFixtureData.seeded({DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day, 10);
    final yesterday = DateTime(current.year, current.month, current.day - 1);

    return AtlasInboxFixtureData(
      tasks: [
        Task(
          id: AtlasInboxFixtureIds.launchTask,
          title: 'Review launch checklist',
          sectionId: AtlasInboxFixtureIds.workSection,
          createdAt: today.add(const Duration(minutes: 20)),
        ),
        Task(
          id: AtlasInboxFixtureIds.dentistTask,
          title: 'Book a dentist appointment',
          notes: 'Check the opening hours first.',
          createdAt: yesterday.add(const Duration(hours: 15)),
        ),
        Task(
          id: AtlasInboxFixtureIds.walkTask,
          title: 'Plan a weekend walk',
          notes: 'Pick a route near the coast.',
          sectionId: AtlasInboxFixtureIds.personalSection,
          createdAt: yesterday.add(const Duration(hours: 11)),
        ),
      ],
      sections: [
        Section(id: AtlasInboxFixtureIds.workSection, name: 'Work'),
        Section(id: AtlasInboxFixtureIds.personalSection, name: 'Personal'),
      ],
      categories: [
        Category(
          id: BuiltInCategoryIds.general,
          name: 'General',
          colorToken: AtlasInboxFixtureIds.generalColorToken,
          emoji: '',
          isBuiltIn: true,
        ),
        Category(
          id: AtlasInboxFixtureIds.workCategory,
          name: 'Work',
          colorToken: AtlasInboxFixtureIds.workColorToken,
          emoji: '',
          isBuiltIn: true,
        ),
        Category(
          id: AtlasInboxFixtureIds.personalCategory,
          name: 'Personal',
          colorToken: AtlasInboxFixtureIds.personalColorToken,
          emoji: '',
          isBuiltIn: true,
        ),
      ],
    );
  }
}
