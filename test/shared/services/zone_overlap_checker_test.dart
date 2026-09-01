import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/services/zone_overlap_checker.dart';

Zone _zone(int start, int end) =>
    Zone(id: 'z', title: 'Z', startMinutes: start, endMinutes: end);

void main() {
  group('zonesOverlap', () {
    test('two zones with intersecting ranges overlap', () {
      expect(zonesOverlap(_zone(60, 120), _zone(90, 150)), isTrue);
    });

    test('one zone fully nested inside another overlaps', () {
      expect(zonesOverlap(_zone(0, 180), _zone(60, 90)), isTrue);
    });

    test('identical ranges overlap', () {
      expect(zonesOverlap(_zone(60, 120), _zone(60, 120)), isTrue);
    });

    test('adjacent zones (one ends exactly when the other starts) do not '
        'overlap — half-open interval', () {
      expect(zonesOverlap(_zone(0, 60), _zone(60, 120)), isFalse);
      expect(zonesOverlap(_zone(60, 120), _zone(0, 60)), isFalse);
    });

    test('clearly separate zones do not overlap', () {
      expect(zonesOverlap(_zone(0, 30), _zone(120, 150)), isFalse);
    });

    test('order of arguments does not affect the result', () {
      final a = _zone(60, 120);
      final b = _zone(90, 150);
      expect(zonesOverlap(a, b), zonesOverlap(b, a));
    });
  });
}
