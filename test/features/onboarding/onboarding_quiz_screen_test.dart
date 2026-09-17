import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/onboarding/onboarding_quiz_screen.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_template.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/task_template_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/providers/zone_facet_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';
import 'package:amble/shared/repositories/zone_facet_repository.dart';
import 'package:amble/shared/services/onboarding_quiz.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// Covers the onboarding Profile quiz's own basic flow — the asset-backed
/// catalog load (`onboardingProfileCatalogProvider`) and every entity's
/// real create path both need REAL Hive boxes and `tester.runAsync`, same
/// shape as `onboarding_materializer_test.dart` — this test reaches the
/// same real I/O through the actual screen widgets instead of calling the
/// materializer directly.
void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<TaskTemplate> templateBox;
  late Box<TrackedBehavior> behaviorBox;
  late Box<Zone> zoneBox;
  late Box<dynamic> facetBox;
  late Box<dynamic> prefsBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_onboarding_quiz_screen');
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
    prefsBox = await Hive.openBox<dynamic>('test_prefs_$stamp');
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await templateBox.close();
    await behaviorBox.close();
    await zoneBox.close();
    await facetBox.close();
    await prefsBox.close();
  });

  Future<void> pumpQuiz(WidgetTester tester) async {
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
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(prefsBox),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const OnboardingQuizScreen(),
        ),
      ),
    );
  }

  testWidgets('Skip on the first question marks onboarding done immediately '
      'with nothing materialized', (tester) async {
    ProviderContainer? container;

    await tester.runAsync(() async {
      await pumpQuiz(tester);
      await tester.pumpAndSettle();
      container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await tester.tap(find.text('Skip').first);
      await tester.pump();
      await Future<void>.delayed(Duration.zero);
      await tester.pumpAndSettle();
    });

    expect(container!.read(hasCompletedOnboardingProvider), isTrue);
    expect(zoneBox.values, isEmpty);
    expect(templateBox.values, isEmpty);
    expect(taskBox.values, isEmpty);
  });

  testWidgets('answering every question reaches the result screen with a real '
      'matched profile', (tester) async {
    await tester.runAsync(() async {
      await pumpQuiz(tester);
      await tester.pumpAndSettle();

      // Answer all 3 questions by tapping the first option's label each
      // time — the exact profile matched isn't this test's concern
      // (onboarding_quiz_test.dart's own job); this just confirms the
      // flow actually reaches a result screen naming SOME real profile.
      for (final question in onboardingQuizQuestions) {
        await tester.tap(find.text(question.options.first.label));
        await tester.pumpAndSettle();
      }
    });

    expect(find.text('Your best match'), findsOneWidget);
    expect(find.text('Use this profile'), findsOneWidget);
  });
}
