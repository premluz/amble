import 'package:hive_ce/hive_ce.dart';
import '../models/zone_facet.dart';

abstract class ZoneFacetRepository {
  List<ZoneFacet> getAll();
  Future<void> save(ZoneFacet facet);
  Future<void> delete(String id);
}

/// Primitive maps need no adapter/type ID. Hive access stays in the repository.
class HiveZoneFacetRepository implements ZoneFacetRepository {
  HiveZoneFacetRepository(this._box);
  final Box<dynamic> _box;
  static const boxName = 'zone_facets';
  static Future<void> initialize() async { await Hive.openBox<dynamic>(boxName); }
  factory HiveZoneFacetRepository.opened() => HiveZoneFacetRepository(Hive.box<dynamic>(boxName));
  @override
  List<ZoneFacet> getAll() => _box.values.map((value) => ZoneFacet.fromJson(Map<String, dynamic>.from(value as Map))).toList();
  @override
  Future<void> save(ZoneFacet facet) => _box.put(facet.id, facet.toJson());
  @override
  Future<void> delete(String id) => _box.delete(id);
}
