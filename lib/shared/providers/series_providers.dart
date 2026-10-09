import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:timezone/timezone.dart' as tz;

import '../repositories/command_log_repository.dart';
import '../repositories/occurrence_alert_state_repository.dart';
import '../repositories/occurrence_record_repository.dart';
import '../repositories/series_repository.dart';
import '../repositories/zone_history_repository.dart';
import '../services/occurrence_timing.dart';
import '../services/recurrence_command_service.dart';

final seriesRepositoryProvider = Provider<SeriesRepository>(
  (ref) => HiveSeriesRepository.opened(),
);

final occurrenceRecordRepositoryProvider = Provider<OccurrenceRecordRepository>(
  (ref) => HiveOccurrenceRecordRepository.opened(),
);

final commandLogRepositoryProvider = Provider<CommandLogRepository>(
  (ref) => HiveCommandLogRepository.opened(),
);

final zoneHistoryRepositoryProvider = Provider<ZoneHistoryRepository>(
  (ref) => HiveZoneHistoryRepository.opened(),
);

final occurrenceAlertStateRepositoryProvider =
    Provider<OccurrenceAlertStateRepository>(
      (ref) => HiveOccurrenceAlertStateRepository.opened(),
    );

/// A fresh clock for "now" in the device zone (`tz.local`, set by
/// `NotificationService.initialize` at launch).
final occurrenceClockProvider = Provider<OccurrenceClock Function()>(
  (ref) =>
      () => OccurrenceClock(
        now: DateTime.now(),
        currentZone: tz.local.name,
        history: ref.read(zoneHistoryRepositoryProvider).load(),
      ),
);

final recurrenceCommandServiceProvider = Provider<RecurrenceCommandService>(
  (ref) => RecurrenceCommandService(
    series: ref.read(seriesRepositoryProvider),
    records: ref.read(occurrenceRecordRepositoryProvider),
    log: ref.read(commandLogRepositoryProvider),
    now: DateTime.now,
    today: () => ref.read(occurrenceClockProvider)().today,
  ),
);

/// Every box the series model needs, opened at launch.
Future<void> openSeriesModelBoxes() async {
  await HiveSeriesRepository.initialize();
  await HiveOccurrenceRecordRepository.initialize();
  await HiveCommandLogRepository.initialize();
  await HiveZoneHistoryRepository.initialize();
  await HiveOccurrenceAlertStateRepository.initialize();
}

/// Deletes every series-model box from disk — test isolation only; the app
/// never calls this.
@visibleForTesting
Future<void> deleteSeriesModelBoxes() async {
  for (final name in [
    HiveSeriesRepository.boxName,
    HiveOccurrenceRecordRepository.boxName,
    HiveCommandLogRepository.boxName,
    HiveZoneHistoryRepository.boxName,
    HiveOccurrenceAlertStateRepository.boxName,
  ]) {
    if (Hive.isBoxOpen(name)) await Hive.box<dynamic>(name).deleteFromDisk();
  }
}

/// Records the device zone for today (a change applies from tomorrow — see
/// `ZoneHistory`).
Future<void> recordDeviceZone(ProviderContainer container) {
  final clock = container.read(occurrenceClockProvider)();
  return container
      .read(zoneHistoryRepositoryProvider)
      .recordZone(clock.currentZone, clock.today);
}
