import 'package:amble/core/app_intents/app_intent_service.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'intent_test_store.dart';

void main() {
  late IntentTestStore store;
  late AppIntentService service;
  final now = DateTime(2026, 9, 9, 10);
  setUp(() async {
    store = IntentTestStore();
    await store.open();
    service = AppIntentService(store.container, now: () => now);
  });
  tearDown(() => store.close());

  Future<void> existing({DateTime? day}) async {
    final zone = Zone.create(
      title: 'Morning',
      startMinutes: 540,
      endMinutes: 600,
      anchorDate: day,
    );
    await store.zones.put(zone.id, zone);
  }

  test('creates through ZoneList and refreshes the visible provider', () async {
    expect(store.container.read(zoneListProvider), isEmpty);
    await service.handle('addZone', {
      'title': 'Evening',
      'startMinutes': 1200,
      'endMinutes': 1440,
    });
    final zone = store.container.read(zoneListProvider).single;
    expect(zone.title, 'Evening');
    expect(zone.startMinutes, 1200);
    expect(zone.endMinutes, 1440);
    expect(zone.anchorDate, isNull);
    expect(zone.weekday, now.weekday);
  });

  test(
    'reuses half-open overlap validation, with named spoken conflict',
    () async {
      await existing();
      await expectLater(
        service.handle('addZone', {
          'title': 'Conflict',
          'startMinutes': 570,
          'endMinutes': 630,
        }),
        throwsA(
          isA<AppIntentFailure>().having(
            (e) => e.message,
            'message',
            contains('overlaps "Morning"'),
          ),
        ),
      );
      expect(store.zones.length, 1);
      await service.handle('addZone', {
        'title': 'Adjacent',
        'startMinutes': 600,
        'endMinutes': 660,
      });
      expect(store.zones.length, 2);
    },
  );

  test(
    'same-day instance conflicts; other-day instance is filtered like form',
    () async {
      await existing(day: DateTime(2026, 9, 10));
      await service.handle('addZone', {
        'title': 'Today',
        'startMinutes': 540,
        'endMinutes': 600,
      });
      expect(store.zones.length, 2);
    },
  );

  test('dated occurrence today is included in overlap validation', () async {
    await existing(day: DateTime(2026, 9, 9));
    await expectLater(
      service.handle('addZone', {
        'title': 'Today',
        'startMinutes': 540,
        'endMinutes': 600,
      }),
      throwsA(isA<AppIntentFailure>()),
    );
    expect(store.zones.length, 1);
  });

  test(
    'ambiguous, reversed, overnight, and invalid time values never write',
    () async {
      for (final range in [
        (-1, 600),
        (540, 540),
        (600, 540),
        (0, 1441),
        (1440, 1440),
        (540, null),
        ('9am', 600),
      ]) {
        await expectLater(
          service.handle('addZone', {
            'title': 'Invalid',
            'startMinutes': range.$1,
            'endMinutes': range.$2,
          }),
          throwsA(isA<AppIntentFailure>()),
        );
      }
      expect(store.zones.values, isEmpty);
    },
  );
}
