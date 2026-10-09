import 'package:hive_ce/hive_ce.dart';

import '../models/series.dart';
import 'stale_write_exception.dart';

abstract class SeriesRepository {
  List<Series> getAll();
  Series? get(String id);

  /// Rejects with [StaleWriteException] unless [series] is exactly one
  /// version past what is stored.
  Future<void> save(Series series);

  /// Permanent deletion. Ending a series is [Series.endedAfter], not this.
  Future<void> delete(String id);
}

/// Primitive maps need no adapter/type ID, same as zone facets. Not opened
/// at launch yet — the recurrence model is not wired into the app.
class HiveSeriesRepository implements SeriesRepository {
  HiveSeriesRepository(this._box);

  final Box<dynamic> _box;
  static const boxName = 'series';

  static Future<void> initialize() => Hive.openBox<dynamic>(boxName);

  factory HiveSeriesRepository.opened() =>
      HiveSeriesRepository(Hive.box<dynamic>(boxName));

  @override
  List<Series> getAll() => _box.values.map(_decode).toList();

  @override
  Series? get(String id) {
    final raw = _box.get(id);
    return raw == null ? null : _decode(raw);
  }

  @override
  Future<void> save(Series series) {
    checkNextVersion(
      entity: 'Series',
      id: series.id,
      storedVersion: get(series.id)?.version,
      attemptedVersion: series.version,
      initialVersion: Series.initialVersion,
    );
    return _box.put(series.id, series.toJson());
  }

  @override
  Future<void> delete(String id) => _box.delete(id);

  static Series _decode(Object? raw) {
    if (raw is! Map) throw const FormatException('Stored series is not a map');
    return Series.fromJson(Map<String, dynamic>.from(raw));
  }
}
