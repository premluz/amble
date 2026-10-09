/// A calendar date with no time and no zone.
///
/// Occurrence identity and day attribution are keyed on this rather than a
/// `DateTime`, so daylight-saving shifts and travel can never move an
/// occurrence to a different day (docs/RECURRENCE_CONTRACT.md §3, §7).
/// Arithmetic runs on UTC midnights, which have no DST.
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  factory LocalDate.fromDateTime(DateTime value) =>
      LocalDate(value.year, value.month, value.day);

  /// Parses `YYYY-MM-DD`. Throws [FormatException] for anything else,
  /// including impossible dates such as `2026-02-30`.
  factory LocalDate.parse(String value) {
    final match = _isoPattern.firstMatch(value);
    if (match == null) {
      throw FormatException('LocalDate.parse: invalid date "$value"');
    }
    final parsed = LocalDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
    if (LocalDate.fromDateTime(parsed._utc) != parsed) {
      throw FormatException('LocalDate.parse: impossible date "$value"');
    }
    return parsed;
  }

  static final _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// [DateTime.monday]..[DateTime.sunday].
  int get weekday => _utc.weekday;

  LocalDate addDays(int days) =>
      LocalDate.fromDateTime(DateTime.utc(year, month, day + days));

  /// Whole days from this date to [other] (negative when [other] is earlier).
  int daysUntil(LocalDate other) => other._utc.difference(_utc).inDays;

  LocalDate get startOfWeek => addDays(DateTime.monday - weekday);

  bool isBefore(LocalDate other) => compareTo(other) < 0;

  bool isAfter(LocalDate other) => compareTo(other) > 0;

  @override
  int compareTo(LocalDate other) => _utc.compareTo(other._utc);

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  String toString() => toIso();
}
