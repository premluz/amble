import 'field_override.dart';
import 'local_date.dart';

/// Where a moved occurrence now starts: a local date plus minutes after
/// midnight. Moving changes only this — never the occurrence's key.
class OccurrenceStart {
  const OccurrenceStart({required this.date, required this.minutes});

  final LocalDate date;
  final int minutes;

  Map<String, dynamic> toJson() => {'date': date.toIso(), 'minutes': minutes};

  static OccurrenceStart fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('OccurrenceStart: expected an object');
    }
    return OccurrenceStart(
      date: LocalDate.parse(decodeString(raw['date'])),
      minutes: decodeInt(raw['minutes']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OccurrenceStart &&
      other.date == date &&
      other.minutes == minutes;

  @override
  int get hashCode => Object.hash(date, minutes);
}

/// The overridable plan fields of one occurrence (contract §4). Every field
/// defaults to [Inherit]; setting a note, outcome or value never touches
/// any of these (D1).
class OccurrencePlanOverrides {
  const OccurrencePlanOverrides({
    this.start = const Inherit(),
    this.durationMinutes = const Inherit(),
    this.title = const Inherit(),
    this.description = const Inherit(),
    this.categoryId = const Inherit(),
    this.zoneId = const Inherit(),
    this.notificationsEnabled = const Inherit(),
    this.isImportant = const Inherit(),
  });

  final FieldOverride<OccurrenceStart> start;
  final FieldOverride<int> durationMinutes;
  final FieldOverride<String> title;
  final ClearableOverride<String> description;
  final ClearableOverride<String> categoryId;
  final ClearableOverride<String> zoneId;
  final FieldOverride<bool> notificationsEnabled;
  final FieldOverride<bool> isImportant;

  bool get isEmpty => !_all.any(isOverridden);

  List<ClearableOverride<Object?>> get _all => [
    start,
    durationMinutes,
    title,
    description,
    categoryId,
    zoneId,
    notificationsEnabled,
    isImportant,
  ];

  Map<String, dynamic> toJson() => {
    'start': encodeOverride(start, (value) => value.toJson()),
    'durationMinutes': encodeOverride(durationMinutes, encodeIdentity),
    'title': encodeOverride(title, encodeIdentity),
    'description': encodeOverride(description, encodeIdentity),
    'categoryId': encodeOverride(categoryId, encodeIdentity),
    'zoneId': encodeOverride(zoneId, encodeIdentity),
    'notificationsEnabled': encodeOverride(
      notificationsEnabled,
      encodeIdentity,
    ),
    'isImportant': encodeOverride(isImportant, encodeIdentity),
  };

  factory OccurrencePlanOverrides.fromJson(Map<String, dynamic> json) =>
      OccurrencePlanOverrides(
        start: decodeFieldOverride(
          json['start'],
          OccurrenceStart.fromJson,
          'start',
        ),
        durationMinutes: decodeFieldOverride(
          json['durationMinutes'],
          decodeInt,
          'durationMinutes',
        ),
        title: decodeFieldOverride(json['title'], decodeString, 'title'),
        description: decodeClearableOverride(
          json['description'],
          decodeString,
          'description',
        ),
        categoryId: decodeClearableOverride(
          json['categoryId'],
          decodeString,
          'categoryId',
        ),
        zoneId: decodeClearableOverride(json['zoneId'], decodeString, 'zoneId'),
        notificationsEnabled: decodeFieldOverride(
          json['notificationsEnabled'],
          decodeBool,
          'notificationsEnabled',
        ),
        isImportant: decodeFieldOverride(
          json['isImportant'],
          decodeBool,
          'isImportant',
        ),
      );
}
