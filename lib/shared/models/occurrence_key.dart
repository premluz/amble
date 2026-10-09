import 'local_date.dart';

/// Stable identity of one occurrence of a series:
/// series id + original local date + same-day ordinal.
///
/// Start time is deliberately NOT part of the key, so changing a series from
/// 07:00 to 08:00 keeps every occurrence's identity — and its note,
/// cancellation or completion — attached (docs/RECURRENCE_CONTRACT.md §3).
/// Moving an occurrence to another day never changes its key either.
class OccurrenceKey {
  const OccurrenceKey({
    required this.seriesId,
    required this.date,
    this.ordinal = firstOrdinal,
  });

  /// Amble's own series produce at most one occurrence per day. Higher
  /// ordinals exist only for imported series with several same-day
  /// occurrences, numbered by original start order.
  static const firstOrdinal = 1;

  static const _separator = '|';

  final String seriesId;
  final LocalDate date;
  final int ordinal;

  /// The storage key form, `seriesId|YYYY-MM-DD|ordinal`.
  String get storageKey =>
      '$seriesId$_separator${date.toIso()}$_separator$ordinal';

  Map<String, dynamic> toJson() => {
    'seriesId': seriesId,
    'date': date.toIso(),
    'ordinal': ordinal,
  };

  factory OccurrenceKey.fromJson(Map<String, dynamic> json) {
    final seriesId = json['seriesId'];
    final date = json['date'];
    final ordinal = json['ordinal'];
    if (seriesId is! String ||
        seriesId.isEmpty ||
        date is! String ||
        ordinal is! int ||
        ordinal < firstOrdinal) {
      throw const FormatException('OccurrenceKey.fromJson: invalid key');
    }
    return OccurrenceKey(
      seriesId: seriesId,
      date: LocalDate.parse(date),
      ordinal: ordinal,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OccurrenceKey &&
      other.seriesId == seriesId &&
      other.date == date &&
      other.ordinal == ordinal;

  @override
  int get hashCode => Object.hash(seriesId, date, ordinal);

  @override
  String toString() => storageKey;
}
