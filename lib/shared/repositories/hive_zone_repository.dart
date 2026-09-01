import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/zone.dart';
import 'zone_repository.dart';

class HiveZoneRepository implements ZoneRepository {
  HiveZoneRepository(this._box);

  final Box<Zone> _box;

  @override
  List<Zone> getAll() => _box.values.toList();

  @override
  Zone? getById(String id) => _box.get(id);

  @override
  Future<void> save(Zone zone) => _box.put(zone.id, zone);

  @override
  Future<void> delete(String id) => _box.delete(id);
}
