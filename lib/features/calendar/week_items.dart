import 'package:flutter/widgets.dart';

import '../../shared/models/external_calendar_event.dart';
import '../../shared/models/scheduled_block.dart';
import '../../shared/models/task.dart';
import '../timeline/pending_task_draft_provider.dart';
import 'week_draft_block.dart';
import 'week_drag.dart';
import 'week_event_block.dart';
import 'week_task_block.dart';
import 'week_task_card.dart';

/// The widgets a week item is drawn with, by kind: a task, a device
/// calendar event, or the new-task draft. Given a [preview], its start and
/// length are shown instead of the item's own (the drag's landing spot).
class WeekItemWidgets {
  const WeekItemWidgets({
    required this.timeUnderTitle,
    required this.textRowHeight,
    this.preview,
  });

  final bool timeUnderTitle;
  final double textRowHeight;
  final WeekDrag? preview;

  DateTime _start(ScheduledBlock item) => preview?.start ?? item.scheduledStart;

  int _minutes(ScheduledBlock item) =>
      preview?.durationMinutes ??
      item.scheduledEnd.difference(item.scheduledStart).inMinutes;

  /// Blocks style.
  Widget block(ScheduledBlock item, double height) => switch (item) {
    final Task task => WeekTaskCard(
      task: task,
      previewStart: preview?.start,
      previewMinutes: preview?.durationMinutes,
    ),
    final ExternalCalendarEvent event => WeekEventCard(event: event),
    PendingTaskDraft() => WeekDraftCard(
      start: _start(item),
      minutes: _minutes(item),
    ),
    _ => const SizedBox.shrink(),
  };

  /// Pills style: the pill.
  Widget pill(ScheduledBlock item, double height) => switch (item) {
    final Task task => WeekTaskPill(
      task: task,
      previewStart: preview?.start,
      previewMinutes: preview?.durationMinutes,
    ),
    final ExternalCalendarEvent event => WeekEventPill(
      event: event,
      height: height,
    ),
    PendingTaskDraft() => WeekDraftPill(height: height),
    _ => const SizedBox.shrink(),
  };

  /// Pills style: the text beside the pill.
  Widget text(ScheduledBlock item, double height) => switch (item) {
    final Task task => WeekTaskText(
      task: task,
      timeUnderTitleVisible: timeUnderTitle,
      previewStart: preview?.start,
    ),
    final ExternalCalendarEvent event => WeekEventText(event: event),
    PendingTaskDraft() => SizedBox(
      height: textRowHeight,
      child: WeekDraftText(start: _start(item), minutes: _minutes(item)),
    ),
    _ => const SizedBox.shrink(),
  };
}
