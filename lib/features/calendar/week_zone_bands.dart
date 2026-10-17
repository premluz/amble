import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/zone.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/week_hour_height_setting.dart';
import '../../shared/providers/zone_providers.dart';
import '../../shared/services/weekly_zone_schedule.dart';
import '../timeline/zone_background_block.dart';

/// One zone on a run of consecutive days of the week: drawn once, as a
/// single band across those days' columns, not as a band per day.
class WeekZoneRun {
  const WeekZoneRun({
    required this.zone,
    required this.first,
    required this.last,
  });

  /// The zone as it applies on [first] (the same on every day of the run).
  final Zone zone;

  /// Indexes into the week's days, inclusive.
  final int first;
  final int last;
}

/// [zones] applying on [days], merged so a zone with the same name (its
/// facet, else its title) and the same hours on consecutive days is one run.
/// A day with different hours, or a gap day, starts another run.
List<WeekZoneRun> weekZoneRuns(Iterable<Zone> zones, List<DateTime> days) {
  final byKey = <String, Zone>{};
  final daysByKey = <String, Set<int>>{};
  for (var i = 0; i < days.length; i++) {
    for (final zone in zonesForDay(zones, days[i])) {
      final key =
          '${zone.facetId ?? zone.title}|${zone.startMinutes}|'
          '${zone.endMinutes}';
      byKey.putIfAbsent(key, () => zone);
      daysByKey.putIfAbsent(key, () => {}).add(i);
    }
  }
  final runs = <WeekZoneRun>[];
  for (final MapEntry(key: key, value: indexes) in daysByKey.entries) {
    final sorted = indexes.toList()..sort();
    var first = sorted.first;
    for (var i = 1; i <= sorted.length; i++) {
      if (i == sorted.length || sorted[i] != sorted[i - 1] + 1) {
        runs.add(
          WeekZoneRun(zone: byKey[key]!, first: first, last: sorted[i - 1]),
        );
        if (i < sorted.length) first = sorted[i];
      }
    }
  }
  return runs;
}

/// The week's zones behind its tasks: the Day screen's own
/// [ZoneBackgroundBlock] and [ZoneNameLabel] (the name in the band's top-left
/// corner on desktop), one per [WeekZoneRun], spanning its day columns.
/// Respects Settings → "Show zones".
class WeekZoneBands extends ConsumerWidget {
  const WeekZoneBands({super.key, required this.days});

  final List<DateTime> days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showZonesSettingProvider)) return const SizedBox.shrink();
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final runs = weekZoneRuns(ref.watch(zoneListProvider), days);
    final hourHeight = ref.watch(weekHourHeightSettingProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth =
            (constraints.maxWidth - CalendarGridTokens.weekGutterWidth) /
            days.length;
        return Stack(
          children: [
            for (final run in runs) ..._band(theme, run, dayWidth, hourHeight),
          ],
        );
      },
    );
  }

  List<Widget> _band(
    AmbleTheme theme,
    WeekZoneRun run,
    double dayWidth,
    double hourHeight,
  ) {
    final gap = theme.spacingXs / 2;
    final x0 = CalendarGridTokens.weekGutterWidth + run.first * dayWidth + gap;
    final x1 =
        CalendarGridTokens.weekGutterWidth + (run.last + 1) * dayWidth - gap;
    final day = days[run.first];
    final rangeStart = DateTime(day.year, day.month, day.day);
    final pixelsPerMinute = hourHeight / Duration.minutesPerHour;
    // The block's left edge lands `zoneBackgroundOffset` left of `left`, and
    // it is `zoneBackgroundGap` narrower than `width`: these two undo both,
    // so it spans exactly x0..x1.
    final left = x0 + zoneBackgroundOffset;
    final width = (x1 - x0) + zoneBackgroundGap;
    return [
      ZoneBackgroundBlock(
        theme: theme,
        zone: run.zone,
        day: day,
        rangeStart: rangeStart,
        pixelsPerMinute: pixelsPerMinute,
        left: left,
        width: width,
      ),
      ZoneNameLabel(
        theme: theme,
        zone: run.zone,
        day: day,
        rangeStart: rangeStart,
        pixelsPerMinute: pixelsPerMinute,
        width: theme.spacingLg,
        insideBandLeft: left,
        insideBandWidth: width - zoneBackgroundGap - zoneBackgroundOffset,
      ),
    ];
  }
}
