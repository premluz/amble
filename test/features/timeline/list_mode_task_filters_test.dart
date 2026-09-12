import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/dev_config.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/external_event_capsule_block.dart';
import 'package:amble/features/timeline/timeline_screen.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/synced_calendar_event.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/tracked_behavior.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/calendar_providers.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/tracked_behavior_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_synced_calendar_event_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_tracked_behavior_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';
import 'package:amble/shared/services/calendar_permission_service.dart';
import 'package:amble/shared/services/external_calendar_service.dart';

import '../../support/fake_notification_service.dart';

/// Coverage, through the REAL `TimelineScreen`, for the two dev-config
/// List-view filters requested directly: "config for Only amble tasks
/// (affects list view only) and config (only important)". Both must:
/// (1) actually filter their target rows in List mode, and (2) leave Task
/// view completely untouched, exactly like `DevTimelineTaskTimeRangeVisible`
/// before them (see `list_mode_clustering_test.dart`/
/// `task_event_lane_sharing_test.dart` for the sibling patterns this
/// mirrors).
class _FakeExternalCalendarService extends ExternalCalendarService {
  _FakeExternalCalendarService(this._events)
    : super(
        dc.DeviceCalendarPlugin(),
        CalendarPermissionService(dc.DeviceCalendarPlugin()),
      );

  final List<ExternalCalendarEvent> _events;

  @override
  Future<List<ExternalCalendarEvent>> fetchEvents({
    required List<String> calendarIds,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    Set<String> excludeDeviceEventIds = const {},
  }) async => _events;
}

class _FixedCalendarDisplayIds extends CalendarDisplayIdsSetting {
  @override
  List<String> build() => const ['cal-1'];
}

class _FixedShowHourLabels extends ShowHourLabelsSetting {
  _FixedShowHourLabels(this._value);

  final bool _value;

  @override
  bool build() => _value;
}

class _FixedZoneViewEnabled extends ZoneViewEnabledSetting {
  _FixedZoneViewEnabled(this._value);

  final bool _value;

  @override
  bool build() => _value;
}

class _FixedOnlyAmbleTasks extends DevHideImportedTasks {
  _FixedOnlyAmbleTasks(this._value);

  final bool _value;

  @override
  bool build() => _value;
}

class _FixedOnlyImportant extends DevTimelineListOnlyImportant {
  _FixedOnlyImportant(this._value);

  final bool _value;

  @override
  bool build() => _value;
}

void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  late Box<SyncedCalendarEvent> syncedCalendarEventBox;
  late Box<Zone> zoneBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_list_mode_task_filters');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$stamp');
    categoryBox = await Hive.openBox<Category>('test_categories_$stamp');
    await categoryBox.put(
      BuiltInCategoryIds.general,
      Category(
        id: BuiltInCategoryIds.general,
        name: 'General',
        colorToken: 0,
        emoji: '⚪',
        isBuiltIn: true,
      ),
    );
    trackedBehaviorBox = await Hive.openBox<TrackedBehavior>(
      'test_tracked_behaviors_$stamp',
    );
    preferencesBox = await Hive.openBox<dynamic>('test_preferences_$stamp');
    syncedCalendarEventBox = await Hive.openBox<SyncedCalendarEvent>(
      'test_synced_calendar_events_$stamp',
    );
    zoneBox = await Hive.openBox<Zone>('test_zones_$stamp');
  });

  tearDown(() async {
    await taskBox.close();
    await categoryBox.close();
    await trackedBehaviorBox.close();
    await preferencesBox.close();
    await syncedCalendarEventBox.close();
    await zoneBox.close();
  });

  Future<void> pumpTimeline(
    WidgetTester tester, {
    required List<Task> tasks,
    List<ExternalCalendarEvent> events = const [],
    List<Zone> zones = const [],
    required bool showHourLabels,
    bool zoneViewEnabled = false,
    bool onlyAmbleTasks = false,
    bool onlyImportant = false,
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      for (final task in tasks) {
        await taskBox.put(task.id, task);
      }
      for (final zone in zones) {
        await zoneBox.put(zone.id, zone);
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(HiveTaskRepository(taskBox)),
          categoryRepositoryProvider.overrideWithValue(
            HiveCategoryRepository(categoryBox),
          ),
          trackedBehaviorRepositoryProvider.overrideWithValue(
            HiveTrackedBehaviorRepository(trackedBehaviorBox),
          ),
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(preferencesBox),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          externalCalendarServiceProvider.overrideWithValue(
            _FakeExternalCalendarService(events),
          ),
          calendarDisplayIdsSettingProvider.overrideWith(
            () => _FixedCalendarDisplayIds(),
          ),
          syncedCalendarEventRepositoryProvider.overrideWithValue(
            HiveSyncedCalendarEventRepository(syncedCalendarEventBox),
          ),
          zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zoneBox)),
          showHourLabelsSettingProvider.overrideWith(
            () => _FixedShowHourLabels(showHourLabels),
          ),
          zoneViewEnabledSettingProvider.overrideWith(
            () => _FixedZoneViewEnabled(zoneViewEnabled),
          ),
          devHideImportedTasksProvider.overrideWith(
            () => _FixedOnlyAmbleTasks(onlyAmbleTasks),
          ),
          devTimelineListOnlyImportantProvider.overrideWith(
            () => _FixedOnlyImportant(onlyImportant),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(body: TimelineScreen()),
        ),
      ),
    );
    await tester.pump();
    // Drains the async externalCalendarEventsForRange fetch.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  group('Only Amble tasks (List view)', () {
    testWidgets('on in List mode hides imported calendar events entirely', (
      tester,
    ) async {
      final now = DateTime.now();
      final task = Task.create(
        title: 'Standup',
        scheduledAt: DateTime(now.year, now.month, now.day, 9),
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.general,
      );
      final event = ExternalCalendarEvent(
        id: 'evt-1',
        title: 'Dentist',
        start: DateTime(now.year, now.month, now.day, 13),
        end: DateTime(now.year, now.month, now.day, 14),
        sourceCalendarId: 'cal-1',
      );

      await pumpTimeline(
        tester,
        tasks: [task],
        events: [event],
        showHourLabels: false,
        onlyAmbleTasks: true,
      );

      // List mode renders each row as one Text.rich combining time +
      // title (see task_event_lane_sharing_test.dart's own comment on
      // this), so titles aren't standalone Text widgets — matched via
      // textContaining instead of an exact find.text.
      expect(find.textContaining('Standup'), findsWidgets);
      expect(find.textContaining('Dentist'), findsNothing);
      expect(find.byType(ExternalEventCapsuleBlock), findsNothing);
    });

    testWidgets(
      'off in List mode still shows imported calendar events (unchanged '
      'default)',
      (tester) async {
        final now = DateTime.now();
        final task = Task.create(
          title: 'Standup',
          scheduledAt: DateTime(now.year, now.month, now.day, 9),
          durationMinutes: 60,
          categoryId: BuiltInCategoryIds.general,
        );
        final event = ExternalCalendarEvent(
          id: 'evt-1',
          title: 'Dentist',
          start: DateTime(now.year, now.month, now.day, 13),
          end: DateTime(now.year, now.month, now.day, 14),
          sourceCalendarId: 'cal-1',
        );

        await pumpTimeline(
          tester,
          tasks: [task],
          events: [event],
          showHourLabels: false,
        );

        expect(find.textContaining('Dentist'), findsWidgets);
      },
    );

    testWidgets(
      'on in Task view has NO effect — imported events still show, since '
      'this setting is List-view only',
      (tester) async {
        final now = DateTime.now();
        final task = Task.create(
          title: 'Standup',
          scheduledAt: DateTime(now.year, now.month, now.day, 9),
          durationMinutes: 60,
          categoryId: BuiltInCategoryIds.general,
        );
        final event = ExternalCalendarEvent(
          id: 'evt-1',
          title: 'Dentist',
          start: DateTime(now.year, now.month, now.day, 13),
          end: DateTime(now.year, now.month, now.day, 14),
          sourceCalendarId: 'cal-1',
        );

        await pumpTimeline(
          tester,
          tasks: [task],
          events: [event],
          showHourLabels: true,
          onlyAmbleTasks: true,
        );

        expect(find.text('Dentist'), findsOneWidget);
      },
    );

    testWidgets(
      'on in Zone view also hides imported calendar events — requested '
      'directly, widening this toggle beyond List view alone',
      (tester) async {
        final now = DateTime.now();
        final task = Task.create(
          title: 'Standup',
          scheduledAt: DateTime(now.year, now.month, now.day, 9),
          durationMinutes: 60,
          categoryId: BuiltInCategoryIds.general,
        );
        final event = ExternalCalendarEvent(
          id: 'evt-1',
          title: 'Dentist',
          start: DateTime(now.year, now.month, now.day, 13),
          end: DateTime(now.year, now.month, now.day, 14),
          sourceCalendarId: 'cal-1',
        );

        await pumpTimeline(
          tester,
          tasks: [task],
          events: [event],
          showHourLabels: false,
          zoneViewEnabled: true,
          onlyAmbleTasks: true,
        );

        expect(find.textContaining('Standup'), findsWidgets);
        expect(find.textContaining('Dentist'), findsNothing);
      },
    );

    testWidgets(
      'off in Zone view still shows imported calendar events (unchanged '
      'default)',
      (tester) async {
        final now = DateTime.now();
        final task = Task.create(
          title: 'Standup',
          scheduledAt: DateTime(now.year, now.month, now.day, 9),
          durationMinutes: 60,
          categoryId: BuiltInCategoryIds.general,
        );
        final event = ExternalCalendarEvent(
          id: 'evt-1',
          title: 'Dentist',
          start: DateTime(now.year, now.month, now.day, 13),
          end: DateTime(now.year, now.month, now.day, 14),
          sourceCalendarId: 'cal-1',
        );

        await pumpTimeline(
          tester,
          tasks: [task],
          events: [event],
          showHourLabels: false,
          zoneViewEnabled: true,
        );

        expect(find.textContaining('Dentist'), findsWidgets);
      },
    );
  });

  group('Only important (List view)', () {
    testWidgets('on in List mode hides non-important tasks', (tester) async {
      final now = DateTime.now();
      final important = Task.create(
        title: 'Ship the release',
        scheduledAt: DateTime(now.year, now.month, now.day, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.general,
        isImportant: true,
      );
      final ordinary = Task.create(
        title: 'Water the plants',
        scheduledAt: DateTime(now.year, now.month, now.day, 13),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.general,
      );

      await pumpTimeline(
        tester,
        tasks: [important, ordinary],
        showHourLabels: false,
        onlyImportant: true,
      );

      expect(find.textContaining('Ship the release'), findsWidgets);
      expect(find.textContaining('Water the plants'), findsNothing);
    });

    testWidgets('off in List mode shows every task (unchanged default)', (
      tester,
    ) async {
      final now = DateTime.now();
      final important = Task.create(
        title: 'Ship the release',
        scheduledAt: DateTime(now.year, now.month, now.day, 9),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.general,
        isImportant: true,
      );
      final ordinary = Task.create(
        title: 'Water the plants',
        scheduledAt: DateTime(now.year, now.month, now.day, 13),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.general,
      );

      await pumpTimeline(
        tester,
        tasks: [important, ordinary],
        showHourLabels: false,
      );

      expect(find.textContaining('Water the plants'), findsWidgets);
    });

    testWidgets(
      'on in Task view has NO effect — non-important tasks still show, '
      'since this setting is List-view only',
      (tester) async {
        final now = DateTime.now();
        final important = Task.create(
          title: 'Ship the release',
          scheduledAt: DateTime(now.year, now.month, now.day, 9),
          durationMinutes: 30,
          categoryId: BuiltInCategoryIds.general,
          isImportant: true,
        );
        final ordinary = Task.create(
          title: 'Water the plants',
          scheduledAt: DateTime(now.year, now.month, now.day, 13),
          durationMinutes: 15,
          categoryId: BuiltInCategoryIds.general,
        );

        await pumpTimeline(
          tester,
          tasks: [important, ordinary],
          showHourLabels: true,
          onlyImportant: true,
        );

        expect(find.text('Water the plants'), findsOneWidget);
      },
    );
  });

  group('a zone whose only member is filtered out of List view', () {
    // Reported directly: "Error check operator used on a null value (also
    // no time no duration would apply to imported tasks)". A zone's
    // containment is resolved from the full task/event lists regardless of
    // either filter, so a zone containing ONLY a now-hidden member still
    // looked non-empty to `collapsedZoneBands`, which then tried to wrap a
    // band around zero actually-visible rows and force-unwrapped two nulls.
    testWidgets(
      'Only important hides the zone\'s sole (non-important) task without '
      'crashing',
      (tester) async {
        final now = DateTime.now();
        final zone = Zone.create(
          title: 'Focus block',
          startMinutes: 8 * 60,
          endMinutes: 10 * 60,
        );
        final ordinary = Task.create(
          title: 'Water the plants',
          scheduledAt: DateTime(now.year, now.month, now.day, 9),
          durationMinutes: 15,
          categoryId: BuiltInCategoryIds.general,
        );

        await pumpTimeline(
          tester,
          tasks: [ordinary],
          zones: [zone],
          showHourLabels: false,
          onlyImportant: true,
        );

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Water the plants'), findsNothing);
      },
    );

    testWidgets(
      'Only Amble tasks hides the zone\'s sole imported event without '
      'crashing',
      (tester) async {
        final now = DateTime.now();
        final zone = Zone.create(
          title: 'Focus block',
          startMinutes: 8 * 60,
          endMinutes: 10 * 60,
        );
        final event = ExternalCalendarEvent(
          id: 'evt-1',
          title: 'Dentist',
          start: DateTime(now.year, now.month, now.day, 9),
          end: DateTime(now.year, now.month, now.day, 9, 30),
          sourceCalendarId: 'cal-1',
        );

        await pumpTimeline(
          tester,
          tasks: const [],
          events: [event],
          zones: [zone],
          showHourLabels: false,
          onlyAmbleTasks: true,
        );

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Dentist'), findsNothing);
      },
    );
  });
}
