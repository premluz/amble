import 'package:hive_ce/hive_ce.dart';

import '../models/occurrence_alert.dart';

/// Which occurrence alerts are currently registered with the OS — needed
/// to cancel ones that should no longer exist, since the OS cannot be asked
/// "which of these did I schedule for occurrences".
abstract class OccurrenceAlertStateRepository {
  Map<int, OccurrenceAlert> getAll();
  Future<void> put(OccurrenceAlert alert);
  Future<void> remove(int notificationId);

  /// Forget everything — after an OS-wide cancel (e.g. the launch-time
  /// `NotificationService.refreshScheduled`), nothing recorded here exists.
  Future<void> clear();
}

class HiveOccurrenceAlertStateRepository
    implements OccurrenceAlertStateRepository {
  HiveOccurrenceAlertStateRepository(this._box);

  final Box<dynamic> _box;
  static const boxName = 'occurrence_alert_state';

  static Future<void> initialize() => Hive.openBox<dynamic>(boxName);

  factory HiveOccurrenceAlertStateRepository.opened() =>
      HiveOccurrenceAlertStateRepository(Hive.box<dynamic>(boxName));

  @override
  Map<int, OccurrenceAlert> getAll() => {
    for (final alert in _box.values.map(_decode)) alert.notificationId: alert,
  };

  @override
  Future<void> put(OccurrenceAlert alert) =>
      _box.put(alert.notificationId, alert.toJson());

  @override
  Future<void> remove(int notificationId) => _box.delete(notificationId);

  @override
  Future<void> clear() => _box.clear();

  static OccurrenceAlert _decode(Object? raw) {
    if (raw is! Map) throw const FormatException('Stored alert is not a map');
    return OccurrenceAlert.fromJson(Map<String, dynamic>.from(raw));
  }
}
