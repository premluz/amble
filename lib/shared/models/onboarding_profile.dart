/// A curated, bundle-level onboarding preset — "a whole starting point,"
/// not an individually-tagged item. Read-only content shipped in the app
/// bundle (`assets/onboarding/profiles.json`), never itself persisted:
/// choosing one materializes its bundle into real, independent Hive rows
/// via the existing `Zone`/`TaskTemplate`/`Task`/`TrackedBehavior` create
/// paths (see `onboarding_materializer.dart`), the same "materialize on
/// choice, not seed on launch" reasoning already established for
/// individual presets.
///
/// Deliberately NOT a `@HiveType` — this whole file is plain, JSON-shaped
/// Dart data, parsed fresh from the bundled asset every time it's needed
/// (see `onboarding_profile_catalog.dart`), never written to Hive itself.
library;

/// One `HH:mm` time-of-day string parsed into minutes since midnight — the
/// same representation `Zone.startMinutes`/`endMinutes` already use (see
/// that model's own doc comment on why: no Hive adapter for `TimeOfDay`,
/// and this codebase already treats "hours * 60 + minutes" as the
/// boundary representation for time of day).
int parseTimeOfDayMinutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) {
    throw FormatException('Expected "HH:mm", got "$value"');
  }
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw FormatException('Time out of range: "$value"');
  }
  return hour * 60 + minute;
}

/// A weekday-recurring time window to materialize via `ZoneList
/// .paintWeeklyZones` — [weekdays] uses the same 1 (Monday) - 7 (Sunday)
/// convention `Zone.weekday` already does, not Dart's `DateTime.weekday`
/// coincidentally matching it (it does, but this is not relying on that
/// being an accident).
class OnboardingZoneEntry {
  const OnboardingZoneEntry({
    required this.title,
    required this.weekdays,
    required this.startMinutes,
    required this.endMinutes,
  });

  factory OnboardingZoneEntry.fromJson(Map<String, dynamic> json) {
    final weekdaysJson = json['weekdays'];
    if (weekdaysJson is! List || weekdaysJson.isEmpty) {
      throw const FormatException(
        'OnboardingZoneEntry: missing or empty "weekdays"',
      );
    }
    final title = json['title'];
    final startTime = json['startTime'];
    final endTime = json['endTime'];
    if (title is! String || title.isEmpty) {
      throw const FormatException('OnboardingZoneEntry: missing "title"');
    }
    if (startTime is! String || endTime is! String) {
      throw const FormatException(
        'OnboardingZoneEntry: missing "startTime"/"endTime"',
      );
    }
    return OnboardingZoneEntry(
      title: title,
      weekdays: weekdaysJson.map((d) => d as int).toSet(),
      startMinutes: parseTimeOfDayMinutes(startTime),
      endMinutes: parseTimeOfDayMinutes(endTime),
    );
  }

  final String title;
  final Set<int> weekdays;
  final int startMinutes;
  final int endMinutes;
}

/// A `TaskTemplate`-shaped entry — [categoryName] is one of the 5
/// built-in `Category` names (`general`/`health`/`work`/`personal`/
/// `admin`), resolved to that install's actual (seeded, UUID) category id
/// at materialization time — never a hardcoded UUID, since built-in ids
/// are stable but a raw string in this asset would be fragile to depend
/// on directly, and self-documents which built-in each entry means.
class OnboardingTemplateEntry {
  const OnboardingTemplateEntry({
    required this.title,
    required this.categoryName,
    this.durationMinutes,
    this.notes,
  });

  factory OnboardingTemplateEntry.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final categoryName = json['categoryName'];
    if (title is! String || title.isEmpty) {
      throw const FormatException('OnboardingTemplateEntry: missing "title"');
    }
    if (categoryName is! String || categoryName.isEmpty) {
      throw const FormatException(
        'OnboardingTemplateEntry: missing "categoryName"',
      );
    }
    return OnboardingTemplateEntry(
      title: title,
      categoryName: categoryName,
      durationMinutes: json['durationMinutes'] as int?,
      notes: json['notes'] as String?,
    );
  }

  final String title;
  final String categoryName;
  final int? durationMinutes;
  final String? notes;
}

/// A ready-to-schedule `Task`-shaped entry for the user's first day.
class OnboardingTaskEntry {
  const OnboardingTaskEntry({
    required this.title,
    required this.categoryName,
    required this.startMinutes,
    required this.durationMinutes,
  });

  factory OnboardingTaskEntry.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final categoryName = json['categoryName'];
    final time = json['time'];
    final durationMinutes = json['durationMinutes'];
    if (title is! String || title.isEmpty) {
      throw const FormatException('OnboardingTaskEntry: missing "title"');
    }
    if (categoryName is! String || categoryName.isEmpty) {
      throw const FormatException(
        'OnboardingTaskEntry: missing "categoryName"',
      );
    }
    if (time is! String) {
      throw const FormatException('OnboardingTaskEntry: missing "time"');
    }
    if (durationMinutes is! int) {
      throw const FormatException(
        'OnboardingTaskEntry: missing "durationMinutes"',
      );
    }
    return OnboardingTaskEntry(
      title: title,
      categoryName: categoryName,
      startMinutes: parseTimeOfDayMinutes(time),
      durationMinutes: durationMinutes,
    );
  }

  final String title;
  final String categoryName;
  final int startMinutes;
  final int durationMinutes;
}

/// A `TrackedBehavior`-shaped entry. [targetType] is the string name of a
/// `BehaviorTargetType` enum value (`duration`/`count`/`binary`/
/// `distance`/`custom`) — parsed at materialization time, not stored as
/// the enum itself, since this whole file stays plain-Dart/JSON-shaped
/// with no dependency on Hive-adapted types.
class OnboardingTrackedBehaviorEntry {
  const OnboardingTrackedBehaviorEntry({
    required this.title,
    required this.targetType,
    required this.timesPerWeek,
    this.targetAmount,
    this.customUnitLabel,
  });

  factory OnboardingTrackedBehaviorEntry.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final targetType = json['targetType'];
    final timesPerWeek = json['timesPerWeek'];
    if (title is! String || title.isEmpty) {
      throw const FormatException(
        'OnboardingTrackedBehaviorEntry: missing "title"',
      );
    }
    if (targetType is! String || targetType.isEmpty) {
      throw const FormatException(
        'OnboardingTrackedBehaviorEntry: missing "targetType"',
      );
    }
    if (timesPerWeek is! int) {
      throw const FormatException(
        'OnboardingTrackedBehaviorEntry: missing "timesPerWeek"',
      );
    }
    return OnboardingTrackedBehaviorEntry(
      title: title,
      targetType: targetType,
      timesPerWeek: timesPerWeek,
      targetAmount: (json['targetAmount'] as num?)?.toDouble(),
      customUnitLabel: json['customUnitLabel'] as String?,
    );
  }

  final String title;
  final String targetType;
  final int timesPerWeek;
  final num? targetAmount;
  final String? customUnitLabel;
}

/// One curated bundle — see this file's own top-level doc comment.
class OnboardingProfile {
  const OnboardingProfile({
    required this.id,
    required this.title,
    required this.description,
    required this.quizTags,
    required this.zones,
    required this.templates,
    required this.tasks,
    required this.trackedBehaviors,
    required this.notes,
  });

  factory OnboardingProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final description = json['description'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('OnboardingProfile: missing "id"');
    }
    if (title is! String || title.isEmpty) {
      throw const FormatException('OnboardingProfile: missing "title"');
    }
    if (description is! String) {
      throw const FormatException('OnboardingProfile: missing "description"');
    }
    return OnboardingProfile(
      id: id,
      title: title,
      description: description,
      quizTags: (json['quizTags'] as List? ?? const [])
          .map((t) => t as String)
          .toSet(),
      zones: (json['zones'] as List? ?? const [])
          .map((z) => OnboardingZoneEntry.fromJson(z as Map<String, dynamic>))
          .toList(),
      templates: (json['templates'] as List? ?? const [])
          .map(
            (t) => OnboardingTemplateEntry.fromJson(t as Map<String, dynamic>),
          )
          .toList(),
      tasks: (json['tasks'] as List? ?? const [])
          .map((t) => OnboardingTaskEntry.fromJson(t as Map<String, dynamic>))
          .toList(),
      trackedBehaviors: (json['trackedBehaviors'] as List? ?? const [])
          .map(
            (t) => OnboardingTrackedBehaviorEntry.fromJson(
              t as Map<String, dynamic>,
            ),
          )
          .toList(),
      notes: (json['notes'] as List? ?? const [])
          .map((n) => n as String)
          .toList(),
    );
  }

  final String id;
  final String title;
  final String description;

  /// Free-form scoring tags this profile matches against — see
  /// `onboarding_quiz.dart`'s own doc comment for how the quiz's answers
  /// are scored against these.
  final Set<String> quizTags;

  final List<OnboardingZoneEntry> zones;
  final List<OnboardingTemplateEntry> templates;
  final List<OnboardingTaskEntry> tasks;
  final List<OnboardingTrackedBehaviorEntry> trackedBehaviors;

  /// Plain titles for `Task.captured`-shaped Inbox notes.
  final List<String> notes;
}
