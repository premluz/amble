import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dev_config.dart';
import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/external_calendar_event.dart';
import '../../shared/models/scheduled_block.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/week_hour_height_setting.dart';
import '../../shared/providers/week_task_style_setting.dart';
import '../timeline/pending_task_draft_provider.dart';
import '../timeline/task_capsule_block.dart' show TaskCapsuleTextRow;
import '../timeline/task_move_overlap.dart';
import '../timeline/task_resize_overlap.dart';
import '../timeline/tasks_on_day.dart';
import 'events_on_day.dart';
import 'week_create_layer.dart';
import 'week_day_layout.dart';
import 'week_drag.dart';
import 'week_item_gestures.dart';
import 'week_items.dart';

/// One day of the week grid: its timed tasks, device-calendar [events] and
/// the new-task draft, placed by time, side by side where they overlap.
/// Tasks and the draft move (also to another of [days]) and resize as on
/// the Day screen; events are read-only. Empty space draws a new task.
/// Zones are drawn once per run of days by `WeekZoneBands`, not per column.
class WeekDayColumn extends ConsumerWidget {
  const WeekDayColumn({
    super.key,
    required this.day,
    this.days = const [],
    this.events = const [],
  });

  final DateTime day;

  /// The visible week, for moves across day columns.
  final List<DateTime> days;
  final List<ExternalCalendarEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(pendingTaskDraftProvider);
    final items = <ScheduledBlock>[
      ..._timed(ref.watch(tasksOnDayProvider(day))),
      ...eventsOnDay(events, day),
      if (draft != null && _sameDay(draft.scheduledAt, day)) draft,
    ]..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    final drag = ref.watch(weekDragProvider);
    final hourHeight = ref.watch(weekHourHeightSettingProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = WeekDayLayout(
          theme: Theme.of(context).extension<AmbleTheme>()!,
          day: day,
          hourHeight: hourHeight,
          width: constraints.maxWidth,
          items: items,
        );
        return Stack(
          children: [
            Positioned.fill(child: WeekCreateLayer(day: day)),
            ..._items(context, ref, layout, items, drag),
          ],
        );
      },
    );
  }

  List<Widget> _items(
    BuildContext context,
    WidgetRef ref,
    WeekDayLayout layout,
    List<ScheduledBlock> items,
    WeekDrag? drag,
  ) {
    final widgets = _widgets(ref, layout.theme, null);
    final preview = drag != null && drag.isOn(day)
        ? _widgets(ref, layout.theme, drag)
        : null;
    WeekItemBuilder movable(WeekItemBuilder draw, {bool resizable = true}) =>
        (item, height) => item is ExternalCalendarEvent
        ? draw(item, height)
        : WeekItemGestures(
            item: item,
            days: days,
            dayWidth: layout.width,
            height: resizable ? height : 0,
            ghost: drag?.item.id == item.id,
            onDrop: (drag, anchor) => _drop(context, ref, drag, anchor),
            child: draw(item, height),
          );
    if (ref.watch(weekTaskStyleSettingProvider) == WeekTaskStyle.blocks) {
      return [
        ...layout.blocks(items, movable(widgets.block)),
        if (preview != null) layout.blockPreview(drag!, preview.block),
      ];
    }
    return [
      ...layout.pills(
        items,
        textRowHeight: widgets.textRowHeight,
        pill: movable(widgets.pill),
        text: movable(widgets.text, resizable: false),
      ),
      if (preview != null)
        ...layout.pillPreview(drag!, pill: preview.pill, text: preview.text),
    ];
  }

  static WeekItemWidgets _widgets(
    WidgetRef ref,
    AmbleTheme theme,
    WeekDrag? preview,
  ) {
    final timeUnderTitle = ref.watch(devTimelineTaskTimeRangeVisibleProvider);
    return WeekItemWidgets(
      timeUnderTitle: timeUnderTitle,
      // The greyed start-end line makes each text row taller, so stacked
      // rows must clear it too.
      textRowHeight:
          CalendarGridTokens.weekTextRowHeight +
          (timeUnderTitle ? TaskCapsuleTextRow.timeUnderTitleExtent(theme) : 0),
      preview: preview,
    );
  }

  /// Lands a drag: a task moves or resizes with the Day screen's rules
  /// (overlap choice, undo); the draft just takes its new span.
  Future<void> _drop(
    BuildContext context,
    WidgetRef ref,
    WeekDrag drag,
    Offset anchor,
  ) async {
    // Outlives this column if the week changes during the overlap menu.
    final container = ProviderScope.containerOf(context, listen: false);
    void end() {
      final drags = container.read(weekDragProvider.notifier);
      if (identical(container.read(weekDragProvider), drag)) drags.end();
    }

    final item = drag.item;
    if (item is PendingTaskDraft) {
      ref.read(pendingTaskDraftProvider.notifier)
        ..updatePosition(drag.start)
        ..updateDuration(drag.durationMinutes);
    } else if (item is Task && drag.mode == WeekDragMode.move) {
      await commitTaskMove(
        context,
        ref,
        task: item,
        newStart: drag.start,
        dayTasks: _timedTasks(ref, drag.start),
        anchor: anchor,
      );
    } else if (item is Task) {
      await commitTaskResize(
        context,
        ref,
        task: item,
        newStart: drag.start,
        newDuration: drag.durationMinutes,
        anchor: anchor,
        onApplied: end,
        dayTasks: _timedTasks(ref, drag.start),
      );
    }
    end();
  }

  /// The tasks that sit on the hour grid.
  static List<Task> _timed(List<Task> tasks) => tasks
      .where((t) => t.scheduledAt != null && t.durationMinutes != null)
      .toList();

  /// The timed tasks on [moment]'s day, now.
  static List<Task> _timedTasks(WidgetRef ref, DateTime moment) => _timed(
    ref.read(
      tasksOnDayProvider(DateTime(moment.year, moment.month, moment.day)),
    ),
  );

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
