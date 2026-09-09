import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/category.dart';
import '../../shared/models/task.dart';
import '../../shared/models/zone.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/notification_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/zone_providers.dart';
import '../../shared/services/quick_capture_parser.dart';
import '../../shared/services/zone_overlap_checker.dart';
import 'intent_task_queries.dart';

class AppIntentFailure implements Exception {
  const AppIntentFailure(this.message);
  final String message;
}

/// Runs on the app's one Dart isolate, including when it has no UI attached.
/// Uses the same repositories/notifiers as the screen; never opens Hive here.
class AppIntentService {
  AppIntentService(this.container, {DateTime Function()? now})
    : now = now ?? DateTime.now;

  final ProviderContainer container;
  final DateTime Function() now;

  Future<Object> handle(String method, Map<Object?, Object?> args) async {
    final repository = container.read(taskRepositoryProvider);
    switch (method) {
      case 'addTask':
        final input = _text(args, 'text');
        final parsed = parseQuickCapture(
          input,
          now: now(),
          categories: container
              .read(categoryRepositoryProvider)
              .getCategories(),
        );
        final notifier = container.read(taskListProvider.notifier);
        if (!parsed.isConfident) {
          await notifier.captureTask(input);
          return 'Saved "$input" as a note. No definite time was found.';
        }
        final duration =
            parsed.durationMinutes ?? quickCaptureDefaultDurationMinutes;
        if (duration <= 0) {
          throw const AppIntentFailure(
            'Please give a duration greater than zero.',
          );
        }
        final task = await notifier.createTask(
          title: parsed.title.isEmpty ? input : parsed.title,
          scheduledAt: parsed.scheduledAt!,
          durationMinutes: duration,
          categoryId: parsed.category?.id ?? BuiltInCategoryIds.general,
          recurrenceRule: parsed.recurrenceRule,
        );
        return 'Added "${task.title}" at ${intentTimeLabel(task.scheduledAt!)}.';
      case 'addNote':
        final note = Task.captured(title: _text(args, 'text'));
        // updateTask is the existing save/upsert + refresh path. Keep the
        // notifier alive if a foreground save is also in flight.
        await container.read(taskListProvider.notifier).updateTask(note);
        return 'Added note "${note.title}".';
      case 'addZone':
        return _addZone(args);
      case 'daySummary':
        return buildIntentDaySummary(repository.getTasks(), now());
      case 'findTasks':
        final candidates = intentScheduledTasks(repository.getTasks(), now());
        final query = args['query'];
        final ids = args['ids'];
        final matches = query is String
            ? matchIntentTasks(candidates, query)
            : ids is List
            ? candidates.where((t) => ids.contains(t.id)).toList()
            : candidates;
        return matches.map(intentTaskData).toList();
      case 'removeTask':
        final id = _text(args, 'id');
        // Resolve again after Siri's disambiguation; never trust a cached entity
        // or delete an item that changed while the person was choosing.
        final task = intentScheduledTasks(
          repository.getTasks(),
          now(),
        ).where((t) => t.id == id).firstOrNull;
        if (task == null ||
            task.title != args['title'] ||
            task.scheduledAt!.millisecondsSinceEpoch != args['scheduledAt']) {
          throw const AppIntentFailure(
            'That task changed or is no longer upcoming. Please ask again.',
          );
        }
        await container.read(taskListProvider.notifier).deleteTask(id);
        return 'Removed "${task.title}".';
      default:
        throw const AppIntentFailure('This Amble action is not available.');
    }
  }

  Future<String> _addZone(Map<Object?, Object?> args) async {
    final title = _text(args, 'title');
    final start = args['startMinutes'];
    final end = args['endMinutes'];
    if (start is! int ||
        end is! int ||
        start < 0 ||
        start >= 1440 ||
        end <= start ||
        end > 1440) {
      throw const AppIntentFailure(
        'Give a clear start and end time, with the end after the start on the same day.',
      );
    }
    final draft = Zone(
      id: 'intent-draft',
      title: title,
      startMinutes: start,
      endMinutes: end,
    );
    final day = now();
    // Same day-membership filter and the SAME validator as ZoneFormScreen.
    // Non-recurring create stays dateless, per ZoneList.createZone's contract.
    final others = container.read(zoneRepositoryProvider).getAll().where((z) {
      final date = z.anchorDate;
      return date == null ||
          (date.year == day.year &&
              date.month == day.month &&
              date.day == day.day);
    });
    final conflict = others.where((z) => zonesOverlap(draft, z)).firstOrNull;
    if (conflict != null) {
      throw AppIntentFailure(
        'This overlaps "${conflict.title}". Choose a different time.',
      );
    }
    final zone = await container
        .read(zoneListProvider.notifier)
        .createZone(title: title, startMinutes: start, endMinutes: end);
    // Zone notifications are scheduled by the form, not by createZone itself.
    try {
      await container.read(notificationServiceProvider).scheduleForZone(zone);
    } catch (_) {
      return 'Added zone "$title". Its notification could not be scheduled.';
    }
    return 'Added zone "$title".';
  }

  String _text(Map<Object?, Object?> args, String key) {
    final value = args[key];
    if (value is! String || value.trim().isEmpty) {
      throw const AppIntentFailure('Please give a non-empty title or text.');
    }
    return value.trim();
  }
}
