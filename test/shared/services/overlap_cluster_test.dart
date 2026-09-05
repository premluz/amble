import 'package:flutter_test/flutter_test.dart';
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
}
