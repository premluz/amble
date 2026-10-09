import 'package:hive_ce/hive_ce.dart';

import '../models/occurrence_key.dart';
import '../models/occurrence_record.dart';
import 'stale_write_exception.dart';

abstract class OccurrenceRecordRepository {
  List<OccurrenceRecord> getAll();
  List<OccurrenceRecord> getForSeries(String seriesId);
  OccurrenceRecord? get(OccurrenceKey key);

  /// One record per key: a save updates it, never adds a second. Rejects
  /// with [StaleWriteException] unless [record] is exactly one version past
  /// what is stored.
  Future<void> save(OccurrenceRecord record);

  /// Removes a record — used when undo leaves it empty (§6).
  Future<void> delete(OccurrenceKey key);

  /// Permanent deletion of a series' history.
  Future<void> deleteForSeries(String seriesId);
}

class HiveOccurrenceRecordRepository implements OccurrenceRecordRepository {
  HiveOccurrenceRecordRepository(this._box);

  final Box<dynamic> _box;
  static const boxName = 'occurrence_records';

  static Future<void> initialize() => Hive.openBox<dynamic>(boxName);

  factory HiveOccurrenceRecordRepository.opened() =>
      HiveOccurrenceRecordRepository(Hive.box<dynamic>(boxName));

  @override
  List<OccurrenceRecord> getAll() => _box.values.map(_decode).toList();

  @override
  List<OccurrenceRecord> getForSeries(String seriesId) =>
      getAll().where((record) => record.key.seriesId == seriesId).toList();

  @override
  OccurrenceRecord? get(OccurrenceKey key) {
    final raw = _box.get(key.storageKey);
    return raw == null ? null : _decode(raw);
  }

  @override
  Future<void> save(OccurrenceRecord record) {
    checkNextVersion(
      entity: 'OccurrenceRecord',
      id: record.key.storageKey,
      storedVersion: get(record.key)?.version,
      attemptedVersion: record.version,
      initialVersion: OccurrenceRecord.initialVersion,
    );
    return _box.put(record.key.storageKey, record.toJson());
  }

  @override
  Future<void> delete(OccurrenceKey key) => _box.delete(key.storageKey);

  @override
  Future<void> deleteForSeries(String seriesId) => _box.deleteAll(
    getForSeries(seriesId).map((record) => record.key.storageKey),
  );

  static OccurrenceRecord _decode(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Stored occurrence record is not a map');
    }
    return OccurrenceRecord.fromJson(Map<String, dynamic>.from(raw));
  }
}
