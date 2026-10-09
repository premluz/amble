import 'field_override.dart';
import 'local_date.dart';

/// The device's time zone (IANA name) from [effectiveFrom] onward.
class ZoneHistoryEntry {
  const ZoneHistoryEntry({required this.effectiveFrom, required this.zoneName});

  final LocalDate effectiveFrom;
  final String zoneName;

  Map<String, dynamic> toJson() => {
    'effectiveFrom': effectiveFrom.toIso(),
    'zoneName': zoneName,
  };

  factory ZoneHistoryEntry.fromJson(Map<String, dynamic> json) {
    final zoneName = decodeString(json['zoneName']);
    if (zoneName.isEmpty) {
      throw const FormatException('ZoneHistoryEntry: empty zone name');
    }
    return ZoneHistoryEntry(
      effectiveFrom: LocalDate.parse(decodeString(json['effectiveFrom'])),
      zoneName: zoneName,
    );
  }
}

/// Which time zone each day used, so travel never re-dates or revives a
/// past occurrence (contract §7).
///
/// A day keeps the zone it began in; a zone change applies from the next
/// day. Without that, flying west can make "today" Monday again in the new
/// zone and turn Monday's already-omitted occurrences back into upcoming.
/// Days after today always float to the current zone (D2).
class ZoneHistory {
  ZoneHistory(Iterable<ZoneHistoryEntry> entries)
    : entries = List.unmodifiable(
        entries.toList()
          ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom)),
      );

  final List<ZoneHistoryEntry> entries;

  /// The zone for [date]: [currentZone] after [today]; for today and
  /// earlier, the latest zone recorded on or before it, else [currentZone]
  /// (nothing was recorded that far back).
  String zoneNameOn(
    LocalDate date, {
    required LocalDate today,
    required String currentZone,
  }) {
    if (date.isAfter(today)) return currentZone;
    String? applicable;
    for (final entry in entries) {
      if (entry.effectiveFrom.isAfter(date)) break;
      applicable = entry.zoneName;
    }
    return applicable ?? currentZone;
  }
}
