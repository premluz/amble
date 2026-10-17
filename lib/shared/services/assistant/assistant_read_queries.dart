import '../../models/category.dart';
import '../../models/scheduled_block.dart';
import '../../models/task.dart';
import '../../models/task_status.dart';
import '../availability.dart';
import 'assistant_args.dart';
import 'assistant_backend.dart';
import 'assistant_json.dart';
import 'assistant_tool.dart';

/// The read tools' handlers, one method per tool.
class AssistantReads {
  AssistantReads(this.backend);

  final AssistantBackend backend;

  Map<String, Category> get _categories => {
    for (final c in backend.categories()) c.id: c,
  };

  List<Task> _tasks(DateTime from, DateTime to) =>
      [for (final day in daysIn(from, to)) ...backend.tasksOn(day)]
        ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

  Future<List<ScheduledBlock>> _busy(DateTime from, DateTime to) async => [
    for (final task in _tasks(from, to))
      if (task.status != TaskStatus.skipped) task,
    ...await backend.eventsBetween(from, to),
  ];

  Future<AssistantToolResult> getDay(AssistantArgs args) async {
    final day = args.requireDate('date');
    final end = DateTime(day.year, day.month, day.day + 1);
    final tasks = _tasks(day, end);
    final events = await backend.eventsBetween(day, end);
    final free = computeFreeWindows(
      busy: await _busy(day, end),
      zonesOn: backend.zonesOn,
      from: day,
      to: end,
      dayStartMinutes: AssistantLimits.defaultDayStartMinutes,
      dayEndMinutes: AssistantLimits.defaultDayEndMinutes,
      minMinutes: AssistantLimits.dayFreeMinMinutes,
    );
    final categories = _categories;
    return AssistantToolResult(
      summary:
          '${tasks.length} tasks, ${events.length} events on '
          '${localDate(day)}.',
      data: {
        'date': localDate(day),
        'tasks': [for (final t in tasks) taskJson(t, categories)],
        'calendar_events': [for (final e in events) eventJson(e)],
        'zones': [for (final z in backend.zonesOn(day)) zoneJson(z, day)],
        'free': [for (final w in free) windowJson(w)],
      },
    );
  }

  Future<AssistantToolResult> listTasks(AssistantArgs args) async {
    final (from, to) = args.requireRange();
    final importantOnly = args.boolOr('important_only', false);
    final categories = _categories;
    final tasks = [
      for (final t in _tasks(from, to))
        if (!importantOnly || t.isImportant) taskJson(t, categories),
    ];
    return AssistantToolResult(
      summary: '${tasks.length} tasks.',
      data: {'tasks': tasks},
    );
  }

  Future<AssistantToolResult> availability(AssistantArgs args) async {
    final (from, to) = args.requireRange();
    final startHour = args.intOr(
      'day_start_hour',
      AssistantLimits.defaultDayStartMinutes ~/ Duration.minutesPerHour,
      min: 0,
      max: Duration.hoursPerDay - 1,
    );
    final endHour = args.intOr(
      'day_end_hour',
      AssistantLimits.defaultDayEndMinutes ~/ Duration.minutesPerHour,
      min: 1,
      max: Duration.hoursPerDay,
    );
    if (endHour <= startHour) {
      throw const AssistantToolError(
        '"day_end_hour" must be after "day_start_hour".',
      );
    }
    final now = backend.now();
    final windows = computeFreeWindows(
      busy: await _busy(from, to),
      zonesOn: backend.zonesOn,
      from: from.isBefore(now) ? now : from,
      to: to,
      dayStartMinutes: startHour * Duration.minutesPerHour,
      dayEndMinutes: endHour * Duration.minutesPerHour,
      minMinutes: args.intOr(
        'min_minutes',
        AssistantLimits.defaultSlotMinutes,
        min: AssistantLimits.minTaskMinutes,
        max: AssistantLimits.maxTaskMinutes,
      ),
      zoneName: args.optionalString('zone_name'),
    );
    final total = windows.fold<int>(0, (sum, w) => sum + w.minutes);
    return AssistantToolResult(
      summary: '${windows.length} free windows, $total minutes in all.',
      data: {
        'free': [for (final w in windows) windowJson(w)],
      },
    );
  }

  Future<AssistantToolResult> listZones(AssistantArgs args) async {
    final (from, to) = args.requireRange();
    final zones = [
      for (final day in daysIn(from, to))
        for (final zone in backend.zonesOn(day)) zoneJson(zone, day),
    ];
    return AssistantToolResult(
      summary: '${zones.length} zone blocks.',
      data: {'zones': zones},
    );
  }

  Future<AssistantToolResult> listCategories(AssistantArgs args) async {
    final names = [for (final c in backend.categories()) c.name];
    return AssistantToolResult(
      summary: '${names.length} categories.',
      data: {'categories': names},
    );
  }
}
