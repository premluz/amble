import '../models/external_calendar_event.dart';
import '../models/task.dart';
import '../models/zone.dart';

/// One [Zone] paired with the [Task]s (and read-only external calendar
/// events — see CONSTITUTION.md's "Calendar" section) that belong inside
/// it on the day being viewed, per [resolveZoneContainment]'s containment
/// rule.
class ZoneContainment {
  const ZoneContainment({
    required this.zone,
    required this.tasks,
    this.externalEvents = const [],
  });

  final Zone zone;

  /// Chronological by [Task.scheduledAt] where set; a zone-only task (no
  /// `scheduledAt`) sorts after every scheduled member, in no particular
  /// order among themselves — matches how an unscheduled task has no
  /// meaningful position to sort by within the container either.
  final List<Task> tasks;

  /// External calendar events whose [ExternalCalendarEvent.start] falls
  /// inside this zone's window — the ONLY containment rule that can ever
  /// apply to an external event: unlike [Task.zoneId], there is no
  /// explicit-assignment concept for an entity Amble doesn't own, so this
  /// is always the computed-fallback rule, never an override. Chronological
  /// by [ExternalCalendarEvent.start]. Requested directly, alongside the
  /// same "imported tasks should be one by one" List-view fix — an
  /// external event whose time falls inside a zone should render grouped
  /// with that zone's tasks, not floating separately on the outer axis.
  final List<ExternalCalendarEvent> externalEvents;
}

/// The result of resolving [tasks]/external events against [zones] for one
/// calendar day — which zone (if any) each belongs to, and which tasks
/// belong to none (external events have no such "unzoned" list — see
/// [ZoneContainment.externalEvents]'s own doc comment for why the caller's
/// existing outer-axis external-event rendering already covers that case).
class ZoneContainmentResult {
  const ZoneContainmentResult({
    required this.containments,
    required this.unzonedTasks,
  });

  /// One entry per [Zone] that applies on the viewed day (see
  /// [_zoneAppliesOnDay]), chronological by [Zone.startMinutes] —
  /// regardless of whether it has any member tasks, so an empty zone
  /// still renders its container per the confirmed spec.
  final List<ZoneContainment> containments;

  /// Every task that belongs to no zone on the viewed day — per the
  /// confirmed decision, these are NOT hidden and are NOT a separate
  /// flat section: the caller renders them at their own real spatial
  /// time position, interleaved with the zone containers on the same
  /// outer time axis, exactly as the Task view already does.
  final List<Task> unzonedTasks;
}

/// Resolves which zone (if any) each of [tasks] belongs to for [day],
/// per CONSTITUTION.md's Zone section and the containment rule confirmed
/// directly for the Spatial Zone View:
///
/// 1. **Time wins whenever it exists**: if [Task.scheduledAt] is set, the
///    task belongs to whichever applicable zone's
///    [Zone.startMinutes]/[Zone.endMinutes] window contains that time —
///    and to NO zone if it falls outside all of them, even when
///    [Task.zoneId] names one. Confirmed directly (2026-09-04), reversing
///    the earlier "explicit `zoneId` wins over a conflicting
///    `scheduledAt`" rule: a `zoneId` set by a Zone-view drop is never
///    cleared when the task's time later changes (Task view's drag and
///    the detail sheet both leave it untouched by design), so honouring
///    it made Zone view disagree with Task view about the same task —
///    reported directly, a 05:15 task rendering inside the 09:00-13:00
///    container. This is READ-ONLY for display — nothing here writes or
///    clears `zoneId` on any [Task], per CONSTITUTION.md ("Zone is
///    metadata on a Task, not a container that owns it"); a stale
///    assignment simply stops affecting placement.
/// 2. **Zone-only tasks**: when [Task.scheduledAt] is null there is no
///    time to resolve against, so [Task.zoneId] is authoritative — this
///    is the case CONSTITUTION.md's "a task can be assigned to a zone
///    with no `scheduledAt` at all" note exists for.
/// 3. **Neither**: an unscheduled task whose `zoneId` matches no
///    applicable zone (or is unset) is "unzoned" — see
///    [ZoneContainmentResult.unzonedTasks].
///
/// Only zones that actually apply on [day] are considered — a
/// non-recurring zone (`anchorDate == null`) applies to every day (it has
/// no date field of its own to restrict it to one), while a materialized
/// recurring instance applies only on its own `anchorDate` — a plain field
/// check now that every occurrence is a real row, replacing the former
/// live rule evaluation (`_ruleMatchesDay`), per the Zone materialization
/// session (see docs/DECISIONS.md).
///
/// [externalEvents] (Feature 1's read-only device-calendar events — see
/// CONSTITUTION.md's "Calendar" section) follow ONLY rule 2 above, since
/// they have no [Task.zoneId]-equivalent explicit-assignment concept: an
/// event whose [ExternalCalendarEvent.start] falls inside an applicable
/// zone's window renders inside that zone's [ZoneContainment.externalEvents]
/// list; one that matches no zone is left for the caller to keep rendering
/// on the outer axis exactly as before (there is no "unzoned external
/// events" list here — the caller's existing full [externalEvents] list
/// already covers that case by simply not being re-filtered down).
ZoneContainmentResult resolveZoneContainment({
  required List<Task> tasks,
  required List<Zone> zones,
  required DateTime day,
  List<ExternalCalendarEvent> externalEvents = const [],
}) {
  final applicableZones =
      zones.where((zone) => _zoneAppliesOnDay(zone, day)).toList()
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  final zoneById = {for (final zone in applicableZones) zone.id: zone};

  final tasksByZoneId = <String, List<Task>>{};
  final unzonedTasks = <Task>[];

  for (final task in tasks) {
    // TIME WINS whenever both are set (confirmed directly, 2026-09-04,
    // reversing the earlier "explicit zoneId wins even over a conflicting
    // scheduledAt" rule — see CONSTITUTION.md's Zone section). Reported
    // directly: a task showing 05:15 in Task view still rendered inside
    // the 09:00-13:00 zone container here, because a `zoneId` set by an
    // earlier Zone-view drop is never cleared when the task's time later
    // moves (Task view's own drag and the detail sheet both leave
    // `zoneId` untouched by design). Resolving by time when a time exists
    // makes the two views agree without needing every write path to
    // maintain the assignment.
    if (task.scheduledAt != null) {
      final zoneByTime = _zoneContaining(applicableZones, task);
      if (zoneByTime != null) {
        (tasksByZoneId[zoneByTime.id] ??= []).add(task);
      } else {
        unzonedTasks.add(task);
      }
      continue;
    }
    // Zone-only task (no scheduledAt): `zoneId` is the ONLY thing that can
    // place it — there is no time to resolve against. This is the case
    // CONSTITUTION.md's "a task can be assigned to a zone with no
    // scheduledAt at all" note exists for.
    final explicitZone = task.zoneId == null ? null : zoneById[task.zoneId];
    if (explicitZone != null) {
      (tasksByZoneId[explicitZone.id] ??= []).add(task);
      continue;
    }
    unzonedTasks.add(task);
  }

  final externalEventsByZoneId = <String, List<ExternalCalendarEvent>>{};
  for (final event in externalEvents) {
    final zone = _zoneContainingTime(applicableZones, event.start);
    if (zone != null) {
      (externalEventsByZoneId[zone.id] ??= []).add(event);
    }
  }

  final containments = [
    for (final zone in applicableZones)
      ZoneContainment(
        zone: zone,
        tasks: _sortedByScheduledAt(tasksByZoneId[zone.id] ?? const []),
        externalEvents: _sortedByStart(
          externalEventsByZoneId[zone.id] ?? const [],
        ),
      ),
  ];

  return ZoneContainmentResult(
    containments: containments,
    unzonedTasks: unzonedTasks,
  );
}

/// The first applicable zone whose window contains [task]'s scheduled
/// time, or null if [task] is unscheduled or falls in none of them. A
/// task can only genuinely fall inside one zone at a time since zones
/// cannot overlap each other (`zonesOverlap`'s own invariant), so "first
/// match" is never an arbitrary choice among several.
Zone? _zoneContaining(List<Zone> zones, Task task) {
  final scheduledAt = task.scheduledAt;
  if (scheduledAt == null) return null;
  return _zoneContainingTime(zones, scheduledAt);
}

/// [_zoneContaining]'s underlying time-of-day check, generalized to any
/// [DateTime] — shared by both [_zoneContaining] (a task's `scheduledAt`)
/// and [resolveZoneContainment]'s external-event matching (an event's
/// `start`), so the two entities' fallback containment rule can never
/// silently drift apart into two different window checks.
Zone? _zoneContainingTime(List<Zone> zones, DateTime time) {
  final minutesSinceMidnight = time.hour * 60 + time.minute;
  for (final zone in zones) {
    if (minutesSinceMidnight >= zone.startMinutes &&
        minutesSinceMidnight < zone.endMinutes) {
      return zone;
    }
  }
  return null;
}

bool _zoneAppliesOnDay(Zone zone, DateTime day) {
  final anchorDate = zone.anchorDate;
  if (anchorDate == null) return true;
  return anchorDate.year == day.year &&
      anchorDate.month == day.month &&
      anchorDate.day == day.day;
}

List<Task> _sortedByScheduledAt(List<Task> tasks) {
  final scheduled = tasks.where((t) => t.scheduledAt != null).toList()
    ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
  final unscheduled = tasks.where((t) => t.scheduledAt == null);
  return [...scheduled, ...unscheduled];
}

List<ExternalCalendarEvent> _sortedByStart(List<ExternalCalendarEvent> events) {
  return [...events]..sort((a, b) => a.start.compareTo(b.start));
}
