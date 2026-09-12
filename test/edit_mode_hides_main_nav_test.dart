import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/main.dart';
import 'package:amble/core/widgets/app_floating_create_button.dart';
import 'package:amble/features/timeline/app_calendar_header.dart';
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
/// described hiding the bottom NavigationBar and the day-navigation bar
/// (day chips, the Task/Zone/List view-cycle button, the "+" create
/// button) while active, but neither had ANY wiring reacting to
/// `editModeEnabledProvider` at all — a real, missing piece, not a
/// duplicate of the (unrelated) task-edit-sheet full-screen-route
/// coverage from a separate feature.
///
/// **2026-09-12** — the old `DayStrip` (day chips + view-cycle button +
/// "+") is gone; day navigation moved to the new `AppCalendarHeader` (top
/// of screen), and the "+" is now an independently floating
/// `AppFloatingCreateButton` rather than living in a bottom bar. This
/// file's own assertions were updated to check for that widget instead —
/// the suppression behavior itself (hide the "+" and the nav while Edit
/// Mode/a draft is active) is unchanged, just applied to a different
/// widget. `AmbleHome` now opens on Task view (index 0, was Inbox) by
/// default, which is still a `TimelineScreen` — the same screen this
/// file's assertions always meant to exercise.
///
/// **Also 2026-09-12** — a follow-up report: hiding `AppCalendarHeader`
/// entirely while Edit Mode was on took its own close control down with
/// it, leaving no visible way to exit. `AppCalendarHeader` now stays
/// mounted throughout Edit Mode, collapsing to just its close button —
/// so unlike the NavigationBar/"+", it is never expected to disappear
/// from the tree here.
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
    // AmbleHome mounts EVERY tab (Task view, Timeline, Inbox, Tracked,
    // Settings) at
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

  testWidgets(
    'the bottom NavigationBar and the floating create button are both '
    'visible on an ordinary Task view (Edit Mode off)',
    (tester) async {
      final container = await pumpHome(tester);
      expect(container.read(editModeEnabledProvider), isFalse);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(AppFloatingCreateButton), findsOneWidget);
    },
  );

  testWidgets(
    'turning Edit Mode on hides the bottom NavigationBar and the floating '
    'create button, but keeps AppCalendarHeader mounted (collapsed to its '
    'own close button) — turning it back off restores all three to their '
    'normal shape',
    (tester) async {
      final container = await pumpHome(tester);
      expect(find.byType(AppCalendarHeader), findsOneWidget);

      container.read(editModeEnabledProvider.notifier).toggle();
      // NOT pumpAndSettle — EditModeWiggle's perpetually-repeating
      // animation never settles once Edit Mode is on. See
      // multi_task_selection_test.dart's own pumpTimeline for the same
      // fix and full explanation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(AppFloatingCreateButton), findsNothing);
      // Still mounted — this is the real gap this file was expanded to
      // cover: the header used to disappear entirely along with everything
      // else, taking its own only Edit Mode exit control down with it.
      expect(find.byType(AppCalendarHeader), findsOneWidget);
      expect(find.byTooltip('Done'), findsOneWidget);

      container.read(editModeEnabledProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(AppFloatingCreateButton), findsOneWidget);
      expect(find.byTooltip('Edit'), findsOneWidget);
    },
  );

  // Reported directly, from a screenshot: the quick-create overlay's own
  // small sheet "should cover main nav currently it opens above main
  // nav." Same mechanism as Edit Mode above — a live PendingTaskDraft
  // hides the bottom NavigationBar the same way Edit Mode does, so the
  // overlay (bottom-anchored inside TimelineScreen's own body) has that
  // space to occupy instead of stopping short above a still-visible bar.
  //
  // The create button's half was a follow-up report: "we don't show main
  // nav, we should not show also the days with view switch and + button
  // section, only the minisheet is visible in this scenario" — the first
  // pass only suppressed the NavigationBar, leaving the "+" still
  // rendering. Unlike Edit Mode, a live draft hides `AppCalendarHeader`
  // entirely too (see `timeline_screen.dart`'s own `if`) — this is the
  // ONE case the whole header still disappears for, since there is no
  // control on it that a draft needs to stay reachable.
  testWidgets(
    'starting a quick-create draft hides the bottom NavigationBar, the '
    'floating create button, AND AppCalendarHeader; clearing it restores '
    'all three — "only the minisheet is visible in this scenario"',
    (tester) async {
      final container = await pumpHome(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(AppFloatingCreateButton), findsOneWidget);
      expect(find.byType(AppCalendarHeader), findsOneWidget);

      container
          .read(pendingTaskDraftProvider.notifier)
          .start(scheduledAt: DateTime(2026, 9, 8, 9), durationMinutes: 30);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(AppFloatingCreateButton), findsNothing);
      expect(find.byType(AppCalendarHeader), findsNothing);

      container.read(pendingTaskDraftProvider.notifier).clear();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(AppFloatingCreateButton), findsOneWidget);
      expect(find.byType(AppCalendarHeader), findsOneWidget);
    },
  );
}
