import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/local_date.dart';
import '../../shared/providers/occurrence_store.dart';
import '../../shared/providers/series_providers.dart';
import '../../shared/services/occurrence_task_projection.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import 'behavior_completion.dart';

/// How far back completed days are read: the longest period Patterns shows
/// (a year).
const _lookbackDays = 366;

final _beginningOfTime = DateTime(0);
final _endOfTime = DateTime(9999, 12, 31);

/// Each tracked behavior's completed days (by behavior id), for every
/// Patterns view.
///
/// Repeating tracked tasks are series occurrences, so a year of them has to
/// be projected, which is the slow part of opening Patterns (about 60 ms per
/// call for 8 daily series on a Mac). It is done once here for all
/// behaviors, only for tracked series, and only after the current frame: the grid of empty dots paints
/// first and the completed days fill in when this lands. Cached until tasks
/// or series change.
final behaviorCompletedDaysProvider =
    FutureProvider<Map<String, Set<DateTime>>>((ref) async {
      final stored = ref.watch(taskListProvider);
      final snapshot = ref.watch(occurrenceStoreProvider);
      final behaviors = ref.watch(trackedBehaviorListProvider);
      await Future<void>.delayed(Duration.zero);
      final today = LocalDate.fromDateTime(DateTime.now());
      final from = today.addDays(-_lookbackDays);
      // An occurrence's behavior is never overridden on its own (it is not
      // a record aspect), so only series whose revisions name a behavior
      // can count: usually a few of many, which is most of the saving.
      final tracked = snapshot.series
          .where((s) => s.revisions.any((r) => r.defaults.behaviorId != null))
          .toList();
      final trackedIds = {for (final s in tracked) s.id};
      final tasks = [
        ...stored,
        ...occurrenceTasksBetween(
          series: tracked,
          records: snapshot.records.where(
            (r) => trackedIds.contains(r.key.seriesId),
          ),
          from: from,
          to: today,
          clock: ref.read(occurrenceClockProvider)(),
        ),
      ];
      // Stored tasks count however far back Patterns is browsed; only the
      // projected occurrences are bounded by the look-back.
      return {
        for (final behavior in behaviors)
          behavior.id: completedDaysFor(
            behavior,
            tasks: tasks,
            start: _beginningOfTime,
            end: _endOfTime,
          ),
      };
    });
