import '../models/zone.dart';

/// Orders [zones] so selected zones paint last, with [liftedId] above every
/// other zone — a manipulated object remains visible over overlapping
/// siblings even when it crosses weekday columns.
///
/// A day/column's zones carry no reliable render order of their own
/// (repository insertion order); both the spatial Timeline and the
/// Weekly Zone Authoring Grid explicitly allow overlapping/adjacent
/// zones whose resize handles extend past their own bounds (both
/// screens' own zone-rendering `Stack`s are `Clip.none`), so an
/// unselected sibling painted after the selected one could otherwise
/// cover its selection ring or handles. The active lifted zone is the
/// final paint child; ties retain their input order.
List<Zone> selectedZonesLast(
  Iterable<Zone> zones,
  Set<String> selectedIds, {
  String? liftedId,
}) {
  final ordered = zones.toList();
  return [
    for (final zone in ordered)
      if (zone.id != liftedId && !selectedIds.contains(zone.id)) zone,
    for (final zone in ordered)
      if (zone.id != liftedId && selectedIds.contains(zone.id)) zone,
    for (final zone in ordered)
      if (zone.id == liftedId) zone,
  ];
}
