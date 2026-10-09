import 'package:hive_ce/hive_ce.dart';

import '../models/command_log_entry.dart';

abstract class CommandLogRepository {
  CommandLogEntry? get(String commandId);
  Future<void> save(CommandLogEntry entry);

  /// Drops entries applied before [cutoff]. Entries carry before/after
  /// values (possibly note text), so they are short-lived by design.
  Future<void> pruneAppliedBefore(DateTime cutoff);
}

class HiveCommandLogRepository implements CommandLogRepository {
  HiveCommandLogRepository(this._box);

  final Box<dynamic> _box;
  static const boxName = 'recurrence_command_log';

  static Future<void> initialize() => Hive.openBox<dynamic>(boxName);

  factory HiveCommandLogRepository.opened() =>
      HiveCommandLogRepository(Hive.box<dynamic>(boxName));

  @override
  CommandLogEntry? get(String commandId) {
    final raw = _box.get(commandId);
    return raw == null ? null : _decode(raw);
  }

  @override
  Future<void> save(CommandLogEntry entry) =>
      _box.put(entry.commandId, entry.toJson());

  @override
  Future<void> pruneAppliedBefore(DateTime cutoff) => _box.deleteAll(
    _box.values
        .map(_decode)
        .where((entry) => entry.appliedAt.isBefore(cutoff))
        .map((entry) => entry.commandId),
  );

  static CommandLogEntry _decode(Object? raw) {
    if (raw is! Map) throw const FormatException('Stored command is not a map');
    return CommandLogEntry.fromJson(Map<String, dynamic>.from(raw));
  }
}
