import '../models/zone.dart';

/// Orders [zones] so any zone whose id is in [selectedIds] paints LAST —
/// requested directly: "selected zone z index goes to top of stack."
///
/// A day/column's zones carry no reliable render order of their own
/// (repository insertion order); both the spatial Timeline and the
/// Weekly Zone Authoring Grid explicitly allow overlapping/adjacent
/// zones whose resize handles extend past their own bounds (both
/// screens' own zone-rendering `Stack`s are `Clip.none`), so an
/// unselected sibling painted after the selected one could otherwise
/// cover its selection ring or handles. Stable sort — ties (both
/// selected, or both unselected) keep their original relative order.
List<Zone> selectedZonesLast(Iterable<Zone> zones, Set<String> selectedIds) {
  return zones.toList()..sort(
    (a, b) => (selectedIds.contains(a.id) ? 1 : 0).compareTo(
      selectedIds.contains(b.id) ? 1 : 0,
    ),
  );
}
