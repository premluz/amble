import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/synced_calendar_event.dart';
import 'package:amble/shared/providers/calendar_providers.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_synced_calendar_event_repository.dart';
import 'package:amble/shared/services/calendar_permission_service.dart';
import 'package:amble/shared/services/external_calendar_service.dart';
import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

/// A calendar whose events can change between reads, like the Calendar app.
class _ChangingCalendar extends ExternalCalendarService {
  _ChangingCalendar()
    : super(
        dc.DeviceCalendarPlugin(),
        CalendarPermissionService(dc.DeviceCalendarPlugin()),
      );

  final events = <ExternalCalendarEvent>[];
  int reads = 0;

  @override
  Future<List<ExternalCalendarEvent>> fetchEvents({
    required List<String> calendarIds,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    Set<String> excludeDeviceEventIds = const {},
  }) async {
    reads++;
    return List.of(events);
  }
}

class _OneCalendar extends CalendarDisplayIdsSetting {
  @override
  List<String> build() => const ['cal-1'];
}

void main() {
  late Box<SyncedCalendarEvent> synced;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_calendar_refresh');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    synced = await Hive.openBox<SyncedCalendarEvent>(
      'synced_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() => synced.deleteFromDisk());

  test('Refresh events re-reads a range a view already loaded', () async {
    final calendar = _ChangingCalendar();
    final container = ProviderContainer(
      overrides: [
        externalCalendarServiceProvider.overrideWithValue(calendar),
        calendarDisplayIdsSettingProvider.overrideWith(_OneCalendar.new),
        syncedCalendarEventRepositoryProvider.overrideWithValue(
          HiveSyncedCalendarEventRepository(synced),
        ),
      ],
    );
    addTearDown(container.dispose);
    final day = DateTime(2026, 10, 12);
    final range = externalCalendarEventsForRangeProvider(
      day,
      day.add(const Duration(days: 1)),
    );
    // A watching view keeps the result alive, as the Timeline does.
    container.listen(range, (_, _) {});
    expect(await container.read(range.future), isEmpty);

    calendar.events.add(
      ExternalCalendarEvent(
        id: 'e1',
        title: 'Standup',
        start: DateTime(2026, 10, 12, 9),
        end: DateTime(2026, 10, 12, 9, 15),
        sourceCalendarId: 'cal-1',
      ),
    );
    expect(await container.read(range.future), isEmpty, reason: 'cached');

    container.read(externalCalendarRefreshProvider.notifier).refresh();
    final refreshed = await container.read(range.future);
    expect(refreshed.single.title, 'Standup');
    expect(calendar.reads, 2);
  });
}
