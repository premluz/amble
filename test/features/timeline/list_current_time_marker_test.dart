import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/list_current_time_marker.dart';
import 'package:amble/features/timeline/zone_container_block.dart';
import 'package:amble/features/timeline/zone_day_timeline.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';

/// The List view's "now" marker — requested directly: "show the current
/// time on Task view, but it will always be between the tasks. It will
/// never overlap a task." Placement confirmed via AskUserQuestion: an
/// in-progress task stays ABOVE the line, and a running zone holds the
/// line between its own member tasks.
void main() {
  final day = DateTime(2026, 9, 2);
  const marker = ValueKey('now-marker');

  group('nowMarkerIndex', () {
    DateTime at(int hour, [int minute = 0]) =>
        DateTime(2026, 9, 2, hour, minute);
    final starts = [at(9), at(10), at(11)];

    test('before every row -> first', () {
      expect(nowMarkerIndex(starts, (s) => s, at(8)), 0);
    });

    test('inside a started row -> after it, never splitting it', () {
      expect(nowMarkerIndex(starts, (s) => s, at(10, 30)), 2);
    });

    test('exactly at a start counts as started', () {
      expect(nowMarkerIndex(starts, (s) => s, at(10)), 2);
    });

    test('after every row -> last', () {
      expect(nowMarkerIndex(starts, (s) => s, at(23)), 3);
    });

    test('a row with no start has not started', () {
      expect(nowMarkerIndex<DateTime?>([at(9), null], (s) => s, at(12)), 1);
    });
  });

  Future<void> pump(
    WidgetTester tester, {
    required DateTime now,
    List<Task> tasks = const [],
    List<Zone> zones = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: ZoneDayTimeline(
            tasks: tasks,
            zones: zones,
            theme: AmbleTheme.light,
            categoryById: const <String, Category>{},
            selectedDate: day,
            onTaskTap: (_) {},
            onToggleComplete: (_) {},
            now: () => now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Task taskAt(String title, int hour, int minutes) => Task.create(
    title: title,
    scheduledAt: DateTime(2026, 9, 2, hour),
    durationMinutes: minutes,
    categoryId: BuiltInCategoryIds.health,
  );

  Rect rowOf(WidgetTester tester, Task task) =>
      tester.getRect(find.byKey(ValueKey('unzoned-task-row-${task.id}')));

  testWidgets('sits between unzoned tasks, below an in-progress one', (
    tester,
  ) async {
    final early = taskAt('Early', 9, 30);
    final running = taskAt('Running', 10, 60);
    final later = taskAt('Later', 11, 30);
    await pump(
      tester,
      now: DateTime(2026, 9, 2, 10, 30),
      tasks: [early, running, later],
    );

    final line = tester.getRect(find.byKey(marker));
    expect(line.top, greaterThanOrEqualTo(rowOf(tester, running).bottom));
    expect(line.bottom, lessThanOrEqualTo(rowOf(tester, later).top));
  });

  testWidgets('never overlaps any task row', (tester) async {
    final tasks = [
      taskAt('A', 8, 45),
      taskAt('B', 9, 120),
      taskAt('C', 12, 30),
    ];
    await pump(tester, now: DateTime(2026, 9, 2, 10, 5), tasks: tasks);

    final line = tester.getRect(find.byKey(marker));
    for (final task in tasks) {
      expect(line.overlaps(rowOf(tester, task)), isFalse, reason: task.title);
    }
  });

  testWidgets('goes inside a running zone, between its member tasks', (
    tester,
  ) async {
    final zone = Zone(
      id: 'work',
      title: 'Work',
      startMinutes: 9 * 60,
      endMinutes: 13 * 60,
    );
    final standup = taskAt('Standup', 9, 15);
    final review = taskAt('Review', 11, 60);
    await pump(
      tester,
      now: DateTime(2026, 9, 2, 10),
      zones: [zone],
      tasks: [standup, review],
    );

    final inZone = find.descendant(
      of: find.byType(ZoneContainerBlock),
      matching: find.byKey(marker),
    );
    expect(inZone, findsOneWidget);
    final line = tester.getRect(inZone);
    expect(line.top, greaterThan(tester.getRect(find.text('Standup')).bottom));
    expect(line.bottom, lessThan(tester.getRect(find.text('Review')).top));
  });

  testWidgets('goes after a zone that has already ended, not inside it', (
    tester,
  ) async {
    final zone = Zone(
      id: 'morning',
      title: 'Morning',
      startMinutes: 7 * 60,
      endMinutes: 8 * 60,
    );
    await pump(tester, now: DateTime(2026, 9, 2, 10), zones: [zone]);

    expect(
      find.descendant(
        of: find.byType(ZoneContainerBlock),
        matching: find.byKey(marker),
      ),
      findsNothing,
    );
    expect(
      tester.getRect(find.byKey(marker)).top,
      greaterThanOrEqualTo(tester.getRect(find.byType(ZoneContainerBlock)).bottom),
    );
  });

  testWidgets('shows only on today', (tester) async {
    await pump(
      tester,
      now: DateTime(2026, 9, 3, 10),
      tasks: [taskAt('A', 9, 30)],
    );
    expect(find.byKey(marker), findsNothing);
  });

  testWidgets('its time starts in the same column as the row times', (
    tester,
  ) async {
    final task = taskAt('A', 9, 30);
    await pump(tester, now: DateTime(2026, 9, 2, 10, 15), tasks: [task]);

    final markerTime = find.descendant(
      of: find.byKey(marker),
      matching: find.byType(Text),
    );
    final rowTime = find.descendant(
      of: find.byType(ZoneRowTimeLabel),
      matching: find.byType(Text),
    );
    expect(
      tester.getTopLeft(markerTime).dx,
      tester.getTopLeft(rowTime.first).dx,
    );
  });
}
