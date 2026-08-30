import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'preferences_repository.dart';

class HivePreferencesRepository implements PreferencesRepository {
  HivePreferencesRepository(this._box);

  final Box<dynamic> _box;

  @override
  T? getValue<T>(String key) {
    final value = _box.get(key);
    // A value of the wrong type means the stored schema changed under us
    // (e.g. a preference's type was altered between releases). Treating it
    // as absent lets the caller fall back to its default instead of
    // throwing on a cast, which would make the app unlaunchable over a
    // cosmetic setting.
    return value is T ? value : null;
  }

  @override
  Future<void> setValue<T>(String key, T value) => _box.put(key, value);

  @override
  Future<void> removeValue(String key) => _box.delete(key);

  @override
  List<String> keys() => _box.keys.cast<String>().toList();
}
