import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/services/overlap_cluster.dart';

Task _task({
  required String title,
  required DateTime scheduledAt,
  required int durationMinutes,
}) {
  return Task.create(
    title: title,
    scheduledAt: scheduledAt,
    durationMinutes: durationMinutes,
    categoryId: BuiltInCategoryIds.personal,
  );
}

void main() {
  group('detectOverlapClusters', () {
    test('no tasks, or a single task, produces no clusters', () {
      expect(detectOverlapClusters(const []), isEmpty);
      expect(
        detectOverlapClusters([
          _task(
            title: 'Solo',
            scheduledAt: DateTime(2026, 8, 24, 9),
            durationMinutes: 30,
          ),
        ]),
        isEmpty,
      );
    });

    test('two tasks that do not overlap produce no cluster', () {
      final tasks = [
        _task(
          title: 'Morning',
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 30,
        ),
        _task(
          title: 'Afternoon',
          scheduledAt: DateTime(2026, 8, 24, 14),
          durationMinutes: 30,
        ),
      ];

      expect(detectOverlapClusters(tasks), isEmpty);
    });

    test('two tasks that intersect form a 2-task cluster', () {
      final tasks = [
        _task(
          title: 'Work',
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 60,
        ),
        _task(
          title: 'Call',
          scheduledAt: DateTime(2026, 8, 24, 9, 30),
          durationMinutes: 30,
        ),
      ];

      final clusters = detectOverlapClusters(tasks);

      expect(clusters, hasLength(1));
      expect(clusters.single.tasks, hasLength(2));
      expect(clusters.single.tasks.map((task) => task.title), ['Work', 'Call']);
    });

    test('a task fully nested inside another still forms a 2-task cluster', () {
      final tasks = [
        _task(
          title: 'Long meeting',
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 120,
        ),
        _task(
          title: 'Quick huddle',
          scheduledAt: DateTime(2026, 8, 24, 9, 30),
          durationMinutes: 15,
        ),
      ];

      final clusters = detectOverlapClusters(tasks);

      expect(clusters, hasLength(1));
      expect(clusters.single.tasks, hasLength(2));
    });

    test('three mutually-overlapping tasks form one 3-task cluster', () {
      final tasks = [
        _task(
          title: 'A',
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 60,
        ),
        _task(
          title: 'B',
          scheduledAt: DateTime(2026, 8, 24, 9, 20),
          durationMinutes: 60,
        ),
        _task(
          title: 'C',
          scheduledAt: DateTime(2026, 8, 24, 9, 40),
          durationMinutes: 60,
        ),
      ];

      final clusters = detectOverlapClusters(tasks);

      expect(clusters, hasLength(1));
      expect(clusters.single.tasks.map((task) => task.title), ['A', 'B', 'C']);
    });

    test('a CHAIN of three tasks, where the first and third never directly '
        'overlap, still forms one cluster via the middle task', () {
      final tasks = [
        _task(
          title: 'A',
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 30,
        ),
        _task(
          title: 'B',
          scheduledAt: DateTime(2026, 8, 24, 9, 15),
          durationMinutes: 30,
        ),
        _task(
          title: 'C',
          scheduledAt: DateTime(2026, 8, 24, 9, 40),
          durationMinutes: 30,
        ),
      ];
      // A: 09:00-09:30, B: 09:15-09:45, C: 09:40-10:10.
      // A and C never overlap directly, but both overlap B.

      final clusters = detectOverlapClusters(tasks);

      expect(clusters, hasLength(1));
      expect(clusters.single.tasks, hasLength(3));
    });

    test('clusters are returned in chronological (start-time) order', () {
      final tasks = [
        // A separate 2-task cluster later in the day.
        _task(
          title: 'Late1',
          scheduledAt: DateTime(2026, 8, 24, 16),
          durationMinutes: 30,
        ),
        _task(
          title: 'Late2',
          scheduledAt: DateTime(2026, 8, 24, 16, 15),
          durationMinutes: 30,
        ),
        // An earlier 2-task cluster.
        _task(
          title: 'Early1',
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 30,
        ),
        _task(
          title: 'Early2',
          scheduledAt: DateTime(2026, 8, 24, 9, 15),
          durationMinutes: 30,
        ),
      ];

      final clusters = detectOverlapClusters(tasks);

      expect(clusters, hasLength(2));
      expect(clusters[0].tasks.map((task) => task.title), ['Early1', 'Early2']);
      expect(clusters[1].tasks.map((task) => task.title), ['Late1', 'Late2']);
    });

    test('each cluster within a member task, chronologically ordered', () {
      final tasks = [
        _task(
          title: 'Third',
          scheduledAt: DateTime(2026, 8, 24, 9, 40),
          durationMinutes: 30,
        ),
        _task(
          title: 'First',
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 60,
        ),
        _task(
          title: 'Second',
          scheduledAt: DateTime(2026, 8, 24, 9, 20),
          durationMinutes: 30,
        ),
      ];

      final clusters = detectOverlapClusters(tasks);

      expect(clusters, hasLength(1));
      expect(clusters.single.tasks.map((task) => task.title), [
        'First',
        'Second',
        'Third',
      ]);
    });

    test('cluster boundary is min(start) and max(end) across members', () {
      final tasks = [
        // Starts latest but runs longest — its END should still win max(end).
        _task(
          title: 'Long',
          scheduledAt: DateTime(2026, 8, 24, 9, 30),
          durationMinutes: 90,
        ),
        // Starts earliest — its START should win min(start).
        _task(
          title: 'Early',
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 40,
        ),
      ];

      final clusters = detectOverlapClusters(tasks);

      expect(clusters, hasLength(1));
      expect(clusters.single.start, DateTime(2026, 8, 24, 9));
      expect(clusters.single.end, DateTime(2026, 8, 24, 11));
    });

    // Reversed directly ("all should overlap as cluster mode"): an
    // earlier pass capped clusters at 3 and let a run of 4+ fall back to
    // plain side-by-side capsules, which produced two different overlap
    // treatments on the same day. There is no upper bound any more.
    test('4 mutually-overlapping tasks DO cluster — no upper bound', () {
      final tasks = [
        for (var i = 0; i < 4; i++)
          _task(
            title: 'T$i',
            scheduledAt: DateTime(2026, 8, 24, 9, i * 10),
            durationMinutes: 60,
          ),
      ];

      final clusters = detectOverlapClusters(tasks);

      expect(clusters, hasLength(1));
      expect(clusters.single.tasks, hasLength(4));
    });

    test(
      'a deep run clusters WHOLE — it is never clipped to the first few',
      () {
        final tasks = [
          for (var i = 0; i < 7; i++)
            _task(
              title: 'T$i',
              scheduledAt: DateTime(2026, 8, 24, 9, i * 5),
              durationMinutes: 60,
            ),
        ];

        final clusters = detectOverlapClusters(tasks);

        expect(clusters, hasLength(1));
        expect(clusters.single.tasks, hasLength(7));
      },
    );

    test('an unrelated task before/after a 4-task run is left out of it', () {
      final tasks = [
        _task(
          title: 'Before',
          scheduledAt: DateTime(2026, 8, 24, 6),
          durationMinutes: 30,
        ),
        for (var i = 0; i < 4; i++)
          _task(
            title: 'T$i',
            scheduledAt: DateTime(2026, 8, 24, 9, i * 5),
            durationMinutes: 60,
          ),
        _task(
          title: 'After',
          scheduledAt: DateTime(2026, 8, 24, 18),
          durationMinutes: 30,
        ),
      ];

      final clusters = detectOverlapClusters(tasks);

      expect(clusters, hasLength(1));
      expect(clusters.single.tasks.map((t) => t.title), [
        'T0',
        'T1',
        'T2',
        'T3',
      ]);
    });

    test('a task can only belong to one cluster at a time', () {
      final tasks = [
        _task(
          title: 'A',
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 60,
        ),
        _task(
          title: 'B',
          scheduledAt: DateTime(2026, 8, 24, 9, 10),
          durationMinutes: 60,
        ),
        // Starts after A/B's window entirely -> its own separate cluster.
        _task(
          title: 'C',
          scheduledAt: DateTime(2026, 8, 24, 11),
          durationMinutes: 60,
        ),
        _task(
          title: 'D',
          scheduledAt: DateTime(2026, 8, 24, 11, 10),
          durationMinutes: 60,
        ),
      ];

      final clusters = detectOverlapClusters(tasks);

      expect(clusters, hasLength(2));
      final allClusteredTitles = clusters
          .expand((cluster) => cluster.tasks)
          .map((task) => task.title)
          .toList();
      expect(allClusteredTitles, ['A', 'B', 'C', 'D']);
    });
  });

  group('clusteredTaskIds', () {
    test('collects ids across every cluster', () {
      final a = _task(
        title: 'A',
        scheduledAt: DateTime(2026, 8, 24, 9),
        durationMinutes: 30,
      );
      final b = _task(
        title: 'B',
        scheduledAt: DateTime(2026, 8, 24, 9, 10),
        durationMinutes: 30,
      );
      final c = _task(
        title: 'C',
        scheduledAt: DateTime(2026, 8, 24, 16),
        durationMinutes: 30,
      );
      final d = _task(
        title: 'D',
        scheduledAt: DateTime(2026, 8, 24, 16, 10),
        durationMinutes: 30,
      );

      final clusters = detectOverlapClusters([a, b, c, d]);
      final ids = clusteredTaskIds(clusters);

      expect(ids, {a.id, b.id, c.id, d.id});
    });

    test('empty for a day with no clusters', () {
      final solo = _task(
        title: 'Solo',
        scheduledAt: DateTime(2026, 8, 24, 9),
        durationMinutes: 30,
      );

      expect(clusteredTaskIds(detectOverlapClusters([solo])), isEmpty);
    });
  });

  // Reported directly: "the imported tasks should also stack in the same
  // way as native tasks... otherwise exactly the same, with different
  // styling" — detectOverlapClusters was generalized from `List<Task>` to
  // `List<ScheduledBlock>` so a run of overlapping blocks can mix real
  // tasks and imported ExternalCalendarEvents into ONE cluster, instead of
  // events being excluded from clustering entirely.
  group('detectOverlapClusters mixing tasks and external events '
      '(2026-09-07)', () {
    ExternalCalendarEvent event({
      required String id,
      required String title,
      required DateTime start,
      required int durationMinutes,
    }) => ExternalCalendarEvent(
      id: id,
      title: title,
      start: start,
      end: start.add(Duration(minutes: durationMinutes)),
      sourceCalendarId: 'cal-1',
    );

    test('a task and an overlapping event form one 2-member cluster', () {
      final task = _task(
        title: 'Standup',
        scheduledAt: DateTime(2026, 8, 24, 9),
        durationMinutes: 60,
      );
      final calEvent = event(
        id: 'evt-1',
        title: 'Dentist',
        start: DateTime(2026, 8, 24, 9, 30),
        durationMinutes: 60,
      );

      final clusters = detectOverlapClusters([task, calEvent]);

      expect(clusters, hasLength(1));
      expect(clusters.single.blocks, hasLength(2));
      // Chronological order — the task starts first.
      expect(clusters.single.blocks.map((b) => b.id), [task.id, 'evt-1']);
    });

    test('OverlapCluster.tasks filters out event members, keeping only '
        'real tasks', () {
      final task = _task(
        title: 'Standup',
        scheduledAt: DateTime(2026, 8, 24, 9),
        durationMinutes: 60,
      );
      final calEvent = event(
        id: 'evt-1',
        title: 'Dentist',
        start: DateTime(2026, 8, 24, 9, 30),
        durationMinutes: 60,
      );

      final clusters = detectOverlapClusters([task, calEvent]);

      expect(clusters.single.tasks, [task]);
      expect(clusters.single.blocks, hasLength(2));
    });

    test('clusteredTaskIds includes an event\'s id alongside task ids', () {
      final task = _task(
        title: 'Standup',
        scheduledAt: DateTime(2026, 8, 24, 9),
        durationMinutes: 60,
      );
      final calEvent = event(
        id: 'evt-1',
        title: 'Dentist',
        start: DateTime(2026, 8, 24, 9, 30),
        durationMinutes: 60,
      );

      final ids = clusteredTaskIds(detectOverlapClusters([task, calEvent]));

      expect(ids, {task.id, 'evt-1'});
    });

    test('an event overlapping nothing never clusters, same as a solo '
        'task', () {
      final calEvent = event(
        id: 'evt-1',
        title: 'Solo event',
        start: DateTime(2026, 8, 24, 14),
        durationMinutes: 30,
      );

      expect(detectOverlapClusters([calEvent]), isEmpty);
    });

    test('three mutually-overlapping members (task, event, task) form one '
        '3-member cluster', () {
      final a = _task(
        title: 'A',
        scheduledAt: DateTime(2026, 8, 24, 9),
        durationMinutes: 60,
      );
      final b = event(
        id: 'evt-b',
        title: 'B',
        start: DateTime(2026, 8, 24, 9, 20),
        durationMinutes: 60,
      );
      final c = _task(
        title: 'C',
        scheduledAt: DateTime(2026, 8, 24, 9, 40),
        durationMinutes: 60,
      );

      final clusters = detectOverlapClusters([a, b, c]);

      expect(clusters, hasLength(1));
      expect(clusters.single.blocks, hasLength(3));
    });
  });

  // Real bug, reported directly from a screenshot: an imported 08:30
  // calendar event's row rendered between 15:20 and 19:30, overlapping
  // its neighbour. List mode positioned each cluster with
  // `blockTops[cluster.tasks.first.id]` — but `tasks` is a FILTERED view
  // of `blocks` (events dropped), so when a cluster's earliest member is
  // an event, `tasks.first` is a later task and the cluster took a
  // different row's top. `blockTops` is keyed by the row's own first
  // member, which is `blocks.first`.
  group('blocks.first is the cluster\'s earliest member', () {
    test('holds when an external event starts before every task in the '
        'cluster', () {
      final event = ExternalCalendarEvent(
        id: 'evt-early',
        title: 'Daily Mixtape',
        start: DateTime(2026, 9, 4, 8, 30),
        end: DateTime(2026, 9, 4, 9, 15),
        sourceCalendarId: 'cal-1',
      );
      final task = _task(
        title: 'Later task',
        scheduledAt: DateTime(2026, 9, 4, 8, 45),
        durationMinutes: 60,
      );

      final clusters = detectOverlapClusters([task, event]);
      expect(clusters, hasLength(1));
      final cluster = clusters.single;

      expect(
        cluster.blocks.first.id,
        event.id,
        reason: 'the event starts first, so it heads the cluster',
      );
      expect(
        cluster.tasks.first.id,
        task.id,
        reason:
            'guards the premise: tasks.first is a DIFFERENT block, which '
            'is exactly why using it for the row top was wrong',
      );
      expect(
        cluster.blocks.first.scheduledStart,
        cluster.blocks
            .map((b) => b.scheduledStart)
            .reduce((a, b) => a.isBefore(b) ? a : b),
        reason: 'blocks.first must be the earliest member',
      );
    });
  });

  group('clusterLanes', () {
    OverlapCluster clusterOf(List<Task> tasks) {
      final clusters = detectOverlapClusters(tasks);
      expect(
        clusters,
        hasLength(1),
        reason: 'fixture must form exactly one cluster',
      );
      return clusters.single;
    }

    // The reported case, from a screenshot: a run of four where only the
    // long first task spans the rest. Standup/Daily sync/Lunch never
    // overlap EACH OTHER, so they all belong in one reused lane — the old
    // one-lane-per-member scheme gave them lanes 1, 2, 3 and left obvious
    // empty space. "There is room in second lane... items from lane 3 and
    // 4 should dock to only next lane if the previous can't fit."
    test('later members reuse a freed lane instead of each taking a new one',
        () {
      final focus = _task(
        title: 'Focus',
        scheduledAt: DateTime(2026, 9, 22, 10),
        durationMinutes: 240,
      );
      final standup = _task(
        title: 'Standup',
        scheduledAt: DateTime(2026, 9, 22, 10, 30),
        durationMinutes: 30,
      );
      final dailySync = _task(
        title: 'Daily sync',
        scheduledAt: DateTime(2026, 9, 22, 11, 30),
        durationMinutes: 60,
      );
      final lunch = _task(
        title: 'Lunch',
        scheduledAt: DateTime(2026, 9, 22, 13),
        durationMinutes: 45,
      );

      final lanes = clusterLanes(clusterOf([focus, standup, dailySync, lunch]));

      expect(lanes, [0, 1, 1, 1]);
      expect(
        lanes.reduce((a, b) => a > b ? a : b) + 1,
        2,
        reason: 'two lanes, not the four the member count would have given',
      );
    });

    test('mutually overlapping members still get one lane each', () {
      final a = _task(
        title: 'A',
        scheduledAt: DateTime(2026, 9, 22, 9),
        durationMinutes: 120,
      );
      final b = _task(
        title: 'B',
        scheduledAt: DateTime(2026, 9, 22, 9, 15),
        durationMinutes: 120,
      );
      final c = _task(
        title: 'C',
        scheduledAt: DateTime(2026, 9, 22, 9, 30),
        durationMinutes: 120,
      );

      expect(clusterLanes(clusterOf([a, b, c])), [0, 1, 2]);
    });

    // The guarantee packing must not break: each pill is a positional
    // marker for its own row in OverlapClusterBlock's list, so lanes have
    // to stay non-decreasing in chronological order. Here lane 0 is
    // genuinely free by the time C starts — a naive leftmost-free packer
    // would put C there, LEFT of B, and pill order would stop matching row
    // order. C must take a new lane instead.
    test('a member never moves left of the previous one, even when an '
        'earlier lane is free', () {
      final a = _task(
        title: 'A',
        scheduledAt: DateTime(2026, 9, 22, 10),
        durationMinutes: 60,
      );
      final b = _task(
        title: 'B',
        scheduledAt: DateTime(2026, 9, 22, 10, 10),
        durationMinutes: 290,
      );
      final c = _task(
        title: 'C',
        scheduledAt: DateTime(2026, 9, 22, 11, 40),
        durationMinutes: 60,
      );

      final lanes = clusterLanes(clusterOf([a, b, c]));

      expect(lanes, [0, 1, 2]);
      expect(
        lanes[2],
        isNot(0),
        reason: 'lane 0 is free at 11:40 but taking it would reorder C '
            'ahead of B',
      );
    });

    test('lanes are non-decreasing for every cluster shape', () {
      final tasks = [
        _task(
          title: 'A',
          scheduledAt: DateTime(2026, 9, 22, 8),
          durationMinutes: 300,
        ),
        _task(
          title: 'B',
          scheduledAt: DateTime(2026, 9, 22, 8, 30),
          durationMinutes: 30,
        ),
        _task(
          title: 'C',
          scheduledAt: DateTime(2026, 9, 22, 9, 30),
          durationMinutes: 30,
        ),
        _task(
          title: 'D',
          scheduledAt: DateTime(2026, 9, 22, 9, 45),
          durationMinutes: 180,
        ),
        _task(
          title: 'E',
          scheduledAt: DateTime(2026, 9, 22, 10, 30),
          durationMinutes: 30,
        ),
      ];

      final lanes = clusterLanes(clusterOf(tasks));

      for (var i = 1; i < lanes.length; i++) {
        expect(
          lanes[i],
          greaterThanOrEqualTo(lanes[i - 1]),
          reason: 'lane order must never invert against row order',
        );
      }
    });

    test('a member is never placed in a lane whose occupant is still '
        'running', () {
      final tasks = [
        _task(
          title: 'A',
          scheduledAt: DateTime(2026, 9, 22, 10),
          durationMinutes: 240,
        ),
        _task(
          title: 'B',
          scheduledAt: DateTime(2026, 9, 22, 10, 30),
          durationMinutes: 30,
        ),
        _task(
          title: 'C',
          scheduledAt: DateTime(2026, 9, 22, 11, 30),
          durationMinutes: 60,
        ),
        _task(
          title: 'D',
          scheduledAt: DateTime(2026, 9, 22, 13),
          durationMinutes: 45,
        ),
      ];
      final cluster = clusterOf(tasks);
      final lanes = clusterLanes(cluster);

      // Re-derive occupancy independently and assert no lane holds two
      // blocks that genuinely overlap in time.
      for (var i = 0; i < cluster.blocks.length; i++) {
        for (var j = i + 1; j < cluster.blocks.length; j++) {
          if (lanes[i] != lanes[j]) continue;
          final first = cluster.blocks[i];
          final second = cluster.blocks[j];
          final overlaps =
              first.scheduledStart.isBefore(second.scheduledEnd) &&
              second.scheduledStart.isBefore(first.scheduledEnd);
          expect(
            overlaps,
            isFalse,
            reason: 'two overlapping blocks share lane ${lanes[i]}',
          );
        }
      }
    });
  });
}
