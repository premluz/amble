import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/onboarding_profile.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/task_template_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/providers/zone_facet_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';
import 'package:amble/shared/repositories/zone_facet_repository.dart';
import 'package:amble/shared/services/onboarding_materializer.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// End-to-end coverage for [materializeOnboardingProfile] against REAL
/// Hive boxes (not memory fakes) — this is deliberately the one place in
/// this feature's test suite that exercises every entity's actual create
/// path together, matching the work order's own "verified end-to-end, not
/// just schema-validated" instruction for the catalog. Real Hive I/O under
/// `flutter_test`'s pump-based zone hangs without `tester.runAsync` — see
/// docs/ERROR_LOG.md; this applies even to a direct notifier call with no
/// widget tap involved, which is exactly what this test does.
///
/// [materializeOnboardingProfile] takes a [WidgetRef], not a plain [Ref]
/// (checked directly — [WidgetRef] does not extend [Ref] in this Riverpod
/// version), so this test captures a real one from a mounted [Consumer]
/// rather than driving the function from a bare [ProviderContainer].
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<TaskTemplate> templateBox;
  late Box<TrackedBehavior> behaviorBox;
  late Box<Zone> zoneBox;
  late Box<dynamic> facetBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_onboarding_materializer');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
    templateBox = await Hive.openBox<TaskTemplate>('test_templates_$stamp');
    behaviorBox = await Hive.openBox<TrackedBehavior>('test_behaviors_$stamp');
    zoneBox = await Hive.openBox<Zone>('test_zones_$stamp');
    facetBox = await Hive.openBox<dynamic>('test_facets_$stamp');
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await templateBox.close();
    await behaviorBox.close();
    await zoneBox.close();
    await facetBox.close();
  });

  Future<WidgetRef> pumpRef(WidgetTester tester) async {
    late WidgetRef capturedRef;
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
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(behaviorBox),
          ),
          zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zoneBox)),
          zoneFacetRepositoryProvider.overrideWithValue(
            HiveZoneFacetRepository(facetBox),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return capturedRef;
  }

  const profile = OnboardingProfile(
    id: 'test_profile',
    title: 'Test Profile',
    description: 'A profile for testing materialization.',
    quizTags: {},
    zones: [
      OnboardingZoneEntry(
        title: 'Focus block',
        weekdays: {1, 2},
        startMinutes: 540,
        endMinutes: 600,
      ),
    ],
    templates: [
      OnboardingTemplateEntry(
        title: 'Review notes',
        categoryName: 'work',
        durationMinutes: 20,
        notes: 'Test note',
      ),
    ],
    tasks: [
      OnboardingTaskEntry(
        title: 'Take a walk',
        categoryName: 'health',
        startMinutes: 480,
        durationMinutes: 15,
      ),
    ],
    trackedBehaviors: [
      OnboardingTrackedBehaviorEntry(
        title: 'Sleep well',
        targetType: 'binary',
        timesPerWeek: 7,
      ),
    ],
    notes: ['Buy milk', 'Call the bank'],
  );

  testWidgets(
    'materializes zones, templates, tasks, tracked behaviors, and notes '
    'into real independent Hive rows',
    (tester) async {
      final ref = await pumpRef(tester);

      await tester.runAsync(() async {
        await materializeOnboardingProfile(
          ref,
          profile,
          firstDay: DateTime(2026, 9, 16),
        );
        await Future<void>.delayed(Duration.zero);
      });

      expect(zoneBox.values, hasLength(2), reason: '2 weekdays -> 2 zones');
      expect(templateBox.values, hasLength(1));
      expect(templateBox.values.single.title, 'Review notes');
      expect(templateBox.values.single.categoryId, BuiltInCategoryIds.work);

      final scheduledTasks = taskBox.values
          .where((t) => t.scheduledAt != null)
          .toList();
      expect(scheduledTasks, hasLength(1));
      expect(scheduledTasks.single.title, 'Take a walk');
      expect(scheduledTasks.single.categoryId, BuiltInCategoryIds.health);
      expect(scheduledTasks.single.scheduledAt, DateTime(2026, 9, 16, 8, 0));

      final capturedTasks = taskBox.values
          .where((t) => t.scheduledAt == null)
          .toList();
      expect(capturedTasks, hasLength(2));
      expect(capturedTasks.map((t) => t.title).toSet(), {
        'Buy milk',
        'Call the bank',
      });

      expect(behaviorBox.values, hasLength(1));
      expect(behaviorBox.values.single.title, 'Sleep well');
    },
  );

  testWidgets('trackedBehaviorEnabled: false skips tracked behaviors entirely, '
      'materializes everything else', (tester) async {
    final ref = await pumpRef(tester);

    await tester.runAsync(() async {
      await materializeOnboardingProfile(
        ref,
        profile,
        firstDay: DateTime(2026, 9, 16),
        trackedBehaviorEnabled: false,
      );
      await Future<void>.delayed(Duration.zero);
    });

    expect(behaviorBox.values, isEmpty);
    expect(templateBox.values, hasLength(1));
    expect(zoneBox.values, hasLength(2));
  });

  testWidgets(
    'an unknown categoryName throws a clear error rather than silently '
    'defaulting',
    (tester) async {
      final ref = await pumpRef(tester);
      const badProfile = OnboardingProfile(
        id: 'bad',
        title: 'Bad',
        description: '',
        quizTags: {},
        zones: [],
        templates: [
          OnboardingTemplateEntry(title: 'X', categoryName: 'not_real'),
        ],
        tasks: [],
        trackedBehaviors: [],
        notes: [],
      );

      await tester.runAsync(() async {
        await expectLater(
          () => materializeOnboardingProfile(ref, badProfile),
          throwsStateError,
        );
      });
    },
  );
}
