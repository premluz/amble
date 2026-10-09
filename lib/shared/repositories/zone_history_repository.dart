import 'package:hive_ce/hive_ce.dart';

import '../models/local_date.dart';
import '../models/zone_history.dart';

abstract class ZoneHistoryRepository {
  ZoneHistory load();

  /// Records the device zone observed on [today] (local date in that zone).
  /// The first entry applies from [today]; a later change applies from the
  /// next day, because today already began in the previous zone. A no-op
  /// when [zoneName] is already the latest zone, so calling it on every
  /// launch stays one entry per actual change.
  Future<void> recordZone(String zoneName, LocalDate today);
}

class HiveZoneHistoryRepository implements ZoneHistoryRepository {
  HiveZoneHistoryRepository(this._box);

  final Box<dynamic> _box;
  static const boxName = 'zone_history';

  static Future<void> initialize() => Hive.openBox<dynamic>(boxName);

  factory HiveZoneHistoryRepository.opened() =>
      HiveZoneHistoryRepository(Hive.box<dynamic>(boxName));

  @override
  ZoneHistory load() => ZoneHistory(_box.values.map(_decode));

  @override
  Future<void> recordZone(String zoneName, LocalDate today) async {
    final entries = load().entries;
    if (entries.isNotEmpty && entries.last.zoneName == zoneName) return;
    final effectiveFrom = entries.isEmpty ? today : today.addDays(1);
    final entry = ZoneHistoryEntry(
      effectiveFrom: effectiveFrom,
      zoneName: zoneName,
    );
    await _box.put(effectiveFrom.toIso(), entry.toJson());
  }

  static ZoneHistoryEntry _decode(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Stored zone history entry is not a map');
    }
    return ZoneHistoryEntry.fromJson(Map<String, dynamic>.from(raw));
  }
}
