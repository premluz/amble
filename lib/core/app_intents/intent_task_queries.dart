import '../../shared/models/task.dart';

/// Today and the following 13 calendar days; excludes Inbox and old history.
const intentTaskWindowDays = 14;

List<Task> intentScheduledTasks(List<Task> tasks, DateTime now) {
  final start = DateTime(now.year, now.month, now.day);
  final end = DateTime(now.year, now.month, now.day + intentTaskWindowDays);
  return tasks.where((task) {
    final at = task.scheduledAt;
    return task.isScheduled &&
        at != null &&
        !at.isBefore(start) &&
        at.isBefore(end);
  }).toList()..sort((a, b) {
    final order = a.scheduledAt!.compareTo(b.scheduledAt!);
    return order == 0 ? a.id.compareTo(b.id) : order;
  });
}

/// No edit-distance library or second NLP parser. Exact titles take priority;
/// otherwise accept a substring or all spoken tokens, in any order.
List<Task> matchIntentTasks(List<Task> candidates, String spokenTitle) {
  final query = spokenTitle.trim().toLowerCase();
  if (query.isEmpty) return [];
  final exact = candidates
      .where((t) => t.title.trim().toLowerCase() == query)
      .toList();
  if (exact.isNotEmpty) return exact;
  Set<String> tokens(String text) => RegExp(
    r'[\p{L}\p{N}]+',
    unicode: true,
  ).allMatches(text).map((m) => m.group(0)!).toSet();
  final words = tokens(query);
  return candidates.where((task) {
    final title = task.title.toLowerCase();
    return title.contains(query) ||
        (words.isNotEmpty && tokens(title).containsAll(words));
  }).toList();
}

String intentTimeLabel(DateTime at) {
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final minute = at.minute == 0
      ? ''
      : ':${at.minute.toString().padLeft(2, '0')}';
  return '$hour$minute${at.hour < 12 ? 'am' : 'pm'}';
}

String buildIntentDaySummary(List<Task> tasks, DateTime now) {
  final today = intentScheduledTasks(tasks, now).where((task) {
    final at = task.scheduledAt!;
    return at.year == now.year && at.month == now.month && at.day == now.day;
  }).toList();
  if (today.isEmpty) return 'No tasks scheduled today.';
  final count = '${today.length} ${today.length == 1 ? 'task' : 'tasks'} today';
  final next = today
      .where((task) => !task.scheduledAt!.isBefore(now))
      .firstOrNull;
  final task = next ?? today.first;
  final label = next == null ? 'starting with' : 'next is';
  return '$count, $label ${task.title} at ${intentTimeLabel(task.scheduledAt!)}.';
}

Map<String, Object> intentTaskData(Task task) => {
  'id': task.id,
  'title': task.title,
  'scheduledAt': task.scheduledAt!.millisecondsSinceEpoch,
};
