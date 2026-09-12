import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/features/timeline/external_event_capsule_block.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
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

/// End-to-end coverage, through the REAL `TimelineScreen`, for the
/// task/event stacking parity reported directly: "the imported tasks
/// should also stack in the same way as native tasks... They just can't
/// be moved, changed, or have their duration, time, or name updated, but
/// otherwise exactly the same, with different styling." The pure-algorithm
/// tests (`task_overlap_layout_test.dart`/`overlap_cluster_test.dart`) and
/// `overlap_cluster_block_test.dart` already cover the layout/rendering
/// logic in isolation; this file exists to catch a regression in the
/// WIRING between them inside `timeline_screen.dart` — the part no
/// isolated widget test can see.
///
/// `externalCalendarServiceProvider` overridden with a fake subclass whose
/// `fetchEvents` returns a fixed list directly — the documented test seam
/// for this service (see its own class doc comment) — so no real
/// `device_calendar` platform channel or permission prompt is ever
/// exercised. `calendarDisplayIdsSettingProvider` overridden to a
/// non-empty list so `externalCalendarEventsForRange` doesn't short-circuit
/// to empty before ever reaching the fake service.
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

void main() {
  late Box<Task> taskBox;
  late Box<Category> categoryBox;
  late Box<TrackedBehavior> trackedBehaviorBox;
  late Box<dynamic> preferencesBox;
  late Box<SyncedCalendarEvent> syncedCalendarEventBox;
  late Box<Zone> zoneBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_task_event_lane_sharing');
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
    required Task task,
    required List<ExternalCalendarEvent> events,
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() => taskBox.put(task.id, task));

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
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(
            body: TimelineScreen(mode: TimelineDisplayMode.spatial),
          ),
        ),
      ),
    );
    await tester.pump();
    // Drains the async externalCalendarEventsForRange fetch (a real
    // FutureProvider, even though the fake service resolves instantly) and
    // the frame it triggers once the event list actually arrives.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  testWidgets(
    'a task and an overlapping imported event render side by side, at '
    'different x positions — genuine lane sharing, not just independent '
    'positioning',
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
        start: DateTime(now.year, now.month, now.day, 9, 30),
        end: DateTime(now.year, now.month, now.day, 10, 30),
        sourceCalendarId: 'cal-1',
      );

      await pumpTimeline(tester, task: task, events: [event]);

      expect(find.byType(TaskCapsuleBlock), findsWidgets);
      expect(find.byType(ExternalEventCapsuleBlock), findsOneWidget);

      // The outer boxes both sit at the SAME fixed day-column origin (see
      // `ExternalEventCapsuleBlock.left`'s own doc comment) — only each
      // one's RAIL moves to its own lane. So lane-sharing is proven by
      // comparing rail x, not the outer box's own getTopLeft.
      final taskRailX = tester
          .getTopLeft(find.byType(TaskCapsuleBlock).first)
          .dx;
      final eventRailX = tester
          .getTopLeft(
            find
                .ancestor(
                  of: find.byIcon(Icons.calendar_today_outlined),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .dx;

      expect(
        eventRailX,
        isNot(taskRailX),
        reason:
            'an overlapping task and event must occupy DIFFERENT lanes — '
            'their rails landing on the same x means they are still '
            'positioning independently rather than sharing the lane '
            'layout, which is the exact regression this test guards '
            'against',
      );

      // And the two titles, in the SHARED text column, must line up at
      // the exact same x regardless of that lane difference — the bug
      // reported directly from a screenshot ("text not aligned wit hnative
      // tasks").
      final taskTitleX = tester.getTopLeft(find.text('Standup')).dx;
      final eventTitleX = tester.getTopLeft(find.text('Dentist')).dx;
      expect(
        eventTitleX,
        taskTitleX,
        reason:
            'titles must share one text column regardless of lane — an '
            'event in a deeper lane must not drag its own title along '
            'with it',
      );
    },
  );

  // **2026-09-12 — removed.** This tested List mode's own compact
  // Text.rich row rendering (`showHourLabels: false`), which is now
  // unreachable: List view is dropped from user reach entirely (Task
  // view is a permanent nav tab that always renders the spatial layout —
  // see TimelineScreen.mode). See docs/PROGRESS_LOG.md for the removal.
}
