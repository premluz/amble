import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/core/clock_provider.dart';
import 'package:amble/core/dev_config.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/task_state_tokens.dart';
import 'package:amble/features/calendar/calendar_span.dart';
import 'package:amble/features/calendar/desktop_calendar_toolbar.dart';
import 'package:amble/features/calendar/month_view.dart';
import 'package:amble/features/calendar/week_task_block.dart';
import 'package:amble/features/calendar/week_task_card.dart';
import 'package:amble/features/calendar/week_view.dart';
import 'package:amble/features/timeline/zone_background_block.dart';
import 'package:amble/features/task_detail/category_visual.dart';
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
import 'package:amble/shared/providers/week_task_style_setting.dart';
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
Finder _shown(String title) =>
    find.descendant(of: find.byType(WeekTaskText), matching: find.text(title));

/// Vertical distance between the two stacked week titles, top to bottom.
double _titleGap(WidgetTester tester) {
  final tops = [
    tester.getTopLeft(_shown('Design')).dy,
    tester.getTopLeft(_shown('Review')).dy,
  ]..sort();
  return tops[1] - tops[0];
}

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
    List<Task> seed, {
    List<Zone> zoneSeed = const [],
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      for (final t in seed) {
        await tasks.put(t.id, t);
      }
      for (final z in zoneSeed) {
        await zones.put(z.id, z);
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

  testWidgets('the Timeline "Show time (from-to)" switch also adds the greyed '
      'range under each week title, and stacked rows clear it', (tester) async {
    final container = await pump(tester, CalendarSpan.week, [
      _task('Design', 14, 9),
      _task('Review', 14, 9, minutes: 30),
    ]);
    final range = find.descendant(
      of: find.byType(WeekTaskText),
      matching: find.textContaining(' - '),
    );
    expect(range, findsNWidgets(2), reason: 'on out of the box');

    final notifier = container.read(
      devTimelineTaskTimeRangeVisibleProvider.notifier,
    );
    notifier.set(false);
    await tester.pumpAndSettle();
    expect(range, findsNothing);
    final offGap = _titleGap(tester);

    notifier.set(true);
    await tester.pumpAndSettle();

    expect(range, findsNWidgets(2));
    expect(
      tester.widget<Text>(range.first).style?.color,
      AmbleTheme.light.colorTextSecondary,
    );
    final titles = [
      tester.getRect(_shown('Design')),
      tester.getRect(_shown('Review')),
    ]..sort((a, b) => a.top.compareTo(b.top));
    final ranges = [tester.getRect(range.at(0)), tester.getRect(range.at(1))]
      ..sort((a, b) => a.top.compareTo(b.top));
    for (var i = 0; i < 2; i++) {
      expect(
        ranges[i].top,
        greaterThanOrEqualTo(titles[i].bottom - 1),
        reason: 'each range sits under its own title',
      );
    }
    expect(
      ranges[0].bottom,
      lessThanOrEqualTo(titles[1].top + 1),
      reason: 'the first range clears the second title',
    );
    expect(_titleGap(tester), greaterThan(offGap));
  });

  testWidgets(
    'a week pill is filled with the tint and its icon is the accent',
    (tester) async {
      await pump(tester, CalendarSpan.week, [_task('Solo', 14, 9)]);
      final work = resolveCategoryVisual(
        theme: AmbleTheme.light,
        category: categories.values.firstWhere(
          (c) => c.id == BuiltInCategoryIds.work,
        ),
      );
      final pill = find.byType(WeekTaskPill);
      final fills = find.descendant(
        of: pill,
        matching: find.byWidgetPredicate(
          (w) =>
              w is AnimatedContainer &&
              (w.decoration as BoxDecoration?)?.color == work.pillColor,
        ),
      );
      expect(fills, findsWidgets);
      final icon = tester.widget<Icon>(
        find.descendant(of: pill, matching: find.byType(Icon)).first,
      );
      expect(icon.color, work.iconColor);
    },
  );

  testWidgets('the Appearance "Blocks" style draws standard calendar blocks '
      'as tall as each task, overlapping ones sharing the column', (
    tester,
  ) async {
    final container = await pump(tester, CalendarSpan.week, [
      _task('Design', 14, 9),
      _task('Review', 14, 9, minutes: 30),
      _task('Solo', 15, 12, minutes: 120),
    ]);
    expect(find.byType(WeekTaskCard), findsNothing, reason: 'pills by default');
    expect(find.byType(WeekTaskPill), findsNWidgets(3));

    await tester.runAsync(
      () => container
          .read(weekTaskStyleSettingProvider.notifier)
          .set(WeekTaskStyle.blocks),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WeekTaskPill), findsNothing);
    expect(find.byType(WeekTaskCard), findsNWidgets(3));
    Rect card(String title) => tester.getRect(
      find.ancestor(of: find.text(title), matching: find.byType(WeekTaskCard)),
    );
    final hour =
        CalendarGridTokens.weekHourHeight / Duration.minutesPerHour * 60;
    final gap = CalendarGridTokens.weekBlockGap;
    expect(card('Solo').height, closeTo(hour * 2 - gap, 0.5));
    expect(card('Design').height, closeTo(hour - gap, 0.5));
    expect(card('Design').width, closeTo(card('Review').width, 0.5));
    expect(card('Design').overlaps(card('Review')), isFalse);
    expect(card('Design').top, card('Review').top);
    expect(find.textContaining(' - '), findsWidgets, reason: 'the range shows');

    // One hue: the block's background is a lighter step of the pill's fill,
    // and its rail is the colour of a pill's icon.
    final work = resolveCategoryVisual(
      theme: AmbleTheme.light,
      category: categories.values.firstWhere(
        (c) => c.id == BuiltInCategoryIds.work,
      ),
    );
    final cardBox = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.ancestor(
              of: find.text('Solo'),
              matching: find.byType(WeekTaskCard),
            ),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final blockBg = TaskStateTokens.blockBackground(
      AmbleTheme.light,
      work.pillColor,
    );
    expect((cardBox.decoration as BoxDecoration).color, blockBg);
    expect(
      blockBg.computeLuminance(),
      greaterThan(work.pillColor.computeLuminance()),
      reason: 'the block background is a lighter step than the pill fill',
    );
    final rail = find.descendant(
      of: find.ancestor(
        of: find.text('Solo'),
        matching: find.byType(WeekTaskCard),
      ),
      matching: find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == work.iconColor,
      ),
    );
    expect(rail, findsOneWidget);

    await tester.tap(find.text('Solo'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsOneWidget, reason: 'a tap opens it');
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
              w.painter.runtimeType.toString() == 'WeekGridLines',
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

  Zone placement(String title, int weekday, int start, int end) => Zone(
    id: '$title-$weekday-$start',
    title: title,
    startMinutes: start,
    endMinutes: end,
    weekday: weekday,
  );

  testWidgets('the week draws one zone band across the days it covers, with '
      'its name in the top-left corner', (tester) async {
    await pump(
      tester,
      CalendarSpan.week,
      const [],
      zoneSeed: [
        for (var d = 1; d <= 5; d++) placement('Work', d, 9 * 60, 17 * 60),
      ],
    );

    expect(find.byType(ZoneBackgroundBlock), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.byType(RotatedBox), findsNothing);

    final band = tester.getRect(find.byType(ZoneBackgroundBlock));
    final mon = tester.getRect(find.text('Mon 12'));
    final fri = tester.getRect(find.text('Fri 16'));
    expect(band.left, lessThan(mon.center.dx));
    expect(band.right, greaterThan(fri.center.dx));
    final sat = tester.getRect(find.text('Sat 17'));
    expect(band.right, lessThan(sat.center.dx), reason: 'stops after Friday');

    final title = tester.getRect(find.text('Work'));
    expect(title.left, greaterThanOrEqualTo(band.left));
    expect(title.left, lessThan(band.left + 24), reason: 'left corner');
    expect(title.top, lessThan(band.top + 12), reason: 'top corner');
  });

  testWidgets('a day with different hours gets its own band', (tester) async {
    await pump(
      tester,
      CalendarSpan.week,
      const [],
      zoneSeed: [
        placement('Work', 1, 9 * 60, 17 * 60),
        placement('Work', 2, 9 * 60, 17 * 60),
        placement('Work', 3, 10 * 60, 12 * 60),
      ],
    );
    expect(find.byType(ZoneBackgroundBlock), findsNWidgets(2));
  });

  testWidgets('the month shows no zones', (tester) async {
    await pump(
      tester,
      CalendarSpan.month,
      [_task('Standup', 14, 9)],
      zoneSeed: [for (var d = 1; d <= 7; d++) placement('Sleep', d, 0, 7 * 60)],
    );
    expect(find.byType(ZoneBackgroundBlock), findsNothing);
    expect(find.text('Sleep'), findsNothing);
    expect(find.text('Standup'), findsOneWidget);
  });
}
