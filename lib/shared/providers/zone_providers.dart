import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../models/recurrence_rule.dart';
import '../models/zone.dart';
import '../repositories/hive_zone_repository.dart';
import '../repositories/zone_repository.dart';
import '../services/zone_cascade_reschedule.dart';
import '../services/zone_recurrence_generator.dart';
import 'notification_providers.dart';
import 'task_providers.dart';

part 'zone_providers.g.dart';

const zoneBoxName = 'zones';

const _uuid = Uuid();

@Riverpod(keepAlive: true)
ZoneRepository zoneRepository(Ref ref) {
  final box = Hive.box<Zone>(zoneBoxName);
  return HiveZoneRepository(box);
}

/// CRUD state over [ZoneRepository], mirroring `TrackedBehaviorList`.
///
/// `keepAlive: true` rather than `autoDispose`, per the Phase 1 decision in
/// docs/DECISIONS.md: this is session-scoped app state, and `autoDispose`
/// caused a real bug where a notifier's own write could be torn down
/// mid-flight with no listener active. Same reasoning applies here.
///
/// Nothing reads this provider yet — no Zone UI exists and none is gated
/// yet (see `core/feature_flags.dart`). Built now so the data layer is
/// complete and testable ahead of that UI.
@Riverpod(keepAlive: true)
class ZoneList extends _$ZoneList {
  @override
  List<Zone> build() {
    return ref.watch(zoneRepositoryProvider).getAll();
  }

  /// Creates a zone. Passing [recurrenceRule] makes it the template of a
  /// new recurring series — mirrors [TaskList.createTask]'s exact shape:
  /// the template is saved, then the rest of the rolling window is
  /// materialized immediately so the series is visible on the Timeline
  /// right away rather than only after the next launch.
  ///
  /// [anchorDateForRecurrence] is the day the series (and every instance
  /// [zone_recurrence_generator.dart] walks forward from) anchors on —
  /// required to mean anything only when [recurrenceRule] is non-null;
  /// ignored for a non-recurring zone, which stays dateless (applies to
  /// every day, unaffected by this session's changes).
  Future<Zone> createZone({
    required String title,
    required int startMinutes,
    required int endMinutes,
    RecurrenceRule? recurrenceRule,
    bool notificationsEnabled = true,
    DateTime? anchorDateForRecurrence,
  }) async {
    final zone = Zone.create(
      title: title,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      recurrenceRule: recurrenceRule,
      notificationsEnabled: notificationsEnabled,
      // A series is identified by its template's own id — no second
      // identifier to keep in sync, mirroring TaskList.createTask exactly.
      recurrenceId: recurrenceRule == null ? null : _uuid.v4(),
      anchorDate: recurrenceRule == null ? null : anchorDateForRecurrence,
    );
    await ref.read(zoneRepositoryProvider).save(zone);

    if (recurrenceRule != null) {
      await _materializeSeries(zone);
    }
    _refresh();
    return zone;
  }

  Future<void> updateZone(Zone zone) async {
    await ref.read(zoneRepositoryProvider).save(zone);
    _refresh();
  }

  /// Generates and persists any missing instances for [template]'s series.
  /// Writes go through [ZoneRepository] like every other mutation — the
  /// generator itself only computes, it never persists. Mirrors
  /// `TaskList._materializeSeries` exactly, including its notification
  /// discipline: deliberately NOT scheduling a notification per instance
  /// here — materialization can write up to 8 weeks of rows at once, and
  /// scheduling an OS alarm for each is what drove the app past Android's
  /// 500-alarm cap for Task (see docs/ERROR_LOG.md). In-horizon instances
  /// pick up their alarm from [refreshScheduledNotifications] instead.
  Future<void> _materializeSeries(Zone template) async {
    final repository = ref.read(zoneRepositoryProvider);
    final seriesId = template.recurrenceId;
    if (seriesId == null) return;

    final existing = repository
        .getAll()
        .where((zone) => zone.recurrenceId == seriesId)
        .toList();

    final generated = generateZoneRecurrenceInstances(
      template: template,
      existingInstances: existing,
      now: DateTime.now(),
    );

    for (final instance in generated) {
      await repository.save(instance);
    }
  }

  /// Tops up every recurring series' rolling window. Called once at app
  /// launch (see main.dart), alongside `TaskList.materializeDueRecurrences`
  /// — mirrors it exactly, including idempotency (instances already
  /// covering an occurrence are skipped by the generator, so repeat calls
  /// create no duplicates).
  Future<void> materializeDueRecurrences() async {
    final templates = ref
        .read(zoneRepositoryProvider)
        .getAll()
        .where((zone) => zone.isRecurrenceTemplate)
        .toList();

    for (final template in templates) {
      await _materializeSeries(template);
    }
    if (templates.isNotEmpty) _refresh();
  }

  /// Applies a full zone-to-zone cascade (`computeZoneCascadeMoves`,
  /// `shared/services/zone_cascade_reschedule.dart`) in one call —
  /// requested directly: "zones should never overlap... perhaps
  /// cascading... that doesn't block user intention." Every zone in
  /// [moves] gets its own new window written (looked up fresh by id, same
  /// "resolve immediately before writing" discipline as
  /// [TaskList.rescheduleTaskWithCascade]), and every [ZoneMove.taskMoves]
  /// entry is forwarded to [TaskList.shiftTasksByMinutes] in one combined
  /// batch — a single cross-provider call rather than one per zone, so
  /// `taskListProvider` refreshes once for the whole cascade, not once
  /// per zone that happened to carry tasks.
  ///
  /// [ref.read]s `taskListProvider.notifier` directly — the one place in
  /// this file that reaches into `task_providers.dart`, justified by the
  /// same "a zone's assigned tasks move with it" rule CONSTITUTION.md now
  /// records as in scope; nothing else here depends on Task at all.
  Future<void> commitZoneCascade(List<ZoneMove> moves) async {
    final repository = ref.read(zoneRepositoryProvider);
    final combinedTaskDeltas = <String, int>{};

    for (final move in moves) {
      final zone = repository.getById(move.zoneId);
      if (zone != null) {
        zone.startMinutes = move.newStartMinutes;
        zone.endMinutes = move.newEndMinutes;
        await repository.save(zone);
      }
      for (final taskMove in move.taskMoves) {
        combinedTaskDeltas[taskMove.taskId] = taskMove.deltaMinutes;
      }
    }

    if (combinedTaskDeltas.isNotEmpty) {
      await ref
          .read(taskListProvider.notifier)
          .shiftTasksByMinutes(combinedTaskDeltas);
    }
    _refresh();
  }

  /// Deletes [id] and cancels its own notification (if any) — matching
  /// `TaskList`'s deletion contract. Pre-existing gap fixed as part of this
  /// session: per-instance deletion becomes a routine operation once a
  /// recurring zone materializes into many real rows, so a stale alarm for
  /// a deleted instance is no longer an edge case worth leaving unhandled.
  Future<void> deleteZone(String id) async {
    await ref.read(zoneRepositoryProvider).delete(id);
    await ref.read(notificationServiceProvider).cancelForZone(id);
    _refresh();
  }

  /// Re-registers every notification-enabled zone's alert, mirroring
  /// `TaskList.refreshScheduledNotifications`'s exact role: `scheduleForZone`
  /// only runs on a zone's own save, so without a launch-time pass a
  /// one-shot zone notification quietly goes stale the day after it fires
  /// (or the day its target occurrence passes, for a recurring zone) —
  /// nothing else re-resolves "what's the next occurrence" until the user
  /// happens to reopen and re-save that exact zone. Called once at launch
  /// from `main.dart`, right after the task-notification refresh, same
  /// fire-and-forget (not awaited) discipline.
  Future<void> refreshScheduledNotifications() async {
    final service = ref.read(notificationServiceProvider);
    for (final zone in ref.read(zoneRepositoryProvider).getAll()) {
      if (!zone.notificationsEnabled) continue;
      await service.scheduleForZone(zone);
    }
  }

  /// Merges [zones] (already parsed/validated by the caller — see
  /// `BackupService.parseImportFile`) into local storage, so a user's
  /// zones survive export/restore on a fresh install. Mirrors
  /// [TaskList.importTasks]'s exact "never overwrite, count and report"
  /// shape (not [CategoryList.importCategories]'s simpler one) — confirmed
  /// directly, since Zone has real edit capability (unlike Category's v1
  /// create-only scope), so a same-id-different-content conflict is a
  /// genuinely reachable case here, not hypothetical.
  ///
  /// Deliberately notification-agnostic, matching [TaskList.importTasks]'s
  /// own confirmed precedent: a bulk/backup restore shouldn't silently
  /// schedule a wave of notifications (or trigger the permission prompt)
  /// as a side effect. `refreshScheduledNotifications` (called once at
  /// launch) is what actually syncs alerts for whatever zones exist by
  /// then.
  Future<ZoneImportResult> importZones(List<Zone> zones) async {
    final repository = ref.read(zoneRepositoryProvider);
    var imported = 0;
    var alreadyPresent = 0;
    var conflicts = 0;

    for (final zone in zones) {
      final existing = repository.getById(zone.id);
      if (existing == null) {
        await repository.save(zone);
        imported++;
      } else if (existing.hasSameFieldsAs(zone)) {
        alreadyPresent++;
      } else {
        conflicts++;
      }
    }

    _refresh();
    return ZoneImportResult(
      imported: imported,
      alreadyPresent: alreadyPresent,
      conflicts: conflicts,
    );
  }

  /// Dev-only: deletes every zone, unconditionally. Gated at every call
  /// site by `kDebugMode` (see `settings_screen.dart`'s Developer section)
  /// — matches `deleteZone`'s own behavior exactly (no notification
  /// cancellation), just applied to every zone rather than one.
  Future<void> clearAllZones() async {
    final repository = ref.read(zoneRepositoryProvider);
    for (final zone in repository.getAll()) {
      await repository.delete(zone.id);
    }
    _refresh();
  }

  void _refresh() {
    state = ref.read(zoneRepositoryProvider).getAll();
  }
}

/// Outcome of [ZoneList.importZones] — mirrors [ImportResult]'s exact
/// shape (`task_providers.dart`), including the conflict count
/// [CategoryImportResult] doesn't need.
class ZoneImportResult {
  const ZoneImportResult({
    required this.imported,
    required this.alreadyPresent,
    required this.conflicts,
  });

  /// New zones (id not previously seen) written.
  final int imported;

  /// Zones skipped because an identical zone with that id already existed.
  final int alreadyPresent;

  /// Zones skipped because a zone with that id already existed but with
  /// different fields — left untouched, never silently overwritten.
  final int conflicts;
}
