import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/repositories/hive_zone_repository.dart';

import '../../support/fake_notification_service.dart';

void main() {
  late Box<Zone> box;
  late ProviderContainer container;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_zone_providers');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Zone>(
      'test_zones_${DateTime.now().microsecondsSinceEpoch}',
    );

    container = ProviderContainer(
      overrides: [
        zoneRepositoryProvider.overrideWithValue(HiveZoneRepository(box)),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await box.deleteFromDisk();
  });

  group('dev-only clear tools', () {
    test('clearAllZones deletes every zone', () async {
      final notifier = container.read(zoneListProvider.notifier);
      await notifier.createZone(
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
      );
      await notifier.createZone(
        title: 'Evening wind-down',
        startMinutes: 21 * 60,
        endMinutes: 22 * 60,
      );
      expect(container.read(zoneListProvider), hasLength(2));

      await notifier.clearAllZones();

      expect(container.read(zoneListProvider), isEmpty);
      expect(container.read(zoneRepositoryProvider).getAll(), isEmpty);
    });
  });

  group('importZones', () {
    test('a new zone (id not previously seen) is imported', () async {
      final notifier = container.read(zoneListProvider.notifier);
      final zone = Zone.create(
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
      );

      final result = await notifier.importZones([zone]);

      expect(result.imported, 1);
      expect(result.alreadyPresent, 0);
      expect(result.conflicts, 0);
      expect(container.read(zoneRepositoryProvider).getById(zone.id), zone);
    });

    test('an identical zone (same id, same fields) counts as already '
        'present and is not rewritten', () async {
      final notifier = container.read(zoneListProvider.notifier);
      final zone = await notifier.createZone(
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
      );
      final reimported = Zone(
        id: zone.id,
        title: zone.title,
        startMinutes: zone.startMinutes,
        endMinutes: zone.endMinutes,
      );

      final result = await notifier.importZones([reimported]);

      expect(result.imported, 0);
      expect(result.alreadyPresent, 1);
      expect(result.conflicts, 0);
    });

    test('a same-id zone with DIFFERENT fields counts as a conflict and is '
        'left completely untouched — never silently overwritten', () async {
      final notifier = container.read(zoneListProvider.notifier);
      final zone = await notifier.createZone(
        title: 'Morning ritual',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
      );
      final conflicting = Zone(
        id: zone.id,
        title: 'Renamed elsewhere',
        startMinutes: zone.startMinutes,
        endMinutes: zone.endMinutes,
      );

      final result = await notifier.importZones([conflicting]);

      expect(result.imported, 0);
      expect(result.alreadyPresent, 0);
      expect(result.conflicts, 1);
      expect(
        container.read(zoneRepositoryProvider).getById(zone.id)?.title,
        'Morning ritual',
      );
    });
  });
}
