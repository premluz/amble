import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/hive_registrar.g.dart';
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
    Hive.init('./.dart_tool/test_hive_overlap_lane_transition');
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
    required List<ExternalCalendarEvent> events,
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      for (final task in tasks) {
        await taskBox.put(task.id, task);
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
    'choosing Overlap: a task moved into a shared slot slides into its new '
    'lane instead of jumping sideways',
    (tester) async {
      final now = DateTime.now();
      final a = Task.create(
        title: 'Alpha',
        scheduledAt: DateTime(now.year, now.month, now.day, 9),
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.general,
      );
      final b = Task.create(
        title: 'Bravo',
        scheduledAt: DateTime(now.year, now.month, now.day, 11),
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.general,
      );
      await pumpTimeline(tester, tasks: [a, b], events: const []);

      Finder pillOf(Task task) => find.byWidgetPredicate(
        (w) => w is TaskCapsuleBlock && w.task.id == task.id,
      );
      final beforeX = tester.getTopLeft(pillOf(b)).dx;

      // The same write the Overlap choice commits: b now shares a's hour.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TimelineScreen)),
      );
      await tester.runAsync(
        () => container
            .read(taskListProvider.notifier)
            .rescheduleTask(b, DateTime(now.year, now.month, now.day, 9, 30)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final midX = tester.getTopLeft(pillOf(b)).dx;

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final afterX = tester.getTopLeft(pillOf(b)).dx;

      expect(afterX, isNot(beforeX), reason: 'b moved into another lane');
      final lo = beforeX < afterX ? beforeX : afterX;
      final hi = beforeX < afterX ? afterX : beforeX;
      expect(
        midX > lo && midX < hi,
        isTrue,
        reason:
            'mid-transition b sits between its old and new lane '
            '($beforeX → $midX → $afterX), i.e. it slides, not jumps',
      );
    },
  );
}
