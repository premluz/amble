import 'package:flutter_test/flutter_test.dart';

import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/services/zone_selection_order.dart';

/// Covers `selectedZonesLast` — requested directly: "selected zone z index
/// goes to top of stack." A selected zone must paint LAST among its
/// siblings so its selection ring/resize handles/live-edge labels aren't
/// covered by an unselected neighbour rendered after it.
void main() {
  Zone zoneOf(String id) =>
      Zone(id: id, title: id, startMinutes: 0, endMinutes: 60);

  test('an unselected list keeps its original order unchanged', () {
    final zones = [zoneOf('a'), zoneOf('b'), zoneOf('c')];

    final ordered = selectedZonesLast(zones, const {});

    expect(ordered.map((z) => z.id), ['a', 'b', 'c']);
  });

  test('a selected zone in the middle moves to the end', () {
    final zones = [zoneOf('a'), zoneOf('b'), zoneOf('c')];

    final ordered = selectedZonesLast(zones, {'b'});

    expect(ordered.last.id, 'b');
    expect(ordered.map((z) => z.id).toSet(), {'a', 'b', 'c'});
  });

  test('multiple selected zones all move after every unselected one, '
      'relative order preserved within each group (stable sort)', () {
    final zones = [zoneOf('a'), zoneOf('b'), zoneOf('c'), zoneOf('d')];

    final ordered = selectedZonesLast(zones, {'a', 'c'});

    expect(ordered.map((z) => z.id), ['b', 'd', 'a', 'c']);
  });

  test('every zone selected leaves the order unchanged', () {
    final zones = [zoneOf('a'), zoneOf('b')];

    final ordered = selectedZonesLast(zones, {'a', 'b'});

    expect(ordered.map((z) => z.id), ['a', 'b']);
  });

  test('does not mutate the input iterable', () {
    final zones = [zoneOf('a'), zoneOf('b')];

    selectedZonesLast(zones, {'a'});

    expect(zones.map((z) => z.id), ['a', 'b']);
  });
}
