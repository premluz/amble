import 'field_override.dart';
import 'occurrence_key.dart';
import 'record_aspect.dart';

/// What one applied command changed — enough to recognise a retry and to
/// undo it without touching anything else (docs/RECURRENCE_CONTRACT.md §6,
/// §12). Each command changes exactly one entity.
///
/// Holds before/after values, which can include note text — so entries are
/// pruned after a short retention window rather than kept as history.
sealed class CommandChange {
  const CommandChange();

  Map<String, dynamic> toJson();

  static CommandChange fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('Invalid command change');
    final json = Map<String, dynamic>.from(raw);
    return switch (json['type']) {
      RecordChange.type => RecordChange._fromJson(json),
      SeriesChange.type => SeriesChange._fromJson(json),
      _ => throw FormatException('Unknown command change "${json['type']}"'),
    };
  }
}

final class RecordChange extends CommandChange {
  const RecordChange({
    required this.key,
    required this.before,
    required this.after,
  });

  static const type = 'record';

  final OccurrenceKey key;

  /// Stored JSON of each changed aspect before and after the command.
  final Map<RecordAspect, Object?> before;
  final Map<RecordAspect, Object?> after;

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'key': key.toJson(),
    'before': _encodeAspects(before),
    'after': _encodeAspects(after),
  };

  factory RecordChange._fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    if (key is! Map) throw const FormatException('RecordChange: no key');
    return RecordChange(
      key: OccurrenceKey.fromJson(Map<String, dynamic>.from(key)),
      before: _decodeAspects(json['before']),
      after: _decodeAspects(json['after']),
    );
  }
}

final class SeriesChange extends CommandChange {
  const SeriesChange({
    required this.seriesId,
    required this.before,
    required this.afterVersion,
  });

  static const type = 'series';

  final String seriesId;

  /// The series JSON before the command; null when the command created it.
  final Map<String, dynamic>? before;
  final int afterVersion;

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'seriesId': seriesId,
    'before': before,
    'afterVersion': afterVersion,
  };

  factory SeriesChange._fromJson(Map<String, dynamic> json) {
    final before = json['before'];
    if (before != null && before is! Map) {
      throw const FormatException('SeriesChange: invalid before');
    }
    return SeriesChange(
      seriesId: decodeString(json['seriesId']),
      before: before is Map ? Map<String, dynamic>.from(before) : null,
      afterVersion: decodeInt(json['afterVersion']),
    );
  }
}

class CommandLogEntry {
  const CommandLogEntry({
    required this.commandId,
    required this.appliedAt,
    required this.change,
    this.undone = false,
  });

  final String commandId;
  final DateTime appliedAt;
  final CommandChange change;
  final bool undone;

  CommandLogEntry markUndone() => CommandLogEntry(
    commandId: commandId,
    appliedAt: appliedAt,
    change: change,
    undone: true,
  );

  Map<String, dynamic> toJson() => {
    'commandId': commandId,
    'appliedAt': appliedAt.toIso8601String(),
    'change': change.toJson(),
    'undone': undone,
  };

  factory CommandLogEntry.fromJson(Map<String, dynamic> json) =>
      CommandLogEntry(
        commandId: decodeString(json['commandId']),
        appliedAt: DateTime.parse(decodeString(json['appliedAt'])),
        change: CommandChange.fromJson(json['change']),
        undone: decodeBool(json['undone']),
      );
}

Map<String, Object?> _encodeAspects(Map<RecordAspect, Object?> aspects) => {
  for (final MapEntry(:key, :value) in aspects.entries) key.name: value,
};

Map<RecordAspect, Object?> _decodeAspects(Object? raw) {
  if (raw is! Map) throw const FormatException('Invalid aspect map');
  return {
    for (final MapEntry(:key, :value) in raw.entries)
      RecordAspect.values.byName(decodeString(key)): value,
  };
}
