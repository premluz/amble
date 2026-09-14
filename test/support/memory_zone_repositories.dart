import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/models/zone_facet.dart';
import 'package:amble/shared/repositories/zone_repository.dart';
import 'package:amble/shared/repositories/zone_facet_repository.dart';
class MemoryZoneRepository implements ZoneRepository {
  final rows = <String,Zone>{};
  @override
  List<Zone> getAll() => rows.values.toList();
  @override
  Zone? getById(String id) => rows[id];
  @override
  Future<void> save(Zone zone) async { rows[zone.id] = zone; }
  @override
  Future<void> delete(String id) async { rows.remove(id); }
}
class MemoryZoneFacetRepository implements ZoneFacetRepository {
  final rows = <String,ZoneFacet>{};
  @override
  List<ZoneFacet> getAll() => rows.values.toList();
  @override
  Future<void> save(ZoneFacet facet) async { rows[facet.id] = facet; }
  @override
  Future<void> delete(String id) async { rows.remove(id); }
}
