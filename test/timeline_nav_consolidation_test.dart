import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/main.dart';
import 'package:amble/features/timeline/app_calendar_header.dart';
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

/// Covers the 2026-09-17 nav consolidation, requested directly: "1 nav
/// item, but when tapped again it switches view... view switch on top
/// similar like Tracked page." Task view and Timeline were two separate,
/// permanent nav destinations (indices 0/1) since 2026-09-12; this
/// reverses that into one destination whose displayed `TimelineDisplayMode`
/// is driven by `zoneViewEnabledSettingProvider`, toggled either by
/// tapping the already-selected nav item again or by
/// `AppCalendarHeader`'s own new switcher button — both reach the same
/// provider, so this file checks both paths land on the same state.
void main() {
  late Box<Task> taskBox;
  late Box<dynamic> prefsBox;
  late Box<Category> categoryBox;
  late Box<Zone> zoneBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<TaskTemplate> taskTemplateBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_nav_consolidation');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    prefsBox = await Hive.openBox<dynamic>('test_prefs_$stamp');
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

  // `ZoneViewEnabledSetting.set` awaits a real Hive write before updating
  // `state` — a bare `tester.tap` + `pump()` races that write under
  // flutter_test's synchronous zone (see docs/ERROR_LOG.md's `runAsync`
  // entries). Mirrors `exit_confirmation_test.dart`'s `_tapAndSettle`
  // shape exactly: tap, pump, then drain the real-I/O continuation, all
  // inside ONE `runAsync` block.
  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await tester.pump();
      await Future<void>.delayed(Duration.zero);
      // One more frame to actually rebuild off the now-updated provider
      // state — the drain above only guarantees the real Hive write (and
      // `state = value` afterward) has happened, not that a frame has
      // been scheduled/pumped to reflect it in the tree yet.
      await tester.pump();
    });
  }

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
    // NOT pumpAndSettle — see edit_mode_hides_main_nav_test.dart's own
    // pumpHome for why (something in the combined IndexedStack tree never
    // settles in a plain widget-test environment).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  testWidgets(
    'the nav bar has ONE Timeline destination, not separate Task view / '
    'Timeline tabs',
    (tester) async {
      await pumpHome(tester);

      expect(find.byTooltip('Timeline'), findsOneWidget);
      expect(find.byTooltip('Task view'), findsNothing);
    },
  );

  testWidgets('tapping the already-selected Timeline destination again toggles '
      'zoneViewEnabledSettingProvider', (tester) async {
    final container = await pumpHome(tester);
    expect(container.read(zoneViewEnabledSettingProvider), isFalse);

    await tapAndSettle(tester, find.byTooltip('Timeline'));

    expect(container.read(zoneViewEnabledSettingProvider), isTrue);

    await tapAndSettle(tester, find.byTooltip('Timeline'));

    expect(container.read(zoneViewEnabledSettingProvider), isFalse);
  });

  testWidgets(
    'the header switcher button and the nav-tap toggle reach the SAME '
    'provider — flipping one is reflected by the other',
    (tester) async {
      final container = await pumpHome(tester);

      await tapAndSettle(tester, find.byTooltip('Switch to Timeline'));

      expect(container.read(zoneViewEnabledSettingProvider), isTrue);
      expect(find.byTooltip('Switch to Task view'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Timeline'));

      expect(container.read(zoneViewEnabledSettingProvider), isFalse);
      expect(find.byTooltip('Switch to Timeline'), findsOneWidget);
    },
  );

  testWidgets(
    'navigating AWAY to another tab and back does not itself change the '
    'view — only an explicit toggle does',
    (tester) async {
      final container = await pumpHome(tester);

      await tapAndSettle(tester, find.byTooltip('Timeline'));
      expect(container.read(zoneViewEnabledSettingProvider), isTrue);

      await tapAndSettle(tester, find.byTooltip('Inbox'));
      await tapAndSettle(tester, find.byTooltip('Timeline'));

      // Navigating away and back is a plain "open" tap, not a same-index
      // repeat — must land on whatever was already selected, not flip it.
      expect(container.read(zoneViewEnabledSettingProvider), isTrue);
      expect(find.byType(AppCalendarHeader), findsOneWidget);
    },
  );
}
