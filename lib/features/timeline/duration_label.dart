/// Formats [minutes] as a short duration label — "1h 40m", "2h", "45m" —
/// for any place on the Timeline that shows a task/window/zone's
/// duration. Promoted to one shared function after the same logic was
/// found duplicated (and, in two of the three copies, buggy) across
/// `FreeWindowBlock`, `TaskCapsuleBlock`, and `ZoneContainerBlock`: the
/// two that only handled the whole-hours and under-an-hour cases showed
/// a duration like 100 minutes as the literal "100m" rather than
/// "1h 40m" — reported directly. `ZoneContainerBlock`'s own version
/// already had the correct three-way split; this is that version, shared.
String formatDurationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '${remainder}m';
  if (remainder == 0) return '${hours}h';
  return '${hours}h ${remainder}m';
}
