import 'package:amble/core/clock_provider.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/calendar/calendar_auto_refresh.dart';
import 'package:amble/features/calendar/calendar_span.dart';
import 'package:amble/features/calendar/desktop_calendar_toolbar.dart';
import 'package:amble/features/calendar/events_on_day.dart';
import 'package:amble/features/calendar/month_event_row.dart';
import 'package:amble/features/calendar/month_view.dart';
import 'package:amble/features/calendar/week_event_block.dart';
import 'package:amble/features/calendar/week_task_card.dart';
import 'package:amble/features/calendar/week_view.dart';
import 'package:amble/features/calendar/week_zoom.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/synced_calendar_event.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/calendar_providers.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/week_hour_height_setting.dart';
import 'package:amble/shared/providers/week_task_style_setting.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';
import 'package:amble/shared/repositories/hive_synced_calendar_event_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';
import 'package:amble/shared/services/calendar_permission_service.dart';
import 'package:amble/shared/services/external_calendar_service.dart';
import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// Device-calendar events in the desktop Week and Month, the Week's zoom,
/// and the automatic calendar refresh. Today is Wednesday 14 October 2026.
final _wednesday = DateTime(2026, 10, 14, 12);

ExternalCalendarEvent _event(String title, DateTime start, DateTime end) =>
    ExternalCalendarEvent(
      id: title,
      title: title,
      start: start,
      end: end,
      sourceCalendarId: 'cal-1',
    );

class _FakeService extends ExternalCalendarService {
  _FakeService(this._events)
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

class _FixedCalendarIds extends CalendarDisplayIdsSetting {
  @override
  List<String> build() => const ['cal-1'];
}

/// In memory, so a setting written mid-gesture needs no real file I/O,
/// which the test clock can't finish.
class _MemoryPreferences implements PreferencesRepository {
  final values = <String, Object?>{};

  @override
  T? getValue<T>(String key) => values[key] as T?;

  @override
  Future<void> setValue<T>(String key, T value) async => values[key] = value;

  @override
  Future<void> removeValue(String key) async => values.remove(key);

  @override
  List<String> keys() => values.keys.toList();
}

void main() {
  late Box<Task> tasks;
  late _MemoryPreferences prefs;
  late Box<Category> categories;
  late Box<Zone> zones;
  late Box<SyncedCalendarEvent> synced;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_calendar_events_zoom');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    tasks = await Hive.openBox<Task>('tasks_$stamp');
    prefs = _MemoryPreferences();
    categories = await openSeededCategoryBox('categories_$stamp');
    zones = await Hive.openBox<Zone>('zones_$stamp');
    synced = await Hive.openBox<SyncedCalendarEvent>('synced_$stamp');
  });

  tearDown(() async {
    for (final box in [tasks, categories, zones, synced]) {
      await box.deleteFromDisk();
    }
  });

  Future<ProviderContainer> pump(
    WidgetTester tester,
    CalendarSpan span, {
    List<ExternalCalendarEvent> events = const [],
    List<Task> seed = const [],
    bool autoRefresh = false,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      for (final t in seed) {
        await tasks.put(t.id, t);
      }
    });
    final container = ProviderContainer(
      overrides: [
        nowProvider.overrideWithValue(() => _wednesday),
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(tasks)),
        preferencesRepositoryProvider.overrideWithValue(prefs),
        categoryRepositoryProvider.overrideWithValue(
          HiveCategoryRepository(categories),
        ),
        zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zones)),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        externalCalendarServiceProvider.overrideWithValue(_FakeService(events)),
        calendarDisplayIdsSettingProvider.overrideWith(_FixedCalendarIds.new),
        syncedCalendarEventRepositoryProvider.overrideWithValue(
          HiveSyncedCalendarEventRepository(synced),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(calendarSpanProvider.notifier).set(span);
    Widget body = Consumer(
      builder: (context, ref, _) => Column(
        children: [
          const DesktopCalendarToolbar(),
          Expanded(
            child: switch (ref.watch(calendarSpanProvider)) {
              CalendarSpan.day => const Text('day view'),
              CalendarSpan.week => const WeekView(),
              CalendarSpan.month => const MonthView(),
            },
          ),
        ],
      ),
    );
    if (autoRefresh) body = CalendarAutoRefresh(child: body);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(body: body),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  final standup = _event(
    'Standup',
    DateTime(2026, 10, 14, 9),
    DateTime(2026, 10, 14, 10),
  );

  testWidgets('the week draws a device event as a neutral pill with its '
      'title, and a whole-day event is left to Month', (tester) async {
    await pump(
      tester,
      CalendarSpan.week,
      events: [
        standup,
        _event('Holiday', DateTime(2026, 10, 15), DateTime(2026, 10, 16)),
      ],
    );
    expect(find.byType(WeekEventPill), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(WeekEventText),
        matching: find.text('Standup'),
      ),
      findsOneWidget,
    );
    expect(find.text('Holiday'), findsNothing);
  });

  testWidgets('in blocks style an event shares its column with an '
      'overlapping task, side by side', (tester) async {
    final container = await pump(
      tester,
      CalendarSpan.week,
      events: [standup],
      seed: [
        Task.create(
          title: 'Design',
          scheduledAt: DateTime(2026, 10, 14, 9),
          durationMinutes: 60,
          categoryId: BuiltInCategoryIds.work,
        ),
      ],
    );
    await tester.runAsync(
      () => container
          .read(weekTaskStyleSettingProvider.notifier)
          .set(WeekTaskStyle.blocks),
    );
    await tester.pumpAndSettle();
    final event = tester.getRect(find.byType(WeekEventCard));
    final task = tester.getRect(find.byType(WeekTaskCard));
    expect(event.overlaps(task), isFalse);
    expect(event.width, closeTo(task.width, 0.5));
    expect(event.top, task.top);
  });

  testWidgets('the month lists a device event with the tasks and counts it '
      'toward "+N more"', (tester) async {
    await pump(
      tester,
      CalendarSpan.month,
      events: [
        for (var i = 0; i < CalendarGridTokens.monthVisibleTasks + 1; i++)
          _event(
            'Event $i',
            DateTime(2026, 10, 14, 8 + i),
            DateTime(2026, 10, 14, 9 + i),
          ),
      ],
    );
    expect(
      find.byType(MonthEventRow),
      findsNWidgets(CalendarGridTokens.monthVisibleTasks),
    );
    expect(find.text('+1 more'), findsOneWidget);
  });

  test('eventsOnDay keeps what overlaps the day, minutesOnDay clips to it', () {
    final day = DateTime(2026, 10, 14);
    final overnight = _event(
      'Night',
      DateTime(2026, 10, 13, 22),
      DateTime(2026, 10, 14, 2),
    );
    final other = _event(
      'Other',
      DateTime(2026, 10, 15, 9),
      DateTime(2026, 10, 15, 10),
    );
    expect(eventsOnDay([other, standup, overnight], day), [overnight, standup]);
    expect(minutesOnDay(overnight.start, day), 0);
    expect(minutesOnDay(overnight.end, day), 120);
    expect(minutesOnDay(DateTime(2026, 10, 16), day), Duration.minutesPerDay);
    expect(isAllDay(overnight), isFalse);
    expect(
      isAllDay(_event('Day', DateTime(2026, 10, 14), DateTime(2026, 10, 15))),
      isTrue,
    );
  });

  test('the anchored offset keeps the time under the pointer still', () {
    // 100px into the viewport, scrolled 200px: at 40px/hour that is 7.5h.
    final offset = weekAnchoredScrollOffset(
      scrollOffset: 200,
      anchorY: 100,
      fromHeight: 40,
      toHeight: 80,
    );
    expect(offset, 500);
    expect((offset + 100) / 80, 7.5);
  });

  testWidgets('the toolbar zooms the week in and out within limits, and '
      'remembers it', (tester) async {
    final container = await pump(tester, CalendarSpan.week);
    final start = container.read(weekHourHeightSettingProvider);
    expect(start, CalendarGridTokens.weekHourHeight);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(
      container.read(weekHourHeightSettingProvider),
      closeTo(start * CalendarGridTokens.weekZoomStep, 0.001),
    );
    expect(prefs.values[PreferenceKeys.weekHourHeight], isNotNull);

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();
    }
    expect(
      container.read(weekHourHeightSettingProvider),
      WeekHourHeightSetting.min,
    );
  });

  testWidgets('zoom buttons appear only in the week', (tester) async {
    await pump(tester, CalendarSpan.month);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets('Ctrl+scroll over the week zooms it instead of scrolling', (
    tester,
  ) async {
    final container = await pump(tester, CalendarSpan.week);
    final before = container.read(weekHourHeightSettingProvider);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(); // the grid starts ignoring pointers
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    final at = tester.getCenter(find.byType(WeekView));
    await tester.sendEventToBinding(mouse.hover(at));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(container.read(weekHourHeightSettingProvider), greaterThan(before));
  });

  testWidgets('calendars re-read on resume, on a macOS change signal '
      '(debounced), and on the periodic timer', (tester) async {
    final container = await pump(tester, CalendarSpan.week, autoRefresh: true);
    int count() => container.read(externalCalendarRefreshProvider);
    expect(count(), 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(count(), 1);

    Future<void> signal() =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'com.amble/calendar_changes',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('changed'),
          ),
          (_) {},
        );
    await signal();
    await signal();
    expect(count(), 1, reason: 'debounced');
    await tester.pump(const Duration(seconds: 2));
    expect(count(), 2, reason: 'a burst is one refresh');

    await tester.pump(calendarPollInterval);
    expect(count(), 3);
  });
}
