import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/task.dart';
import '../../shared/models/zone.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/zone_providers.dart';
import '../../shared/services/overlap_cluster.dart';
import '../../shared/services/weekly_zone_schedule.dart';
import '../timeline/tasks_on_day.dart';
import '../timeline/zone_background_block.dart' show zoneBackgroundGap;
import 'week_task_block.dart';

/// One day of the week grid: that day's zones as quiet bands, and its
/// timed tasks placed by time, side by side where they overlap.
class WeekDayColumn extends ConsumerWidget {
  const WeekDayColumn({super.key, required this.day});

  final DateTime day;

  static double _y(int minutes) =>
      minutes * CalendarGridTokens.weekHourHeight / Duration.minutesPerHour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final zones = ref.watch(showZonesSettingProvider)
        ? zonesForDay(ref.watch(zoneListProvider), day)
        : const <Zone>[];
    final tasks = ref
        .watch(tasksOnDayProvider(day))
        .where((t) => t.scheduledAt != null && t.durationMinutes != null)
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          for (final zone in zones) _zone(theme, zone),
          ..._tasks(theme, tasks, constraints.maxWidth),
        ],
      ),
    );
  }

  Widget _zone(AmbleTheme theme, Zone zone) => Positioned(
    top: _y(zone.startMinutes),
    height: math.max(
      0,
      _y(zone.endMinutes - zone.startMinutes) - zoneBackgroundGap,
    ),
    left: theme.spacingXs / 2,
    right: theme.spacingXs / 2,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorZoneBackground,
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacingXs),
        child: Text(
          zone.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textZoneName.copyWith(color: theme.colorTextTertiary),
        ),
      ),
    ),
  );

  /// Pills sit side by side at pill width where tasks overlap, as on the
  /// Day screen; every task's text sits after the widest group of pills, at
  /// its own time, pushed down only if an earlier row would cover it.
  List<Widget> _tasks(AmbleTheme theme, List<Task> tasks, double width) {
    final lanes = <String, int>{};
    var laneCount = 1;
    for (final cluster in detectOverlapClusters(tasks)) {
      final assigned = clusterLanes(cluster);
      laneCount = math.max(laneCount, assigned.reduce(math.max) + 1);
      for (var i = 0; i < cluster.blocks.length; i++) {
        lanes[(cluster.blocks[i] as Task).id] = assigned[i];
      }
    }
    final pitch = theme.sizeTaskBadge + theme.spacingSm;
    final textLeft = theme.spacingXs / 2 + laneCount * pitch;
    var textFloor = 0.0;
    final widgets = <Widget>[];
    for (final task in tasks) {
      final start = task.scheduledAt!;
      final y = _y(start.hour * Duration.minutesPerHour + start.minute);
      widgets.add(
        Positioned(
          top: y,
          left: theme.spacingXs / 2 + (lanes[task.id] ?? 0) * pitch,
          child: WeekTaskPill(task: task),
        ),
      );
      final textTop = math.max(y, textFloor);
      textFloor = textTop + CalendarGridTokens.weekTextRowHeight;
      widgets.add(
        Positioned(
          top: textTop,
          left: textLeft,
          width: math.max(0, width - textLeft),
          child: WeekTaskText(task: task),
        ),
      );
    }
    return widgets;
  }
}
