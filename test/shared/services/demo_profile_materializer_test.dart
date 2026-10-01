import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/label_presets.dart';
import 'package:amble/shared/models/onboarding_profile.dart';
import 'package:amble/shared/models/section.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/section_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/task_template_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/providers/zone_facet_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_section_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';
import 'package:amble/shared/repositories/zone_facet_repository.dart';
import 'package:amble/shared/services/onboarding_materializer.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// The bundled Demo profile, materialized end to end against real boxes:
/// labels it names are created from the presets, and its Things land in
/// their sections.
void main() {
  late Box<Task> tasks;
  late Box<Category> categories;
  late Box<TaskTemplate> templates;
  late Box<TrackedBehavior> behaviors;
  late Box<Zone> zones;
  late Box<dynamic> facets;
  late Box<Section> sections;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_demo_profile');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    tasks = await Hive.openBox<Task>('tasks_$stamp');
    categories = await openSeededCategoryBox('categories_$stamp');
    templates = await Hive.openBox<TaskTemplate>('templates_$stamp');
    behaviors = await Hive.openBox<TrackedBehavior>('behaviors_$stamp');
    zones = await Hive.openBox<Zone>('zones_$stamp');
    facets = await Hive.openBox<dynamic>('facets_$stamp');
    sections = await Hive.openBox<Section>('sections_$stamp');
  });

  tearDown(() async {
    for (final box in [
      tasks,
      categories,
      templates,
      behaviors,
      zones,
      facets,
      sections,
    ]) {
      await box.close();
    }
  });

  testWidgets('the Demo profile materializes every part', (tester) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(tasks)),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categories),
          ),
          taskTemplateRepositoryProvider.overrideWithValue(
            HiveTaskTemplateRepository(templates),
          ),
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(behaviors),
          ),
          zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zones)),
          zoneFacetRepositoryProvider.overrideWithValue(
            HiveZoneFacetRepository(facets),
          ),
          sectionRepositoryProvider.overrideWithValue(
            HiveSectionRepository(sections),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, captured, _) {
              ref = captured;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final catalog =
        jsonDecode(File('assets/onboarding/profiles.json').readAsStringSync())
            as Map<String, dynamic>;
    final demo = (catalog['profiles'] as List)
        .map((p) => OnboardingProfile.fromJson(p as Map<String, dynamic>))
        .singleWhere((p) => p.id == 'demo');

    await tester.runAsync(() async {
      await materializeOnboardingProfile(
        ref,
        demo,
        firstDay: DateTime(2026, 9, 30),
        trackedBehaviorEnabled: true,
      );
    });

    expect(templates.values, hasLength(demo.templates.length));
    expect(behaviors.values, hasLength(6));
    final scheduled = tasks.values.where((t) => t.scheduledAt != null);
    expect(scheduled, hasLength(demo.tasks.length));

    // "Gym" isn't a built-in, so it was created from its preset.
    final gym = categories.values.singleWhere((c) => c.name == 'Gym');
    final preset = labelPresets.singleWhere((p) => p.name == 'Gym');
    expect(gym.iconCodePoint, preset.icon.codePoint);
    expect(gym.colorToken, preset.colorToken);
    expect(
      categories.values.where((c) => c.name == 'Focus'),
      hasLength(1),
      reason: 'a label used many times is created once',
    );

    final someday = sections.values.singleWhere((s) => s.name == 'Someday');
    final somedayThings = tasks.values.where((t) => t.sectionId == someday.id);
    expect(somedayThings.map((t) => t.title), contains('Learn to sail'));
    expect(sections.values, hasLength(6));
  });
}
