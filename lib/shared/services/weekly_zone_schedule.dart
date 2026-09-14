import '../models/zone.dart';

/// Canonical date query for every day surface. Preserved dated exceptions take
/// precedence over their original weekly placement, never over another facet.
List<Zone> zonesForDay(Iterable<Zone> zones, DateTime day) {
  final applicable = zones.where((z) => z.appliesOn(day)).toList();
  final overridden = applicable.where((z) => !z.isWeeklyPlacement && z.sourceId != null).map((z) => z.sourceId).toSet();
  return applicable.where((z) => !z.isWeeklyPlacement || !overridden.contains(z.sourceId)).toList()
    ..sort((a,b) => a.startMinutes.compareTo(b.startMinutes));
}

bool weeklyWindowConflicts(Iterable<Zone> zones, int weekday, int start, int end,
    {Set<String> excluding = const {}, DateTime? now}) {
  final from = now ?? DateTime.now();
  final today = DateTime(from.year, from.month, from.day);
  return zones.any((z) => !z.archived && z.effectiveUntil == null && !excluding.contains(z.id) &&
    (z.weekday == weekday || (z.weekday == null && (z.anchorDate == null ||
      (!z.anchorDate!.isBefore(today) && z.anchorDate!.weekday == weekday)))) &&
    start < z.endMinutes && z.startMinutes < end);
}
