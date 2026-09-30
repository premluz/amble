import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../../shared/models/category.dart';
import '../../shared/models/recurrence_rule.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_template.dart';
import '../../shared/providers/task_providers.dart';
import 'task_recurrence_days.dart';

export 'task_recurrence_days.dart';

/// The compact task sheet's fields — one model for create (the Timeline's
/// in-place sheet, or [showTaskSheet] from elsewhere), edit and duplicate.
/// Knows what it started as, so the sheet can ask before discarding edits,
/// and which recurrence case a save is ([wasRecurring] / [repeats]).
class TaskSheetForm extends ChangeNotifier {
  TaskSheetForm({
    required List<Task> allTasks,
    this.task,
    Task? duplicateFrom,
    this.templateId,
    DateTime? date,
    TimeOfDay? time,
    int? durationMinutes,
    String? title,
    String? categoryId,
    bool isImportant = false,
    String? behaviorId,
  }) : wasRecurring = task?.isRecurring {
    final seed = task ?? duplicateFrom;
    final seedAt = seed?.scheduledAt;
    this.title = TextEditingController(text: seed?.title ?? title ?? '');
    description = TextEditingController(text: seed?.description ?? '');
    final day = date ?? seedAt ?? DateTime.now();
    _date = DateTime(day.year, day.month, day.day);
    _time = time ?? (seedAt == null ? null : TimeOfDay.fromDateTime(seedAt));
    _durationMinutes = seed?.durationMinutes ?? durationMinutes;
    _categoryId = seed?.categoryId ?? categoryId ?? BuiltInCategoryIds.general;
    _behaviorId = seed?.behaviorId ?? behaviorId;
    _isImportant = seed?.isImportant ?? isImportant;
    _notificationsEnabled = seed?.notificationsEnabled ?? true;
    // Keyed off [task], not the seed: a duplicate is a plain task.
    _repeats = task?.isRecurring ?? false;
    final editing = task;
    _selectedDays = editing != null && editing.isRecurring
        ? daysFromRecurrenceRule(
            findSeriesTemplate(editing, allTasks).recurrenceRule!,
          )
        : {_date.weekday};
    _initial = _snapshot();
    _initialDays = {..._selectedDays};
    initialBehaviorId = _behaviorId;
    initialScheduledAt = scheduledAt;
    initialDurationMinutes = _durationMinutes;
    this.title.addListener(notifyListeners);
    description.addListener(notifyListeners);
  }

  /// The task being edited; null for a create or a duplicate.
  final Task? task;

  /// Whether [task] was part of a series when the sheet opened.
  final bool? wasRecurring;

  late final TextEditingController title;
  late final TextEditingController description;

  /// Provenance when seeded from a preset (see [Task.templateId]).
  String? templateId;

  late final String? initialBehaviorId;
  late final DateTime? initialScheduledAt;
  late final int? initialDurationMinutes;
  late final Object _initial;

  late DateTime _date;
  TimeOfDay? _time;
  int? _durationMinutes;
  late String _categoryId;
  String? _behaviorId;
  late bool _isImportant;
  late bool _notificationsEnabled;
  late bool _repeats;
  late Set<int> _selectedDays;
  bool _affectFutureInstances = false;

  DateTime get date => _date;
  TimeOfDay? get time => _time;
  int? get durationMinutes => _durationMinutes;
  String get categoryId => _categoryId;
  String? get behaviorId => _behaviorId;
  bool get isImportant => _isImportant;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get repeats => _repeats;
  Set<int> get selectedDays => _selectedDays;
  bool get affectFutureInstances => _affectFutureInstances;

  set date(DateTime value) =>
      _set(() => _date = DateTime(value.year, value.month, value.day));
  set time(TimeOfDay? value) => _set(() => _time = value);
  set durationMinutes(int? value) => _set(() => _durationMinutes = value);
  set categoryId(String value) => _set(() => _categoryId = value);
  set behaviorId(String? value) => _set(() => _behaviorId = value);
  set isImportant(bool value) => _set(() => _isImportant = value);
  set notificationsEnabled(bool value) =>
      _set(() => _notificationsEnabled = value);
  set affectFutureInstances(bool value) =>
      _set(() => _affectFutureInstances = value);

  /// Date, time and length at once — one change, not three (the Timeline
  /// draft pill moving under the sheet).
  void setSchedule(DateTime at, int minutes) => _set(() {
    _date = DateTime(at.year, at.month, at.day);
    _time = TimeOfDay.fromDateTime(at);
    _durationMinutes = minutes;
  });

  void setRepeat({required bool enabled, required Set<int> days}) => _set(() {
    _repeats = enabled;
    _selectedDays = {...days};
  });

  /// A preset fills the name and its metadata, not the schedule.
  void applyTemplate(TaskTemplate template) {
    title.text = template.title;
    _set(() {
      templateId = template.id;
      _categoryId = template.categoryId;
      _behaviorId = template.behaviorId;
      _isImportant = template.isImportant;
    });
  }

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }

  /// The chosen date at the chosen time; null while the time is unset.
  DateTime? get scheduledAt {
    final time = _time;
    if (time == null) return null;
    return DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);
  }

  bool get canSave =>
      title.text.trim().isNotEmpty &&
      scheduledAt != null &&
      _durationMinutes != null;

  RecurrenceRule get recurrenceRule => recurrenceRuleFromDays(_selectedDays);

  /// Only for a repeating task whose start or length moved: whether that
  /// change reaches the rest of the series or just this occurrence.
  bool get showFutureInstancesChoice =>
      (wasRecurring ?? false) &&
      _repeats &&
      (scheduledAt != initialScheduledAt ||
          _durationMinutes != initialDurationMinutes);

  bool get hasChanges =>
      title.text.trim().isNotEmpty &&
      (_snapshot() != _initial ||
          (_repeats &&
              (wasRecurring ?? false) &&
              !setEquals(_selectedDays, _initialDays)));

  late final Set<int> _initialDays;

  Object _snapshot() => (
    title.text,
    description.text,
    _date,
    _time,
    _durationMinutes,
    _categoryId,
    _behaviorId,
    _isImportant,
    _notificationsEnabled,
    _repeats,
  );

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }
}
