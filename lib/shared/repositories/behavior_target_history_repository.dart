import 'package:hive_ce/hive_ce.dart';

import '../models/behavior_target_revision.dart';

abstract class BehaviorTargetHistoryRepository {
  List<BehaviorTargetRevision> getForBehavior(String behaviorId);

  /// Records a target from its effective date; a second save for the same
  /// behavior and date replaces the first.
  Future<void> save(BehaviorTargetRevision revision);
}

class HiveBehaviorTargetHistoryRepository
    implements BehaviorTargetHistoryRepository {
  HiveBehaviorTargetHistoryRepository(this._box);

  final Box<dynamic> _box;
  static const boxName = 'behavior_target_history';

  static Future<void> initialize() => Hive.openBox<dynamic>(boxName);

  factory HiveBehaviorTargetHistoryRepository.opened() =>
      HiveBehaviorTargetHistoryRepository(Hive.box<dynamic>(boxName));

  @override
  List<BehaviorTargetRevision> getForBehavior(String behaviorId) => _box.values
      .map(_decode)
      .where((revision) => revision.behaviorId == behaviorId)
      .toList();

  @override
  Future<void> save(BehaviorTargetRevision revision) =>
      _box.put(revision.storageKey, revision.toJson());

  static BehaviorTargetRevision _decode(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Stored behavior target is not a map');
    }
    return BehaviorTargetRevision.fromJson(Map<String, dynamic>.from(raw));
  }
}
