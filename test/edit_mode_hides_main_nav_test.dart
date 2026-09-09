import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/main.dart';
import 'package:amble/features/timeline/day_strip.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';
import 'package:amble/features/timeline/pending_task_draft_provider.dart';
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
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_task_template_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

import 'support/fake_notification_service.dart';
import 'support/seeded_category_box.dart';

/// Covers a real gap, reported directly: Edit Mode's own docs/plan
/// described hiding the bottom NavigationBar and DayStrip (day chips,
/// the Task/Zone/List view-cycle button, the "+" create button) while
/// active, but neither `main.dart`'s bottom nav nor `day_strip.dart` had
/// ANY wiring reacting to `editModeEnabledProvider` at all — a real,
/// missing piece, not a duplicate of the (unrelated) task-edit-sheet
/// full-screen-route coverage from a separate feature.
void main() {
  late Box<Task> taskBox;
  late Box<dynamic> prefsBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<TaskTemplate> taskTemplateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_edit_mode_nav');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    prefsBox = await Hive.openBox<dynamic>('test_prefs_$stamp');
    // AmbleHome mounts EVERY tab (Inbox, Timeline, Tracked, Settings) at
    // once via IndexedStack, so every repository provider any of them
    // reads needs a real box — not just Task/preferences.
    categoryBox = await openSeededCategoryBox('test_categories_$stamp');
    zoneBox = await Hive.openBox<Zone>('test_zones_$stamp');
    trackedBehaviorBox = await Hive.openBox<TrackedBehavior>(
      'test_tracked_behaviors_$stamp',
    );
    taskTemplateBox = await Hive.openBox<TaskTemplate>(
      'test_task_templates_$stamp',
    );
  });

  tearDown(() async {
    await taskBox.deleteFromDisk();
    await prefsBox.deleteFromDisk();
    await categoryBox.deleteFromDisk();
    await zoneBox.deleteFromDisk();
    await trackedBehaviorBox.deleteFromDisk();
    await taskTemplateBox.deleteFromDisk();
  });

  Future<ProviderContainer> pumpHome(WidgetTester tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(prefsBox),
          ),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categoryBox),
          ),
          zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zoneBox)),
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(trackedBehaviorBox),
          ),
          taskTemplateRepositoryProvider.overrideWithValue(
            HiveTaskTemplateRepository(taskTemplateBox),
          ),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              theme: ThemeData(
                useMaterial3: true,
                extensions: [AmbleTheme.light],
              ),
              home: const AmbleHome(),
            );
          },
        ),
      ),
    );
    // NOT pumpAndSettle: AmbleHome mounts every tab at once via
    // IndexedStack, and something in that combined tree never settles in
    // a plain widget-test environment (not Edit Mode's own wiggle, which
    // is off by default here — this happens even before it's ever
    // toggled on). Bounded pumps are enough to mount and paint everything
    // this file's own assertions need.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  testWidgets('the bottom NavigationBar and DayStrip are both visible on an '
      'ordinary Timeline (Edit Mode off)', (tester) async {
    final container = await pumpHome(tester);
    expect(container.read(editModeEnabledProvider), isFalse);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(DayStrip), findsOneWidget);
  });

  testWidgets('turning Edit Mode on hides both the bottom NavigationBar and '
      'DayStrip, and turning it back off restores them', (tester) async {
    final container = await pumpHome(tester);

    container.read(editModeEnabledProvider.notifier).toggle();
    // NOT pumpAndSettle — EditModeWiggle's perpetually-repeating
    // animation never settles once Edit Mode is on. See
    // multi_task_selection_test.dart's own pumpTimeline for the same
    // fix and full explanation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(DayStrip), findsNothing);

    container.read(editModeEnabledProvider.notifier).toggle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(DayStrip), findsOneWidget);
  });

  // Reported directly, from a screenshot: the quick-create overlay's own
  // small sheet "should cover main nav currently it opens above main
  // nav." Same mechanism as Edit Mode above — a live PendingTaskDraft
  // hides the bottom NavigationBar the same way Edit Mode does, so the
  // overlay (bottom-anchored inside TimelineScreen's own body) has that
  // space to occupy instead of stopping short above a still-visible bar.
  //
  // The DayStrip half was a follow-up report: "we don't show main nav, we
  // should not show also the days with view switch and + button section,
  // only the minisheet is visible in this scenario" — the first pass only
  // suppressed the NavigationBar, leaving DayStrip still rendering.
  testWidgets(
    'starting a quick-create draft hides BOTH the bottom NavigationBar '
    'and the DayStrip (days, view switch, "+"), and clearing it restores '
    'both — "only the minisheet is visible in this scenario"',
    (tester) async {
      final container = await pumpHome(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(DayStrip), findsOneWidget);

      container
          .read(pendingTaskDraftProvider.notifier)
          .start(scheduledAt: DateTime(2026, 9, 8, 9), durationMinutes: 30);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(DayStrip), findsNothing);

      container.read(pendingTaskDraftProvider.notifier).clear();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(DayStrip), findsOneWidget);
    },
  );
}
