import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/recurrence_rule.dart';
import '../models/zone.dart';
import '../repositories/hive_zone_repository.dart';
import '../repositories/zone_repository.dart';
import 'notification_providers.dart';

part 'zone_providers.g.dart';

const zoneBoxName = 'zones';

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

  Future<Zone> createZone({
    required String title,
    required int startMinutes,
    required int endMinutes,
    RecurrenceRule? recurrenceRule,
    bool notificationsEnabled = true,
  }) async {
    final zone = Zone.create(
      title: title,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      recurrenceRule: recurrenceRule,
      notificationsEnabled: notificationsEnabled,
    );
    await ref.read(zoneRepositoryProvider).save(zone);
    _refresh();
    return zone;
  }

  Future<void> updateZone(Zone zone) async {
    await ref.read(zoneRepositoryProvider).save(zone);
    _refresh();
  }

  Future<void> deleteZone(String id) async {
    await ref.read(zoneRepositoryProvider).delete(id);
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
