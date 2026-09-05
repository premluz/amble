import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

void main() {
  late Box<Zone> box;
  late HiveZoneRepository repository;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_zones');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Zone>(
      'test_zones_${DateTime.now().microsecondsSinceEpoch}',
    );
    repository = HiveZoneRepository(box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  test('save persists and getById retrieves it', () async {
    final zone = Zone(
      id: 'zone-1',
      title: 'Morning ritual',
      startMinutes: 420,
      endMinutes: 480,
    );

    await repository.save(zone);

    final fetched = repository.getById('zone-1');
    expect(fetched, isNotNull);
    expect(fetched!.title, 'Morning ritual');
    expect(fetched.startMinutes, 420);
    expect(fetched.endMinutes, 480);
    expect(fetched.schemaVersion, 1);
  });

  test('durationMinutes is derived, not stored', () async {
    final zone = Zone(
      id: 'z',
      title: 'Focus',
      startMinutes: 540,
      endMinutes: 600,
    );
    await repository.save(zone);

    expect(repository.getById('z')!.durationMinutes, 60);
  });

  test('getAll returns every saved zone', () async {
    await repository.save(
      Zone(id: 'a', title: 'A', startMinutes: 0, endMinutes: 60),
    );
    await repository.save(
      Zone(id: 'b', title: 'B', startMinutes: 120, endMinutes: 180),
    );

    expect(repository.getAll().length, 2);
  });

  test('saving an existing id updates rather than duplicating', () async {
    final zone = Zone(
      id: 'update-me',
      title: 'Original',
      startMinutes: 60,
      endMinutes: 120,
    );
    await repository.save(zone);

    zone.title = 'Edited';
    zone.endMinutes = 150;
    await repository.save(zone);

    expect(repository.getAll().length, 1);
    expect(repository.getById('update-me')!.title, 'Edited');
    expect(repository.getById('update-me')!.endMinutes, 150);
  });

  test('delete removes the zone', () async {
    await repository.save(
      Zone(
        id: 'to-delete',
        title: 'Gone soon',
        startMinutes: 0,
        endMinutes: 30,
      ),
    );

    await repository.delete('to-delete');

    expect(repository.getById('to-delete'), isNull);
  });

  test('getById returns null for an unknown id', () {
    expect(repository.getById('never-saved'), isNull);
  });

  test(
    'a zone with a non-null recurrenceRule round-trips through Hive',
    () async {
      final zone = Zone(
        id: 'recurring-zone',
        title: 'Morning ritual',
        startMinutes: 420,
        endMinutes: 480,
        recurrenceRule: RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          daysOfWeek: [DateTime.monday, DateTime.wednesday],
        ),
      );

      await repository.save(zone);
      final fetched = repository.getById('recurring-zone');

      expect(fetched, isNotNull);
      final rule = fetched!.recurrenceRule;
      expect(rule, isNotNull);
      expect(rule!.frequency, RecurrenceFrequency.weekly);
      expect(rule.daysOfWeek, [DateTime.monday, DateTime.wednesday]);
    },
  );

  test('recurrenceRule defaults to null (non-recurring) when unset', () async {
    final zone = Zone(
      id: 'plain-zone',
      title: 'Focus block',
      startMinutes: 60,
      endMinutes: 120,
    );
    await repository.save(zone);

    expect(repository.getById('plain-zone')!.recurrenceRule, isNull);
  });

  test('notificationsEnabled defaults to true and round-trips', () async {
    final defaultZone = Zone(
      id: 'default-notify',
      title: 'Default',
      startMinutes: 0,
      endMinutes: 60,
    );
    await repository.save(defaultZone);
    expect(repository.getById('default-notify')!.notificationsEnabled, isTrue);

    final silentZone = Zone(
      id: 'silent',
      title: 'Silent',
      startMinutes: 0,
      endMinutes: 60,
      notificationsEnabled: false,
    );
    await repository.save(silentZone);
    expect(repository.getById('silent')!.notificationsEnabled, isFalse);
  });

  test('Zone.create generates a unique client-side UUID', () {
    final a = Zone.create(title: 'A', startMinutes: 0, endMinutes: 60);
    final b = Zone.create(title: 'B', startMinutes: 0, endMinutes: 60);

    expect(a.id, isNotEmpty);
    expect(a.id, isNot(equals(b.id)));
  });

  test(
    'startMinutes outside 0-1439 is rejected — the constructor invariant',
    () {
      expect(
        () => Zone(id: 'x', title: 'Bad', startMinutes: -1, endMinutes: 60),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => Zone(id: 'x', title: 'Bad', startMinutes: 1440, endMinutes: 1440),
        throwsA(isA<AssertionError>()),
      );
    },
  );

  test('endMinutes not after startMinutes is rejected', () {
    expect(
      () => Zone(id: 'x', title: 'Bad', startMinutes: 60, endMinutes: 60),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => Zone(id: 'x', title: 'Bad', startMinutes: 120, endMinutes: 60),
      throwsA(isA<AssertionError>()),
    );
  });
}
