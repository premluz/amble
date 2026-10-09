import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/clock_provider.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/calendar/calendar_span.dart';
import 'package:amble/features/calendar/desktop_calendar_toolbar.dart';
import 'package:amble/features/calendar/month_view.dart';
import 'package:amble/features/calendar/week_task_block.dart';
import 'package:amble/features/calendar/week_view.dart';
import 'package:amble/features/task_detail/task_editor.dart';
import 'package:amble/features/timeline/selected_date_provider.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/calendar_grid_lines_setting.dart';
import 'package:amble/shared/providers/category_providers.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_category_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

import '../../support/fake_notification_service.dart';
import '../../support/seeded_category_box.dart';

/// The wide layout's Week and Month views — requested directly: "on desktop
/// view switcher for number of days shown Day / Week / Month (Month shows
/// just tasks without zones and not spatiality)". Today is pinned to
/// Wednesday 14 October 2026.
final _wednesday = DateTime(2026, 10, 14, 12);

Task _task(String title, int day, int hour, {int minutes = 60}) => Task.create(
  title: title,
  scheduledAt: DateTime(2026, 10, day, hour),
  durationMinutes: minutes,
  categoryId: BuiltInCategoryIds.work,
);

/// [title] in a week task's visible text row (the pill keeps a hidden,
/// zero-width copy of its title, as it does on the Day screen).
Finder _shown(String title) => find.descendant(
  of: find.byType(WeekTaskText),
  matching: find.text(title),
);

void main() {
  late Box<Task> tasks;
  late Box<dynamic> prefs;
  late Box<Category> categories;
  late Box<Zone> zones;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_desktop_calendar');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    tasks = await Hive.openBox<Task>('tasks_$stamp');
    prefs = await Hive.openBox<dynamic>('prefs_$stamp');
    categories = await openSeededCategoryBox('categories_$stamp');
    zones = await Hive.openBox<Zone>('zones_$stamp');
  });

  tearDown(() async {
    for (final box in [tasks, prefs, categories, zones]) {
      await box.deleteFromDisk();
    }
  });

  Future<ProviderContainer> pump(
    WidgetTester tester,
    CalendarSpan span,
    List<Task> seed,
  ) async {
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
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(prefs),
        ),
        categoryRepositoryProvider.overrideWithValue(
          HiveCategoryRepository(categories),
        ),
        zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(zones)),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(calendarSpanProvider.notifier).set(span);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Consumer(
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
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('the week shows Monday to Sunday with each task in its own '
      'day column, at its time', (tester) async {
    await pump(tester, CalendarSpan.week, [
      _task('Standup', 13, 9),
      _task('Retro', 16, 10),
    ]);

    expect(find.text('Mon 12'), findsOneWidget);
    expect(find.text('Sun 18'), findsOneWidget);
    final tue = tester.getRect(find.text('Tue 13'));
    final fri = tester.getRect(find.text('Fri 16'));
    final standup = tester.getRect(_shown('Standup'));
    final retro = tester.getRect(_shown('Retro'));
    expect(standup.center.dx, closeTo(tue.center.dx, tue.width));
    expect(retro.center.dx, closeTo(fri.center.dx, fri.width));
    // 10:00 sits one hour below 09:00.
    expect(retro.top - standup.top, greaterThan(0));
  });

  testWidgets('overlapping tasks share their day column side by side', (
    tester,
  ) async {
    await pump(tester, CalendarSpan.week, [
      _task('Design', 14, 9),
      _task('Review', 14, 9, minutes: 30),
    ]);

    final blocks = find.byType(WeekTaskPill);
    expect(blocks, findsNWidgets(2));
    final a = tester.getRect(blocks.at(0));
    final b = tester.getRect(blocks.at(1));
    expect(a.overlaps(b), isFalse);
    expect(a.top, b.top);
    // Both titles show (reported: "not seeing label of others"), after the
    // pills and without printing over each other.
    final design = tester.getRect(_shown('Design'));
    final review = tester.getRect(_shown('Review'));
    expect(design.left, greaterThan(b.right));
    expect(design.overlaps(review), isFalse);
  });

  testWidgets('a task in the week opens its editor', (tester) async {
    await pump(tester, CalendarSpan.week, [_task('Standup', 14, 9)]);
    await tester.tap(_shown('Standup'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsOneWidget);
  });

  testWidgets('a day header opens that day in Day view', (tester) async {
    final container = await pump(tester, CalendarSpan.week, const []);
    await tester.tap(find.text('Fri 16'));
    await tester.pumpAndSettle();
    expect(container.read(calendarSpanProvider), CalendarSpan.day);
    expect(container.read(selectedDateProvider), DateTime(2026, 10, 16));
  });

  testWidgets('the month lists tasks per day, then "+N more", which opens '
      'the day', (tester) async {
    final container = await pump(tester, CalendarSpan.month, [
      for (var h = 8; h < 14; h++) _task('Busy $h', 21, h),
      _task('Lunch', 9, 12),
    ]);

    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Busy 8'), findsOneWidget);
    expect(find.text('Busy 12'), findsNothing);
    await tester.tap(find.text('+2 more'));
    await tester.pumpAndSettle();
    expect(container.read(calendarSpanProvider), CalendarSpan.day);
    expect(container.read(selectedDateProvider), DateTime(2026, 10, 21));
  });

  testWidgets('the toolbar switches span and steps by it', (tester) async {
    final container = await pump(tester, CalendarSpan.week, const []);
    expect(find.text('October 2026'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Next'));
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), DateTime(2026, 10, 21));

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.byType(MonthView), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Next'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), DateTime(2026, 10, 14));
  });

  testWidgets('the faint day and hour lines follow the Appearance toggle', (
    tester,
  ) async {
    bool weekLines() => find
        .byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter.runtimeType.toString() == '_GridLines',
        )
        .evaluate()
        .isNotEmpty;
    bool monthLines() => find
        .byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).border?.top.style ==
                  BorderStyle.solid,
        )
        .evaluate()
        .isNotEmpty;

    final container = await pump(tester, CalendarSpan.week, const []);
    expect(container.read(calendarGridLinesSettingProvider), isTrue);
    expect(weekLines(), isTrue);

    await tester.runAsync(
      () =>
          container.read(calendarGridLinesSettingProvider.notifier).set(false),
    );
    await tester.pumpAndSettle();
    expect(weekLines(), isFalse);

    container.read(calendarSpanProvider.notifier).set(CalendarSpan.month);
    await tester.pumpAndSettle();
    expect(monthLines(), isFalse);
    await tester.runAsync(
      () => container.read(calendarGridLinesSettingProvider.notifier).set(true),
    );
    await tester.pumpAndSettle();
    expect(monthLines(), isTrue);
  });
}
