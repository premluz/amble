import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/zone.dart';
import '../repositories/hive_zone_repository.dart';
import '../repositories/zone_repository.dart';

part 'zone_providers.g.dart';

const zoneBoxName = 'zones';

@Riverpod(keepAlive: true)
ZoneRepository zoneRepository(Ref ref) {
  final box = Hive.box<Zone>(zoneBoxName);
  return HiveZoneRepository(box);
}

/// CRUD state over [ZoneRepository], mirroring `TrackedBehaviorList`.
///
/// `keepAlive: true` rather than `autoDispose`, per the Phase 1 decision in
/// docs/DECISIONS.md: this is session-scoped app state, and `autoDispose`
/// caused a real bug where a notifier's own write could be torn down
/// mid-flight with no listener active. Same reasoning applies here.
///
/// Nothing reads this provider yet — no Zone UI exists and none is gated
/// yet (see `core/feature_flags.dart`). Built now so the data layer is
/// complete and testable ahead of that UI.
@Riverpod(keepAlive: true)
class ZoneList extends _$ZoneList {
  @override
  List<Zone> build() {
    return ref.watch(zoneRepositoryProvider).getAll();
  }

  Future<void> createZone({
    required String title,
    required int startMinutes,
    required int endMinutes,
  }) async {
    final zone = Zone.create(
      title: title,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );
    await ref.read(zoneRepositoryProvider).save(zone);
    _refresh();
  }

  Future<void> updateZone(Zone zone) async {
    await ref.read(zoneRepositoryProvider).save(zone);
    _refresh();
  }

  Future<void> deleteZone(String id) async {
    await ref.read(zoneRepositoryProvider).delete(id);
    _refresh();
  }

  void _refresh() {
    state = ref.read(zoneRepositoryProvider).getAll();
  }
}
