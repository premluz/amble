import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../models/recurrence_rule.dart';
import '../models/recurrence_frequency.dart';
import 'zone_facet_providers.dart';
import '../models/zone.dart';
import '../models/zone_facet.dart';
import '../repositories/hive_zone_repository.dart';
import '../repositories/zone_repository.dart';
import '../services/zone_cascade_reschedule.dart';
import '../services/zone_recurrence_generator.dart';
import 'notification_providers.dart';
import 'task_providers.dart';

part 'zone_providers.g.dart';

const zoneBoxName = 'zones';

const _uuid = Uuid();

/// Stands in for the not-yet-created paint while [resolveZonePlacement]
/// works out who it displaces — the placement itself is written separately
/// (with its own real id per weekday), so its own move is discarded.
const _paintPlaceholderId = '__paint__';

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

  bool _notificationRefreshNeeded = false;
  bool _notificationRefreshRunning = false;

  void _syncNotification(Zone zone) {
    final service = ref.read(notificationServiceProvider);
    final repository = ref.read(zoneRepositoryProvider);
    _notificationRefreshNeeded = true;
    if (_notificationRefreshRunning) return;
    _notificationRefreshRunning = true;
    unawaited(
      Future<void>(() async {
        try {
          while (_notificationRefreshNeeded) {
            _notificationRefreshNeeded = false;
            await service.scheduleZoneCalendar(repository.getAll());
          }
        } catch (error) {
          debugPrint('Zone notification sync failed: $error');
        } finally {
          _notificationRefreshRunning = false;
        }
      }),
    );
  }

  /// Creates independent weekly placements after validating the entire paint.
  /// No writes occur on a conflict; choosing a facet never copies a schedule.
  Future<List<Zone>> paintWeeklyZones({
    required String title,
    String? facetId,
    required Set<int> weekdays,
    required int startMinutes,
    required int endMinutes,
  }) async {
    if (weekdays.isEmpty ||
        weekdays.any((d) => d < 1 || d > 7) ||
        startMinutes < 0 ||
        endMinutes > 1440 ||
        endMinutes <= startMinutes) {
      throw ArgumentError('Choose days and a valid time range.');
    }
    final repository = ref.read(zoneRepositoryProvider);
    final zones = repository.getAll();
    // Historical rows do not block editing the usual week. Dated future
    // exceptions do: the preview and command use this same candidate set.
    final today = DateTime.now();
    final current = zones.where(
      (z) =>
          z.effectiveUntil == null &&
          (z.anchorDate == null ||
              !z.anchorDate!.isBefore(
                DateTime(today.year, today.month, today.day),
              )),
    );
    // Overlap NEVER refuses a paint — confirmed directly, "never prevent
    // action". Each day's existing zones are pushed aside by the shared
    // cascade instead, and only a neighbour that would be swallowed whole
    // is trimmed (to `kZoneSliverMinutes`) rather than removed.
    final displaced = <ZoneMove>[];
    for (final day in weekdays) {
      displaced.addAll(
        resolveZonePlacement(
          placedZoneId: _paintPlaceholderId,
          placedOriginalStartMinutes: startMinutes,
          placedStartMinutes: startMinutes,
          placedEndMinutes: endMinutes,
          otherZones: current
              .where((z) => z.isWeeklyPlacement && z.weekday == day)
              .toList(),
          tasksByZoneId: const {},
        ).where((move) => move.zoneId != _paintPlaceholderId),
      );
    }
    final facet = await ref
        .read(zoneFacetListProvider.notifier)
        .resolve(title, id: facetId);
    final created = <Zone>[];
    try {
      for (final day in weekdays.toList()..sort()) {
        final zone = Zone(
          id: _uuid.v4(),
          title: facet.name,
          startMinutes: startMinutes,
          endMinutes: endMinutes,
          weekday: day,
          facetId: facet.id,
          notificationsEnabled: false,
        );
        await repository.save(zone);
        created.add(zone);
      }
    } catch (_) {
      for (final zone in created) {
        await repository.delete(zone.id);
      }
      rethrow;
    }
    // Apply the push/trim the placement forced on its neighbours, after the
    // placement itself is safely written.
    for (final move in displaced) {
      final zone = repository.getById(move.zoneId);
      if (zone == null) continue;
      zone.startMinutes = move.newStartMinutes;
      zone.endMinutes = move.newEndMinutes;
      await repository.save(zone);
    }
    _refresh();
    return created;
  }

  Future<void> deleteUnusedFacet(String id) async {
    if (ref.read(zoneRepositoryProvider).getAll().any((z) => z.facetId == id)) {
      throw StateError('This name is used by saved zones. Rename it instead.');
    }
    await ref.read(zoneFacetRepositoryProvider).delete(id);
    ref.invalidate(zoneFacetListProvider);
  }

  Future<void> renameFacetPlacements(String facetId, String name) async {
    final repository = ref.read(zoneRepositoryProvider);
    for (final zone in repository.getAll().where((z) => z.facetId == facetId)) {
      zone.title = name;
      await repository.save(zone);
    }
    _refresh();
  }

  /// Non-destructive conversion: old IDs survive, past windows keep their
  /// original dates, and changed future instances remain dated exceptions.
  Future<void> migrateToWeeklySchedule({DateTime? now}) async {
    final repository = ref.read(zoneRepositoryProvider);
    final date = now ?? DateTime.now();
    final today = DateTime(date.year, date.month, date.day);
    final originals = repository.getAll();
    for (final zone in originals.where((z) => z.facetId != null)) {
      await ref.read(zoneFacetListProvider.notifier).importFacets([
        ZoneFacet(id: zone.facetId!, name: zone.title),
      ]);
    }
    for (final zone in originals.where(
      (z) => !z.isWeeklyPlacement && z.facetId == null,
    )) {
      final facet = await ref
          .read(zoneFacetListProvider.notifier)
          .resolve(zone.title);
      // Assigned last, after conversion, so an interrupted pass can retry.
      final rule = zone.recurrenceRule;
      final canConvert =
          zone.anchorDate == null ||
          (rule != null && rule.interval == 1 && rule.endDate == null);
      if (canConvert) {
        final days = rule == null || rule.frequency == RecurrenceFrequency.daily
            ? {1, 2, 3, 4, 5, 6, 7}
            : (rule.daysOfWeek?.toSet() ?? {zone.anchorDate!.weekday});
        for (final day in days) {
          final id = _uuid.v5(
            Namespace.url.value,
            'amble:weekly:${zone.id}:$day',
          );
          if (repository.getById(id) != null ||
              repository.getAll().any(
                (z) =>
                    z.isWeeklyPlacement &&
                    z.facetId == facet.id &&
                    z.weekday == day &&
                    z.startMinutes == zone.startMinutes &&
                    z.endMinutes == zone.endMinutes,
              )) {
            continue;
          }
          await repository.save(
            Zone(
              id: id,
              title: facet.name,
              startMinutes: zone.startMinutes,
              endMinutes: zone.endMinutes,
              weekday: day,
              facetId: facet.id,
              sourceId: zone.id,
              effectiveFrom: today,
              notificationsEnabled: zone.notificationsEnabled,
            ),
          );
        }
        for (final sibling in originals.where(
          (z) =>
              z.id != zone.id &&
              zone.recurrenceId != null &&
              z.recurrenceId == zone.recurrenceId,
        )) {
          sibling.facetId =
              (await ref
                      .read(zoneFacetListProvider.notifier)
                      .resolve(sibling.title))
                  .id;
          sibling.sourceId =
              repository
                  .getAll()
                  .where(
                    (z) =>
                        z.isWeeklyPlacement &&
                        z.facetId == facet.id &&
                        z.startMinutes == zone.startMinutes &&
                        z.endMinutes == zone.endMinutes,
                  )
                  .firstOrNull
                  ?.sourceId ??
              zone.id;
          final sameWindow =
              sibling.startMinutes == zone.startMinutes &&
              sibling.endMinutes == zone.endMinutes &&
              sibling.facetId == facet.id;
          if (sameWindow) sibling.effectiveUntil = today;
          await repository.save(sibling);
        }
      }
      if (canConvert) {
        zone.effectiveUntil = today;
        zone.sourceId = zone.id;
      }
      zone.facetId = facet.id;
      await repository.save(zone);
    }
    _refresh();
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
  ///
  /// **A create whose title matches an existing zone type adds a single
  /// dated INSTANCE of that type — never a second template, and never a
  /// series-wide retune.** Confirmed directly: "the one added as existing
  /// template with same name but different hour should be just [an]
  /// instance."
  ///
  /// Applies whether the title was typed or tapped from the existing-zones
  /// list, and regardless of the Repeat switch — also confirmed directly:
  /// title IS the zone type's identity, so how you arrived at it doesn't
  /// change what it means. Only a genuinely NEW title with a
  /// [recurrenceRule] creates a template/series.
  ///
  /// The emitted row carries the matched series' `recurrenceId` with
  /// `recurrenceRule: null` — so `ZoneListBody`'s registry filter
  /// (`!isRecurring || isRecurrenceTemplate`) correctly leaves it OUT of
  /// Settings' zone list, which is the reported bug: every add, however
  /// made, was landing in that list. It still renders on the grid, which
  /// keys purely off `anchorDate`.
  ///
  /// History: this replaces a "retune the whole series in place" branch
  /// added one pass earlier, which fixed duplicate SERIES (a real backup
  /// showed one zone as four, two overlapping on 49 identical days) but
  /// overcorrected — re-adding a zone at a different hour silently moved
  /// every future occurrence. Emitting an instance fixes the duplication
  /// just as well, since one series per title is still the invariant.
  Future<Zone> createZone({
    required String title,
    required int startMinutes,
    required int endMinutes,
    RecurrenceRule? recurrenceRule,
    bool notificationsEnabled = true,
    DateTime? anchorDateForRecurrence,
  }) async {
    final day = anchorDateForRecurrence ?? DateTime.now();
    final days = recurrenceRule == null
        ? {day.weekday}
        : recurrenceRule.frequency == RecurrenceFrequency.daily
        ? {1, 2, 3, 4, 5, 6, 7}
        : (recurrenceRule.daysOfWeek?.toSet() ?? {day.weekday});
    final zones = await paintWeeklyZones(
      title: title,
      weekdays: days,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );
    for (final zone in zones) {
      zone.notificationsEnabled = notificationsEnabled;
      await ref.read(zoneRepositoryProvider).save(zone);
    }
    _refresh();
    return zones.first;
  }

  Future<void> updateZone(Zone zone) async {
    if (zone.startMinutes < 0 ||
        zone.endMinutes > 1440 ||
        zone.endMinutes <= zone.startMinutes) {
      throw ArgumentError('Choose a valid time range.');
    }
    final repository = ref.read(zoneRepositoryProvider);
    await repository.save(zone);
    // Overlap pushes neighbours aside instead of refusing the edit —
    // "never prevent action". Only a neighbour that would be swallowed
    // whole is trimmed, down to `kZoneSliverMinutes`.
    if (zone.weekday != null) {
      final others = repository
          .getAll()
          .where(
            (z) =>
                z.id != zone.id &&
                z.effectiveUntil == null &&
                z.isWeeklyPlacement &&
                z.weekday == zone.weekday,
          )
          .toList();
      for (final move in resolveZonePlacement(
        placedZoneId: zone.id,
        placedOriginalStartMinutes: zone.startMinutes,
        placedStartMinutes: zone.startMinutes,
        placedEndMinutes: zone.endMinutes,
        otherZones: others,
        tasksByZoneId: const {},
      ).where((m) => m.zoneId != zone.id)) {
        final other = repository.getById(move.zoneId);
        if (other == null) continue;
        other.startMinutes = move.newStartMinutes;
        other.endMinutes = move.newEndMinutes;
        await repository.save(other);
      }
    }
    _refresh();
    _syncNotification(zone);
  }

  /// Creates a ONE-OFF zone occurrence pinned to a single calendar day.
  ///
  /// [createZone] cannot express this shape. Its non-recurring path
  /// deliberately leaves `anchorDate` null, which every day-membership
  /// check in the app (`_appliesOnDay`, `resolveZoneContainment`) reads as
  /// "applies to EVERY day" — correct for a zone the user means as a
  /// standing daily window, wrong for one placed on one specific square of
  /// a week grid. Its recurring path always mints a template and
  /// materializes a series, which is more than a single-day placement
  /// means.
  ///
  /// So this is the third row shape, and the only one that says "this
  /// zone, this day, once": `anchorDate` set, `recurrenceRule` null, and
  /// `recurrenceId` set only when the occurrence belongs to an existing
  /// series (which is what keeps it out of Settings' registry — see
  /// `ZoneListBody`'s `!isRecurring || isRecurrenceTemplate` filter).
  ///
  /// Used by the Weekly Zone Authoring Grid for both tap-to-create and
  /// drag-sideways-to-extend-across-days, which place occurrences on
  /// specific days by definition.
  Future<Zone> createZoneOccurrence({
    required String title,
    required int startMinutes,
    required int endMinutes,
    required DateTime day,
    bool notificationsEnabled = true,
  }) async {
    final repository = ref.read(zoneRepositoryProvider);
    final trimmedTitle = title.trim();
    final dayOnly = DateTime(day.year, day.month, day.day);

    // **Every occurrence carries a group id, without exception.** Settings'
    // registry lists a row when `!isRecurring || isRecurrenceTemplate`, and
    // `isRecurring` is only `recurrenceId != null` — so a dated occurrence
    // with a null `recurrenceId` shows up there as its own "template".
    //
    // An earlier version set the id ONLY when a matching template already
    // existed, which meant the first "Relax" placed on the grid became a
    // Settings row, and a sideways extend across five days added five more.
    // Reported directly: "there is loooots of duplicates of same name and
    // type templates... they all've been created as templates in settings."
    //
    // Resolution order, widest match last:
    // 1. the title's own series template, if it has one (keeps a placement
    //    genuinely part of that series, so series-wide edits reach it);
    // 2. failing that, ANY existing row sharing the title — occurrences of
    //    the same zone type group together even when no series exists;
    // 3. failing that, a fresh id, so this first occurrence becomes the
    //    group every later one of the same name will find at step 2.
    //
    // Step 3 is what keeps the list clean: no row created here is ever a
    // registry row, because none is ever rule-less AND id-less. It is a
    // narrow fix, not the zone-TYPE model — that is deliberately separate
    // work (docs/DECISIONS.md), and this deliberately does not touch or
    // migrate any existing row.
    final sameTitle = repository
        .getAll()
        .where(
          (zone) =>
              zone.title.trim().toLowerCase() == trimmedTitle.toLowerCase(),
        )
        .toList();
    final groupId =
        sameTitle
            .where(
              (zone) =>
                  zone.isRecurrenceTemplate && zone.effectiveUntil == null,
            )
            .firstOrNull
            ?.recurrenceId ??
        sameTitle
            .where((zone) => zone.recurrenceId != null)
            .firstOrNull
            ?.recurrenceId ??
        _uuid.v4();

    final zone = Zone.create(
      title: trimmedTitle,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      notificationsEnabled: notificationsEnabled,
      recurrenceId: groupId,
      anchorDate: dayOnly,
    );
    await repository.save(zone);
    _refresh();
    return zone;
  }

  /// Re-anchors [instance]'s WHOLE series to a new start/end time-of-day —
  /// the Zone-level equivalent of [TaskList.updateTaskWithChangedRecurrence]
  /// that CONSTITUTION.md's own Weekly Zone Authoring Grid section flagged
  /// as missing when the "affect future instances" toggle first shipped
  /// (rendered/tracked state, but flipping it ON had no effect on
  /// move/resize). Confirmed via AskUserQuestion, mirroring Task's own
  /// confirmed rule exactly: EVERY future instance (today or later) moves
  /// to the new time — including one an earlier, individually-scoped edit
  /// had already moved to some other time. "Change all future" wins.
  ///
  /// Unlike Task, Zone has no `originalScheduledAt`/moved-instance marker
  /// to distinguish "generated where the series expects" from
  /// "individually nudged" — a Zone instance's own `startMinutes`/
  /// `endMinutes` ARE its whole state, with nothing else recording where
  /// it "should" be. So there's no need for Task's own realign dance
  /// (compare against sibling witnesses to decide what drifted): every
  /// OTHER future instance is deleted unconditionally and regenerated
  /// fresh from the re-anchored template.
  ///
  /// [instance] itself is SPARED from that delete-and-regenerate sweep —
  /// mirrors [TaskList._deleteFutureInstancesForRealign]'s own `alsoSpare`
  /// parameter exactly: deleting-then-regenerating the very row the user
  /// just dragged would silently swap its id out from under any task
  /// already assigned to it (`Task.zoneId`), orphaning that assignment.
  /// [instance] is updated in place instead, at the caller's own resolved
  /// window (identical to [newStartMinutes]/[newEndMinutes] for a move,
  /// per-instance for a resize where every selected zone can differ).
  Future<void> updateZoneSeries(
    Zone instance, {
    required int newStartMinutes,
    required int newEndMinutes,
  }) async {
    assert(
      instance.isRecurring,
      'updateZoneSeries is for a zone that belongs to a series — use '
      'updateZone for a plain one.',
    );
    final repository = ref.read(zoneRepositoryProvider);
    final notificationService = ref.read(notificationServiceProvider);
    final seriesId = instance.recurrenceId;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final seriesZones = repository
        .getAll()
        .where((zone) => zone.recurrenceId == seriesId)
        .toList();
    final template = seriesZones.firstWhere(
      (zone) => zone.isRecurrenceTemplate,
      orElse: () => instance,
    );

    for (final zone in seriesZones) {
      if (zone.id == template.id || zone.id == instance.id) continue;
      final anchor = zone.anchorDate;
      final isFuture = anchor != null && !anchor.isBefore(todayStart);
      if (!isFuture) continue;
      await repository.delete(zone.id);
      await notificationService.cancelForZone(zone.id);
    }

    // [instance] itself moves to its own resolved window — spared above,
    // updated here instead of being deleted and regenerated.
    if (instance.id != template.id) {
      instance.startMinutes = newStartMinutes;
      instance.endMinutes = newEndMinutes;
      await repository.save(instance);
    }

    // Re-anchors the template's own time-of-day — its DATE never changes,
    // matching Task's own "'all future' changes when occurrences happen,
    // never which day the series began."
    template.startMinutes = newStartMinutes;
    template.endMinutes = newEndMinutes;
    await repository.save(template);

    await _materializeSeries(template);
    _refresh();
  }

  /// Collapses duplicate same-titled series into one, and detaches
  /// orphaned rows. A one-off data repair for installs that accumulated
  /// duplicates before the two causes were fixed — run at launch (see
  /// main.dart), idempotent, and a complete no-op on healthy data.
  ///
  /// Why this is needed at all: `createZone` used to mint a fresh
  /// `recurrenceId` on every save, and the generator's `takenDays` only
  /// ever considers rows sharing its OWN `recurrenceId` — so two series
  /// for one zone would each generate a full ~8-week window straight over
  /// the other. A real backup showed one zone as four series, 156 of 268
  /// rows redundant. Fixing `createZone` stops new duplicates; only this
  /// can clear the ones already on disk.
  ///
  /// **Canonical series per title**: the one with a template, tie-broken
  /// by most rows. Preferring a template-bearing series matters because a
  /// series without one can never regenerate — keeping it as the survivor
  /// would silently stop the zone from extending into the future.
  ///
  /// Rows of a non-canonical series are DELETED rather than re-pointed at
  /// the survivor: the survivor already covers those same days (that is
  /// precisely what made them duplicates), so re-pointing would just
  /// recreate the same-day collision under one id. Non-recurring rows
  /// (`recurrenceId == null`) are never touched — they are standalone by
  /// definition and carry no series relationship to collapse.
  Future<void> repairDuplicateZoneSeries() async {
    final repository = ref.read(zoneRepositoryProvider);
    final notificationService = ref.read(notificationServiceProvider);
    final all = repository.getAll();

    final bySeries = <String, List<Zone>>{};
    for (final zone in all) {
      final seriesId = zone.recurrenceId;
      if (seriesId == null) continue;
      (bySeries[seriesId] ??= []).add(zone);
    }
    if (bySeries.isEmpty) return;

    // Pick one canonical series per title. `hasTemplate` dominates the
    // comparison, so a template-bearing series always beats a larger
    // orphan.
    final canonicalByTitle = <String, String>{};
    final scoreByTitle = <String, (bool hasTemplate, int rows)>{};
    for (final entry in bySeries.entries) {
      final rows = entry.value;
      final title = rows.first.title.trim().toLowerCase();
      final score = (
        rows.any((zone) => zone.isRecurrenceTemplate),
        rows.length,
      );
      final best = scoreByTitle[title];
      final wins =
          best == null ||
          (score.$1 && !best.$1) ||
          (score.$1 == best.$1 && score.$2 > best.$2);
      if (wins) {
        scoreByTitle[title] = score;
        canonicalByTitle[title] = entry.key;
      }
    }

    var changed = false;
    for (final entry in bySeries.entries) {
      final seriesId = entry.key;
      final rows = entry.value;
      final title = rows.first.title.trim().toLowerCase();
      if (canonicalByTitle[title] == seriesId) {
        // The survivor — but it may still be an orphan (no template), in
        // which case nothing can regenerate it and its rows should become
        // plain standalone zones rather than a half-alive series.
        if (rows.any((zone) => zone.isRecurrenceTemplate)) continue;
        for (final zone in rows) {
          zone.recurrenceId = null;
          zone.recurrenceRule = null;
          await repository.save(zone);
        }
        changed = true;
        continue;
      }

      for (final zone in rows) {
        await repository.delete(zone.id);
        await notificationService.cancelForZone(zone.id);
      }
      changed = true;
    }

    if (changed) _refresh();
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
        .where(
          (zone) => zone.isRecurrenceTemplate && zone.effectiveUntil == null,
        )
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
    final changes = {for (final move in moves) move.zoneId: move};
    final planned = repository.getAll().map((z) {
      final move = changes[z.id];
      return move == null
          ? z
          : Zone.fromJson({
              ...z.toJson(),
              'startMinutes': move.newStartMinutes,
              'endMinutes': move.newEndMinutes,
            });
    }).toList();
    // Only genuinely impossible windows are rejected here — running off the
    // end of the day, or an inverted window. Overlap is NOT rejected: the
    // caller has already resolved it via `resolveZonePlacement`, and
    // re-validating it here would reject that function's own planned
    // output (which is exactly what this check used to do).
    //
    // **In debug builds this is unreachable**: `Zone.fromJson` above runs
    // the model's own constructor asserts on every planned row first, and
    // those reject exactly these windows. It stays because asserts are
    // stripped in release builds, where this becomes the only guard — so
    // it is a real backstop, not dead code, but it cannot be unit-tested
    // through this path (see `weekly_zone_schedule_test.dart`).
    for (final zone in planned.where(
      (z) => changes.containsKey(z.id) && z.isWeeklyPlacement,
    )) {
      if (zone.startMinutes < 0 ||
          zone.endMinutes > 1440 ||
          zone.endMinutes <= zone.startMinutes) {
        throw StateError('That move leaves the day.');
      }
    }

    for (final move in moves) {
      final zone = repository.getById(move.zoneId);
      if (zone != null) {
        zone.startMinutes = move.newStartMinutes;
        zone.endMinutes = move.newEndMinutes;
        await repository.save(zone);
        _syncNotification(zone);
      }
      if (zone?.isWeeklyPlacement == true) continue;
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
    final repository = ref.read(zoneRepositoryProvider);
    final zone = repository.getById(id);
    if (zone?.isWeeklyPlacement == true) {
      zone!.archived = true;
      await repository.save(zone);
    } else {
      await repository.delete(id);
    }
    await ref.read(notificationServiceProvider).cancelForZone(id);
    _refresh();
  }

  /// Deletes [instance] and every OTHER instance of its series that falls
  /// today or later, mirroring [TaskList.deleteTaskSeries]'s exact
  /// "this and all future" shape — used by the Weekly Zone Authoring
  /// Grid's drag-to-delete when its "affect future instances" toggle is on
  /// (see docs/DECISIONS.md's entry for this addition). Past instances of
  /// the same series are left untouched, matching Task's own reasoning:
  /// history shouldn't disappear because a later occurrence was removed.
  ///
  /// If the series' template itself survives (its own `anchorDate` is in
  /// the past and it isn't [instance]), it's detached from the series
  /// (`recurrenceId`/`recurrenceRule` cleared) exactly like
  /// `deleteTaskSeries` detaches a surviving past template — otherwise the
  /// next `materializeDueRecurrences()` pass would keep regenerating the
  /// "deleted" future instances from that same template.
  Future<void> deleteZoneSeries(Zone instance) async {
    assert(
      instance.isRecurring,
      'deleteZoneSeries is for a zone that belongs to a series — use '
      'deleteZone for a plain one.',
    );
    final repository = ref.read(zoneRepositoryProvider);
    final notificationService = ref.read(notificationServiceProvider);
    final seriesId = instance.recurrenceId;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final seriesZones = repository
        .getAll()
        .where((zone) => zone.recurrenceId == seriesId)
        .toList();

    for (final zone in seriesZones) {
      final anchor = zone.anchorDate;
      final isFuture = anchor != null && !anchor.isBefore(todayStart);
      // The tapped/dragged instance goes regardless of when it falls —
      // matches deleteTaskSeries's own "the user asked for it directly"
      // reasoning.
      if (isFuture || zone.id == instance.id) {
        await repository.delete(zone.id);
        await notificationService.cancelForZone(zone.id);
      }
    }

    // Whatever rows of this series are still standing after the sweep
    // above — every past instance, plus a past template that wasn't the
    // dragged one. Resolved FRESH from the repository rather than by
    // reasoning about `seriesZones` (already stale by now, since the loop
    // deleted from under it).
    final survivors = repository
        .getAll()
        .where((zone) => zone.recurrenceId == seriesId)
        .toList();

    // A series whose TEMPLATE is gone but whose past instances survive is
    // an orphan: nothing can ever regenerate it (the generator needs a
    // template), but every stranded row still renders on the grid forever
    // — which is exactly what a real backup showed (40 rows, 0 templates,
    // all still drawing as duplicate "Morning ritual" blocks). The old
    // code only detached a template that survived in the PAST, and said
    // nothing about the case where the template itself was deleted.
    //
    // Detaching each survivor (clearing `recurrenceId`/`recurrenceRule`)
    // turns them back into ordinary standalone past rows — history is
    // preserved, exactly as `deleteTaskSeries` intends, without leaving a
    // half-alive series behind.
    final templateGone = !survivors.any((zone) => zone.isRecurrenceTemplate);
    for (final zone in survivors) {
      final isSurvivingPastTemplate = zone.isRecurrenceTemplate;
      if (!templateGone && !isSurvivingPastTemplate) continue;
      zone.recurrenceId = null;
      zone.recurrenceRule = null;
      await repository.save(zone);
    }

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
    await ref
        .read(notificationServiceProvider)
        .scheduleZoneCalendar(ref.read(zoneRepositoryProvider).getAll());
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
