import '../models/scheduled_block.dart';
import '../models/zone.dart';

/// One stretch of free time inside a day's planning hours, with the names of
/// the zones it overlaps.
class FreeWindow {
  const FreeWindow({
    required this.start,
    required this.end,
    required this.zoneNames,
  });

  final DateTime start;
  final DateTime end;
  final List<String> zoneNames;

  int get minutes => end.difference(start).inMinutes;
}

/// Free time between [from] and [to], day by day, inside each day's
/// [dayStartMinutes]..[dayEndMinutes] (minutes after local midnight), with
/// every [busy] block subtracted. Windows shorter than [minMinutes] are
/// dropped. When [zoneName] is given, each window is clipped to that zone's
/// hours on its day, so the result is "free time inside Focus", not "free
/// time that touches Focus".
///
/// Pure: the caller decides what counts as busy (tasks, imported events) and
/// supplies the zones for a day, so this is testable with plain values.
List<FreeWindow> computeFreeWindows({
  required Iterable<ScheduledBlock> busy,
  required List<Zone> Function(DateTime day) zonesOn,
  required DateTime from,
  required DateTime to,
  required int dayStartMinutes,
  required int dayEndMinutes,
  required int minMinutes,
  String? zoneName,
}) {
  final blocks = busy.toList()
    ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
  final windows = <FreeWindow>[];
  for (
    var day = DateTime(from.year, from.month, from.day);
    day.isBefore(to);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    final zones = zonesOn(day);
    final open = _later(from, _at(day, dayStartMinutes));
    final close = _earlier(to, _at(day, dayEndMinutes));
    for (final gap in _gaps(open, close, blocks)) {
      for (final piece in _clipToZone(gap, day, zones, zoneName)) {
        if (piece.$2.difference(piece.$1).inMinutes < minMinutes) continue;
        windows.add(
          FreeWindow(
            start: piece.$1,
            end: piece.$2,
            zoneNames: _zonesTouching(piece, day, zones),
          ),
        );
      }
    }
  }
  return windows;
}

typedef _Span = (DateTime, DateTime);

DateTime _at(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day).add(Duration(minutes: minutes));

DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

/// The parts of [open]..[close] no block covers. [blocks] is sorted by start.
List<_Span> _gaps(DateTime open, DateTime close, List<ScheduledBlock> blocks) {
  if (!open.isBefore(close)) return const [];
  final gaps = <_Span>[];
  var cursor = open;
  for (final block in blocks) {
    if (!block.scheduledEnd.isAfter(cursor)) continue;
    if (!block.scheduledStart.isBefore(close)) break;
    if (block.scheduledStart.isAfter(cursor)) {
      gaps.add((cursor, block.scheduledStart));
    }
    cursor = _later(cursor, block.scheduledEnd);
    if (!cursor.isBefore(close)) return gaps;
  }
  gaps.add((cursor, close));
  return gaps;
}

List<_Span> _clipToZone(
  _Span gap,
  DateTime day,
  List<Zone> zones,
  String? zoneName,
) {
  if (zoneName == null) return [gap];
  final wanted = zoneName.trim().toLowerCase();
  return [
    for (final zone in zones)
      if (zone.title.trim().toLowerCase() == wanted)
        (
          _later(gap.$1, _at(day, zone.startMinutes)),
          _earlier(gap.$2, _at(day, zone.endMinutes)),
        ),
  ].where((span) => span.$1.isBefore(span.$2)).toList();
}

List<String> _zonesTouching(_Span span, DateTime day, List<Zone> zones) => [
  for (final zone in zones)
    if (_at(day, zone.startMinutes).isBefore(span.$2) &&
        _at(day, zone.endMinutes).isAfter(span.$1))
      zone.title,
];
