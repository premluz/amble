import 'package:amble/core/clock_provider.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/calendar/calendar_span.dart';
import 'package:amble/features/calendar/week_draft_block.dart';
import 'package:amble/features/calendar/week_drag.dart';
import 'package:amble/features/calendar/week_event_block.dart';
import 'package:amble/features/calendar/week_task_block.dart';
import 'package:amble/features/calendar/week_task_card.dart';
import 'package:amble/features/calendar/week_view.dart';
import 'package:amble/features/timeline/completion_checkbox.dart';
import 'package:amble/features/timeline/pending_task_draft_provider.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/synced_calendar_event.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/calendar_providers.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/week_task_style_setting.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_synced_calendar_event_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';
import 'package:amble/shared/repositories/task_repository.dart';
import 'package:amble/shared/services/calendar_permission_service.dart';
import 'package:amble/shared/services/external_calendar_service.dart';
import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// Editing in the desktop week, as on the Day screen: move (also to another
/// day), resize, the overlap choice, create, complete. Today is Wednesday
/// 14 October 2026; the week runs Monday 12 to Sunday 18. Writes go to
/// in-memory stores, since a real Hive write can't finish on the test clock.
final _wednesday = DateTime(2026, 10, 14, 12);
const _hour = CalendarGridTokens.weekHourHeight;

class _MemoryTasks implements TaskRepository {
  final tasks = <String, Task>{};

  @override
  List<Task> getTasks() => tasks.values.toList();

  @override
  Task? getTaskById(String id) => tasks[id];

  @override
  Future<void> saveTask(Task task) async => tasks[task.id] = task;

  @override
  Future<void> deleteTask(String id) async => tasks.remove(id);
}

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

Task _task(String title, int day, int hour, {int minutes = 60}) => Task.create(
  title: title,
  scheduledAt: DateTime(2026, 10, day, hour),
  durationMinutes: minutes,
  categoryId: BuiltInCategoryIds.work,
);

/// Drags with a mouse in small steps, so the gesture passes its slop.
Future<void> _mouseDrag(WidgetTester tester, Offset from, Offset by) async {
  final gesture = await tester.startGesture(
    from,
    kind: PointerDeviceKind.mouse,
  );
  const steps = 4;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(by / steps.toDouble());
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

class _FakeCalendar extends ExternalCalendarService {
  _FakeCalendar(this._events)
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

class _OneCalendar extends CalendarDisplayIdsSetting {
  @override
  List<String> build() => const ['cal-1'];
}

void main() {
  late Box<SyncedCalendarEvent> synced;
  late _MemoryTasks tasks;
  late Box<Category> categories;
  late Box<Zone> zones;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_week_edit');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    tasks = _MemoryTasks();
    categories = await openSeededCategoryBox('categories_$stamp');
    zones = await Hive.openBox<Zone>('zones_$stamp');
    synced = await Hive.openBox<SyncedCalendarEvent>('synced_$stamp');
  });

  tearDown(() async {
    await categories.deleteFromDisk();
    await zones.deleteFromDisk();
    await synced.deleteFromDisk();
  });

  Future<ProviderContainer> pump(
    WidgetTester tester,
    List<Task> seed, {
    WeekTaskStyle style = WeekTaskStyle.blocks,
    List<ExternalCalendarEvent> events = const [],
    bool checkbox = false,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final t in seed) {
      tasks.tasks[t.id] = t;
    }
    final prefs = _MemoryPreferences()
      ..values[PreferenceKeys.weekTaskStyle] = style.name
      ..values[PreferenceKeys.showCompletionCheckbox] = checkbox;
    final container = ProviderContainer(
      overrides: [
        nowProvider.overrideWithValue(() => _wednesday),
        taskRepositoryProvider.overrideWithValue(tasks),
        preferencesRepositoryProvider.overrideWithValue(prefs),
        categoryRepositoryProvider.overrideWithValue(
          HiveCategoryRepository(categories),
        ),
        zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zones)),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        externalCalendarServiceProvider.overrideWithValue(
          _FakeCalendar(events),
        ),
        calendarDisplayIdsSettingProvider.overrideWith(_OneCalendar.new),
        syncedCalendarEventRepositoryProvider.overrideWithValue(
          HiveSyncedCalendarEventRepository(synced),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(calendarSpanProvider.notifier).set(CalendarSpan.week);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(body: WeekView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder card(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(WeekTaskCard));

  Task stored(String title) =>
      tasks.tasks.values.firstWhere((t) => t.title == title);

  Offset dayWidth(WidgetTester tester) => Offset(
    tester.getCenter(find.text('Thu 15')).dx -
        tester.getCenter(find.text('Wed 14')).dx,
    0,
  );

  group('move', () {
    testWidgets('dragging a block down moves it later, with an Undo toast', (
      tester,
    ) async {
      await pump(tester, [_task('Design', 14, 9)]);
      await _mouseDrag(
        tester,
        tester.getCenter(card('Design').first),
        const Offset(0, _hour),
      );
      expect(stored('Design').scheduledAt, DateTime(2026, 10, 14, 10));
      expect(stored('Design').status, TaskStatus.rescheduled);
      expect(find.text("Moved 'Design'"), findsOneWidget);
    });

    testWidgets('dragging sideways moves it to that day, same time', (
      tester,
    ) async {
      await pump(tester, [_task('Design', 14, 9)]);
      await _mouseDrag(
        tester,
        tester.getCenter(card('Design').first),
        dayWidth(tester) * 2,
      );
      expect(stored('Design').scheduledAt, DateTime(2026, 10, 16, 9));
      final friday = tester.getCenter(find.text('Fri 16')).dx;
      expect(
        tester.getCenter(card('Design').first).dx,
        closeTo(friday, dayWidth(tester).dx / 2),
      );
    });

    testWidgets('pills move too, by their pill or their title', (tester) async {
      await pump(tester, [_task('Design', 14, 9)], style: WeekTaskStyle.pills);
      final title = find.descendant(
        of: find.byType(WeekTaskText),
        matching: find.text('Design'),
      );
      await _mouseDrag(
        tester,
        tester.getCenter(title),
        dayWidth(tester) + const Offset(0, _hour / 2),
      );
      expect(stored('Design').scheduledAt, DateTime(2026, 10, 15, 9, 30));
    });

    testWidgets('while dragging, the task stays faded in place and its '
        'landing spot shows the new time', (tester) async {
      await pump(tester, [_task('Design', 14, 9)]);
      final gesture = await tester.startGesture(
        tester.getCenter(card('Design').first),
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(0, _hour / 4));
        await tester.pump();
      }
      expect(card('Design'), findsNWidgets(2), reason: 'ghost and preview');
      final ghost = tester.widget<Opacity>(
        find
            .ancestor(of: card('Design').first, matching: find.byType(Opacity))
            .first,
      );
      expect(ghost.opacity, DragPreviewTokens.ghostOpacity);
      expect(find.textContaining('10:00'), findsWidgets);
      expect(stored('Design').scheduledAt, DateTime(2026, 10, 14, 9));
      await gesture.up();
      await tester.pump();
    });

    testWidgets('landing on another task asks Overlap / Push all / Trim; '
        'Push all moves the other one on', (tester) async {
      await pump(tester, [_task('Design', 14, 9), _task('Review', 15, 9)]);
      await _mouseDrag(
        tester,
        tester.getCenter(card('Design').first),
        dayWidth(tester),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Overlap'), findsOneWidget);
      expect(find.text('Trim'), findsOneWidget);
      expect(stored('Design').scheduledAt, DateTime(2026, 10, 14, 9));
      await tester.tap(find.text('Push all'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(stored('Design').scheduledAt, DateTime(2026, 10, 15, 9));
      expect(stored('Review').scheduledAt, DateTime(2026, 10, 15, 10));
    });

    testWidgets('device calendar events stay put', (tester) async {
      final container = await pump(
        tester,
        const [],
        events: [
          ExternalCalendarEvent(
            id: 'e1',
            title: 'Standup',
            start: DateTime(2026, 10, 14, 9),
            end: DateTime(2026, 10, 14, 10),
            sourceCalendarId: 'cal-1',
          ),
        ],
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(WeekEventCard)),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, _hour));
      await tester.pump();
      expect(container.read(weekDragProvider), isNull);
      await gesture.up();
    });
  });

  group('resize', () {
    testWidgets('the bottom edge changes the length', (tester) async {
      await pump(tester, [_task('Design', 14, 9)]);
      final rect = tester.getRect(card('Design').first);
      await _mouseDrag(
        tester,
        rect.bottomCenter - const Offset(0, 2),
        const Offset(0, _hour / 2),
      );
      expect(stored('Design').durationMinutes, 90);
      expect(stored('Design').scheduledAt, DateTime(2026, 10, 14, 9));
      expect(find.text("Resized 'Design'"), findsOneWidget);
    });

    testWidgets('the top edge moves the start, keeping the end', (
      tester,
    ) async {
      await pump(tester, [_task('Design', 14, 9)]);
      final rect = tester.getRect(card('Design').first);
      await _mouseDrag(
        tester,
        rect.topCenter + const Offset(0, 2),
        const Offset(0, -_hour / 2),
      );
      expect(stored('Design').scheduledAt, DateTime(2026, 10, 14, 8, 30));
      expect(stored('Design').durationMinutes, 90);
    });
  });

  testWidgets('click-dragging empty space draws a new task and opens it', (
    tester,
  ) async {
    final container = await pump(tester, const []);
    final wednesday = tester.getCenter(find.text('Wed 14')).dx;
    // The grid opens scrolled to 07:00.
    final nine =
        tester.getTopLeft(find.byType(SingleChildScrollView)).dy +
        (9 - CalendarGridTokens.weekFirstVisibleHour) * _hour;
    await _mouseDrag(tester, Offset(wednesday, nine), const Offset(0, _hour));
    final draft = container.read(pendingTaskDraftProvider);
    expect(draft, isNotNull);
    expect(draft!.scheduledAt.day, 14);
    expect(draft.durationMinutes, closeTo(60, 10));
    expect(container.read(quickAddSheetVisibleProvider), isTrue);
    expect(find.byType(WeekDraftCard), findsOneWidget);
  });

  testWidgets('with the Day screen\'s checkbox setting on, the pills checkbox '
      'completes a task', (tester) async {
    await pump(
      tester,
      [_task('Design', 14, 9)],
      style: WeekTaskStyle.pills,
      checkbox: true,
    );
    await tester.tap(find.byType(CompletionCheckbox).last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(stored('Design').status, TaskStatus.completed);
  });

  group('weekDragTarget', () {
    final days = [for (var d = 12; d <= 18; d++) DateTime(2026, 10, d)];
    final task = _task('T', 14, 23);
    WeekDrag drag(WeekDragMode mode) => WeekDrag(
      item: task,
      mode: mode,
      start: task.scheduledAt!,
      durationMinutes: 60,
    );
    ({DateTime start, int durationMinutes}) target(
      WeekDragMode mode,
      Offset delta,
    ) => weekDragTarget(
      drag(mode),
      delta: delta,
      dayWidth: 100,
      hourHeight: 60,
      days: days,
    );

    test('a move stays inside one day and inside the week', () {
      expect(
        target(WeekDragMode.move, const Offset(0, 120)).start,
        DateTime(2026, 10, 14, 23),
      );
      expect(
        target(WeekDragMode.move, const Offset(900, 0)).start,
        DateTime(2026, 10, 18, 23),
      );
      expect(
        target(WeekDragMode.move, const Offset(-140, -60)).start,
        DateTime(2026, 10, 13, 22),
      );
    });

    test('resizes keep the minimum length and the day', () {
      expect(
        target(
          WeekDragMode.resizeBottom,
          const Offset(0, -600),
        ).durationMinutes,
        5,
      );
      expect(
        target(WeekDragMode.resizeBottom, const Offset(0, 600)).durationMinutes,
        60,
      );
      final top = target(WeekDragMode.resizeTop, const Offset(0, 600));
      expect(top.start, DateTime(2026, 10, 14, 23, 55));
      expect(top.durationMinutes, 5);
    });
  });
}
