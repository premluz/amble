import 'package:hive_ce/hive_ce.dart';

part 'tracked_behavior_view_mode.g.dart';

/// How the "Tracked" screen's cards render a behavior's own completion
/// history — one global setting for the whole screen (confirmed directly:
/// every card shows the same granularity at once, mirroring how the
/// Timeline's own view-cycle button is a single global switcher, not a
/// per-card one).
///
/// - [weekly] — a 7-cell Mon-Sun row, one square per day of the current
///   week.
/// - [monthly] — a plain wrapping grid of numbered day cells for the
///   current month (no weekday-column alignment — a simple left-to-right,
///   top-to-bottom wrap, confirmed directly as simpler than a real
///   calendar grid).
/// - [sixMonthly] — a GitHub-heatmap-style grid of small day squares
///   spanning the trailing 6 months, wrapping into rows (confirmed
///   directly), with month names as loose labels above roughly where each
///   month's squares begin rather than visually separated blocks.
///
/// Its own Hive type (not reused from anywhere else) for the same reason
/// [TaskSize] has one: a persisted value needs a storage format that
/// doesn't depend on this enum's declaration order or any other type's
/// shape.
@HiveType(typeId: 13)
enum TrackedBehaviorViewMode {
  @HiveField(0)
  weekly,
  @HiveField(1)
  monthly,
  @HiveField(2)
  sixMonthly,
}
