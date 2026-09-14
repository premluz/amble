import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/providers/zone_facet_providers.dart';
import 'package:amble/shared/services/weekly_zone_schedule.dart';
import 'package:amble/shared/services/zone_cascade_reschedule.dart';

import '../../support/memory_zone_repositories.dart';

void main() {
  late MemoryZoneRepository repository;
  late MemoryZoneFacetRepository facets;
  late ProviderContainer container;
  setUp(() {
    repository = MemoryZoneRepository();
    facets = MemoryZoneFacetRepository();
    container = ProviderContainer(
      overrides: [
        zoneRepositoryProvider.overrideWithValue(repository),
        zoneFacetRepositoryProvider.overrideWithValue(facets),
      ],
    );
  });
  tearDown(() => container.dispose());
  test(
    'painting creates independent weekly windows and one timeless facet',
    () async {
      final zones = await container
          .read(zoneListProvider.notifier)
          .paintWeeklyZones(
            title: 'Work',
            weekdays: {1, 2, 3},
            startMinutes: 540,
            endMinutes: 1020,
          );
      expect(zones, hasLength(3));
      expect(zones.map((z) => z.id).toSet(), hasLength(3));
      expect(
        zones.every(
          (z) =>
              z.recurrenceId == null &&
              z.recurrenceRule == null &&
              z.anchorDate == null,
        ),
        isTrue,
      );
      expect(
        facets.getAll().single.toJson().keys,
        unorderedEquals(['id', 'name', 'schemaVersion']),
      );
      expect(zonesForDay(zones, DateTime(2030, 1, 7)), hasLength(1));
      expect(zonesForDay(zones, DateTime(2030, 1, 10)), isEmpty);
    },
  );
  test('reuse does not copy or mutate another placement’s hours', () async {
    final notifier = container.read(zoneListProvider.notifier);
    final morning = await notifier.paintWeeklyZones(
      title: 'Commute',
      weekdays: {1},
      startMinutes: 480,
      endMinutes: 510,
    );
    await notifier.paintWeeklyZones(
      title: 'commute',
      weekdays: {1},
      startMinutes: 1020,
      endMinutes: 1050,
    );
    expect(facets.getAll(), hasLength(1));
    expect(repository.getAll(), hasLength(2));
    expect(morning.single.startMinutes, 480);
  });
  // Overlap NEVER refuses a paint — confirmed directly, "never prevent
  // action". Replaces a test asserting the opposite ("conflict anywhere
  // prevents the entire paint"), written when overlap hard-blocked.
  test('an overlapping paint is written in full; the zone it lands on is displaced, never deleted', () async {
    final notifier = container.read(zoneListProvider.notifier);
    final existing = (await notifier.paintWeeklyZones(
      title: 'Work',
      weekdays: {3},
      startMinutes: 540,
      endMinutes: 600,
    )).single;
    await notifier.paintWeeklyZones(
      title: 'Other',
      weekdays: {1, 2, 3},
      startMinutes: 570,
      endMinutes: 630,
    );
    // All three requested days written — nothing partial, nothing refused.
    expect(repository.getAll().where((z) => z.title == 'Other'), hasLength(3));
    expect(facets.getAll(), hasLength(2));
    // The zone it overlapped survives, keeping at least a sliver.
    final after = repository.getById(existing.id);
    expect(after, isNotNull);
    expect(
      after!.endMinutes - after.startMinutes,
      greaterThanOrEqualTo(kZoneSliverMinutes),
    );
  });
  test('adjacent windows are valid but midnight overflow is refused', () async {
    final notifier = container.read(zoneListProvider.notifier);
    await notifier.paintWeeklyZones(
      title: 'A',
      weekdays: {1},
      startMinutes: 0,
      endMinutes: 60,
    );
    await notifier.paintWeeklyZones(
      title: 'B',
      weekdays: {1},
      startMinutes: 60,
      endMinutes: 1440,
    );
    await expectLater(
      notifier.paintWeeklyZones(
        title: 'C',
        weekdays: {2},
        startMinutes: 1380,
        endMinutes: 1445,
      ),
      throwsArgumentError,
    );
  });
  test('migration preserves old IDs, historical times, and changed future exceptions; repeat is idempotent', () async {
    final template = Zone(
      id: 'series',
      title: 'Work',
      startMinutes: 540,
      endMinutes: 600,
      recurrenceId: 'series',
      recurrenceRule: RecurrenceRule(frequency: RecurrenceFrequency.daily),
      anchorDate: DateTime(2026, 9, 1),
    );
    await repository.save(template);
    await repository.save(
      Zone(
        id: 'normal',
        title: 'Work',
        startMinutes: 540,
        endMinutes: 600,
        recurrenceId: 'series',
        anchorDate: DateTime(2026, 9, 15),
      ),
    );
    await repository.save(
      Zone(
        id: 'exception',
        title: 'Work',
        startMinutes: 600,
        endMinutes: 660,
        recurrenceId: 'series',
        anchorDate: DateTime(2026, 9, 16),
      ),
    );
    final notifier = container.read(zoneListProvider.notifier);
    await notifier.migrateToWeeklySchedule(now: DateTime(2026, 9, 14));
    expect(repository.getAll(), hasLength(10));
    expect(
      zonesForDay(repository.getAll(), DateTime(2026, 9, 1)).single.id,
      'series',
    );
    expect(
      zonesForDay(repository.getAll(), DateTime(2026, 9, 15)).single.weekday,
      2,
    );
    expect(
      zonesForDay(repository.getAll(), DateTime(2026, 9, 16)).single.id,
      'exception',
    );
    expect(repository.getById('normal'), isNotNull);
    await notifier.migrateToWeeklySchedule(now: DateTime(2026, 9, 14));
    expect(repository.getAll(), hasLength(10));
  });
  test(
    'dateless every-day migration yields seven independent placements',
    () async {
      await repository.save(
        Zone(id: 'daily', title: 'Ritual', startMinutes: 420, endMinutes: 480),
      );
      await container
          .read(zoneListProvider.notifier)
          .migrateToWeeklySchedule(now: DateTime(2026, 9, 14));
      for (var day = 14; day <= 20; day++) {
        expect(
          zonesForDay(repository.getAll(), DateTime(2026, 9, day)),
          hasLength(1),
        );
      }
      expect(
        zonesForDay(repository.getAll(), DateTime(2026, 9, 13)).single.id,
        'daily',
      );
    },
  );
  // `commitZoneCascade` used to re-validate overlap and throw — which meant
  // it REJECTED the cascade's own planned output, the likely reason pushing
  // appeared not to work at all. It now only rejects genuinely impossible
  // windows (off the end of the day, or inverted); resolving overlap is the
  // caller's job, via `resolveZonePlacement`.
  test('a group resize that overlaps is committed, not refused', () async {
    final notifier = container.read(zoneListProvider.notifier);
    final a = (await notifier.paintWeeklyZones(
      title: 'A',
      weekdays: {1},
      startMinutes: 60,
      endMinutes: 120,
    )).single;
    final b = (await notifier.paintWeeklyZones(
      title: 'B',
      weekdays: {1},
      startMinutes: 150,
      endMinutes: 180,
    )).single;
    await notifier.commitZoneCascade([
      ZoneMove(
        zoneId: a.id,
        newStartMinutes: 60,
        newEndMinutes: 160,
        taskMoves: [],
      ),
      ZoneMove(
        zoneId: b.id,
        newStartMinutes: 150,
        newEndMinutes: 220,
        taskMoves: [],
      ),
    ]);
    expect(repository.getById(a.id)!.endMinutes, 160);
    expect(repository.getById(b.id)!.endMinutes, 220);
  });

  // Deliberately NOT tested: `commitZoneCascade`'s own "that move leaves the
  // day" `StateError`. It is unreachable from any input — the function
  // rebuilds each planned row through `Zone.fromJson`, whose constructor
  // asserts reject an out-of-day or inverted window first. The guard is kept
  // in the provider anyway (asserts are stripped in release builds, so it
  // stays a real backstop there), but a test pinning it would only ever be
  // asserting which of the two checks fires first, not any behaviour a user
  // can reach. A test that cannot fail for the reason it claims is worse
  // than no test.
  test(
    'duplicate legacy series share weekly windows while every old ID survives',
    () async {
      for (final id in ['first', 'duplicate']) {
        await repository.save(
          Zone(
            id: id,
            title: 'Work',
            startMinutes: 540,
            endMinutes: 600,
            recurrenceId: id,
            recurrenceRule: RecurrenceRule(
              frequency: RecurrenceFrequency.daily,
            ),
            anchorDate: DateTime(2026, 9, 1),
          ),
        );
      }
      final notifier = container.read(zoneListProvider.notifier);
      await notifier.migrateToWeeklySchedule(now: DateTime(2026, 9, 14));
      expect(
        repository.getAll().where((z) => z.isWeeklyPlacement),
        hasLength(7),
      );
      expect(repository.getById('first'), isNotNull);
      expect(repository.getById('duplicate'), isNotNull);
      await notifier.migrateToWeeklySchedule(now: DateTime(2026, 9, 14));
      expect(repository.getAll(), hasLength(9));
    },
  );
}
