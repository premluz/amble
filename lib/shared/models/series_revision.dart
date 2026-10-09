import 'field_override.dart';
import 'local_date.dart';
import 'recurrence_rule.dart';

/// Minutes in one day — the exclusive upper bound for a start time.
const minutesPerDay = 24 * 60;

/// The default plan fields of a series, as one revision defines them.
class SeriesDefaults {
  const SeriesDefaults({
    required this.title,
    this.description,
    this.categoryId,
    this.zoneId,
    this.behaviorId,
    this.notificationsEnabled = true,
    this.isImportant = false,
  });

  final String title;
  final String? description;
  final String? categoryId;
  final String? zoneId;
  final String? behaviorId;
  final bool notificationsEnabled;
  final bool isImportant;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'categoryId': categoryId,
    'zoneId': zoneId,
    'behaviorId': behaviorId,
    'notificationsEnabled': notificationsEnabled,
    'isImportant': isImportant,
  };

  factory SeriesDefaults.fromJson(Map<String, dynamic> json) {
    final title = decodeString(json['title']);
    if (title.trim().isEmpty) {
      throw const FormatException('SeriesDefaults: empty title');
    }
    return SeriesDefaults(
      title: title,
      description: _optionalString(json['description']),
      categoryId: _optionalString(json['categoryId']),
      zoneId: _optionalString(json['zoneId']),
      behaviorId: _optionalString(json['behaviorId']),
      notificationsEnabled: decodeBool(json['notificationsEnabled']),
      isImportant: decodeBool(json['isImportant']),
    );
  }
}

/// A series' rule and defaults as they apply from [effectiveFrom] until the
/// next revision. Past dates always resolve against the revision that
/// applied on that date (D4a).
class SeriesRevision {
  SeriesRevision({
    required this.effectiveFrom,
    required this.rule,
    required this.startMinutes,
    required this.durationMinutes,
    required this.defaults,
  }) {
    if (startMinutes < 0 || startMinutes >= minutesPerDay) {
      throw ArgumentError.value(startMinutes, 'startMinutes');
    }
    if (durationMinutes <= 0) {
      throw ArgumentError.value(durationMinutes, 'durationMinutes');
    }
  }

  final LocalDate effectiveFrom;
  final RecurrenceRule rule;

  /// Local wall-clock start, minutes after midnight (floating — D2).
  final int startMinutes;

  /// Elapsed minutes, so a task across a clock change keeps its length.
  final int durationMinutes;

  final SeriesDefaults defaults;

  Map<String, dynamic> toJson() => {
    'effectiveFrom': effectiveFrom.toIso(),
    'rule': rule.toJson(),
    'startMinutes': startMinutes,
    'durationMinutes': durationMinutes,
    'defaults': defaults.toJson(),
  };

  factory SeriesRevision.fromJson(Map<String, dynamic> json) {
    final rule = json['rule'];
    final defaults = json['defaults'];
    if (rule is! Map || defaults is! Map) {
      throw const FormatException('SeriesRevision: missing rule or defaults');
    }
    try {
      return SeriesRevision(
        effectiveFrom: LocalDate.parse(decodeString(json['effectiveFrom'])),
        rule: RecurrenceRule.fromJson(Map<String, dynamic>.from(rule)),
        startMinutes: decodeInt(json['startMinutes']),
        durationMinutes: decodeInt(json['durationMinutes']),
        defaults: SeriesDefaults.fromJson(Map<String, dynamic>.from(defaults)),
      );
    } on ArgumentError catch (error) {
      throw FormatException('SeriesRevision: ${error.message}');
    }
  }
}

String? _optionalString(Object? value) =>
    value == null ? null : decodeString(value);
