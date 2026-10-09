import 'field_override.dart';
import 'occurrence_key.dart';

/// One OS reminder for one occurrence start.
class OccurrenceAlert {
  const OccurrenceAlert({
    required this.key,
    required this.title,
    required this.at,
  });

  final OccurrenceKey key;
  final String title;
  final DateTime at;

  /// Namespaced like zone alerts (`zone:` prefix) so occurrence ids never
  /// collide with task or zone ids. A fixed FNV-1a hash rather than
  /// `String.hashCode`, which Dart does not promise is stable across runs —
  /// a stored alert must map to the same OS id on every launch to be
  /// cancelled.
  int get notificationId => _fnv1a31(payload);

  /// Carries the occurrence key, not a row id, so a tap opens this exact
  /// occurrence even after it was moved (docs/RECURRENCE_CONTRACT.md S3).
  String get payload => occurrencePayload(key);

  /// Same alert as [other] — nothing to reschedule.
  bool sameAs(OccurrenceAlert other) =>
      other.key == key && other.title == title && other.at.isAtSameMomentAs(at);

  Map<String, dynamic> toJson() => {
    'key': key.toJson(),
    'title': title,
    'at': at.toUtc().toIso8601String(),
  };

  factory OccurrenceAlert.fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    if (key is! Map) throw const FormatException('OccurrenceAlert: no key');
    return OccurrenceAlert(
      key: OccurrenceKey.fromJson(Map<String, dynamic>.from(key)),
      title: decodeString(json['title']),
      at: DateTime.parse(decodeString(json['at'])),
    );
  }
}

const _payloadPrefix = 'occurrence:';
const _fnvOffsetBasis = 0x811c9dc5;
const _fnvPrime = 0x01000193;
const _mask32 = 0xffffffff;
const _mask31 = 0x7fffffff;

int _fnv1a31(String input) {
  var hash = _fnvOffsetBasis;
  for (final unit in input.codeUnits) {
    hash = ((hash ^ unit) * _fnvPrime) & _mask32;
  }
  return hash & _mask31;
}

/// The payload (and Timeline task id) form of [key]:
/// `occurrence:<series>|<date>|<ordinal>`.
String occurrencePayload(OccurrenceKey key) =>
    '$_payloadPrefix${key.storageKey}';

/// The occurrence a notification [payload] points at; null for task and
/// zone payloads.
OccurrenceKey? occurrenceKeyFromPayload(String payload) {
  if (!payload.startsWith(_payloadPrefix)) return null;
  final parts = payload.substring(_payloadPrefix.length).split('|');
  if (parts.length != 3) {
    throw FormatException('Malformed occurrence payload "$payload"');
  }
  return OccurrenceKey.fromJson({
    'seriesId': parts[0],
    'date': parts[1],
    'ordinal': int.parse(parts[2]),
  });
}
