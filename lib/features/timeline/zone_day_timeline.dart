import 'package:flutter/material.dart';

import '../../core/dev_config.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_top_scroll_fade.dart';
import '../../shared/models/category.dart';
import '../../shared/models/external_calendar_event.dart';
import '../../shared/models/task.dart';
import '../../shared/models/zone.dart';
import '../../shared/services/zone_containment.dart';
import 'duration_label.dart';
import 'external_event_block.dart' show showExternalCalendarEventInfo;
import 'external_event_capsule_block.dart' show DashedPillRail;
import 'task_capsule_block.dart';
import 'zone_container_block.dart';

typedef ZoneTaskCallback = void Function(Task task);

/// **Made non-spatial — requested directly: "current zone view make non
/// spatial.. just list of zones one by one with 4px gap"**, reversing the
/// earlier time-axis design entirely. No `rangeStart`/`pixelsPerMinute`
/// math, no `Positioned`/`Stack` geometry, no drag-to-move/resize and no
/// drag-and-drop task reassignment — confirmed directly that dropping
/// those interactions is correct now that there's no time axis to drag
/// along; editing a zone's own fields happens through
/// `showZoneFormScreen` instead (via [onZoneHeaderTap]), the same tap-to-
/// edit precedent `ZoneListBody` already uses for Settings' plain Zones
/// list.
///
/// Renders a single vertical list, one item per row, `theme.spacingXs`
/// (4px) apart:
/// - each [Zone] as its own [ZoneContainerBlock] (title/time header, its
///   member tasks and matched external events stacked inside — unchanged
///   visual, just no longer positioned on a time axis),
/// - each unzoned [Task] as an ordinary flat [TaskCapsuleBlock] row
///   (`compactText: true`, fixed badge size, matching List view's own
///   individual-row look),
/// - each unmatched [ExternalCalendarEvent] as a small read-only row,
/// all merged into ONE chronological sequence by start time — confirmed
/// directly: "zones listed with header time exactly as they are now, but
/// as list... they should act as container for tasks inside those zones
/// as they are now also" / "keep them [unzoned tasks/events] in — outside
/// zones could be in between."
class ZoneDayTimeline extends StatelessWidget {
  const ZoneDayTimeline({
    super.key,
    required this.tasks,
    required this.zones,
    this.externalEvents = const [],
    required this.theme,
    required this.categoryById,
    required this.selectedDate,
    this.devTextLayout = TimelineTaskTextLayout.stacked,
    this.showCompletionCheckbox = true,
    this.devIconsVisible = true,
    this.devDurationVisible = true,
    this.devTimeRangeVisible = true,
    this.devZoneCardFlat = false,
    this.devHideEmptyZones = false,
    this.devZoneTaskStartTimeVisible = false,
    required this.onTaskTap,
    required this.onToggleComplete,
    this.onZoneHeaderTap,
  });

  final List<Task> tasks;
  final List<Zone> zones;

  /// Read-only events fetched from whichever device calendars the user
  /// selected to display (Settings' Calendar section, Feature 1) — see
  /// CONSTITUTION.md's "Calendar" section. An event whose time falls
  /// inside a zone renders inside that zone's own container (via
  /// [ZoneContainment.externalEvents]); every other event gets its own
  /// flat row, interleaved chronologically with everything else.
  final List<ExternalCalendarEvent> externalEvents;

  final AmbleTheme theme;
  final Map<String, Category> categoryById;
  final DateTime selectedDate;

  /// Dev-only capsule display toggles (Settings' "Developer" section) —
  /// applied to this view's unzoned-task rows so they match List view's
  /// own capsules, per the same providers. Defaults match the providers'
  /// own defaults, so a caller that doesn't wire them up (a dev scaffold,
  /// a test) still renders the current shipped look.
  final TimelineTaskTextLayout devTextLayout;
  final bool devIconsVisible;
  final bool devDurationVisible;

  /// The "Show time (from-to)" dev toggle
  /// (`DevTimelineTaskTimeRangeVisibleProvider`) — requested directly:
  /// "Hide/show start end should also affect zone view." Threaded to every
  /// row this view renders: each zone's own [ZoneContainerBlock] (header
  /// and in-container rows), unzoned tasks' [TaskCapsuleBlock]s, and
  /// unmatched events' [_UnzonedEventRow]s. Independent of
  /// [devDurationVisible] — either, both, or neither can be on.
  final bool devTimeRangeVisible;

  /// The `DevZoneCardFlat` dev toggle — strips each [ZoneContainerBlock]'s
  /// own background fill/border and padding, leaving just the bare
  /// title/duration header above its row list. See that provider's own
  /// doc comment for the full request.
  final bool devZoneCardFlat;

  /// The `DevHideEmptyZones` dev toggle — drops every zone container with
  /// no member task and no matched external event from the merged row
  /// list. See that provider's own doc comment for the full request.
  final bool devHideEmptyZones;

  /// The `DevZoneTaskStartTimeVisible` dev toggle — each zone's OWN member
  /// task rows show just their start time, overriding
  /// [devTimeRangeVisible] for those rows only. See that provider's own
  /// doc comment for the full request and its scope (zone member rows
  /// only — the zone header and unzoned rows are unaffected).
  final bool devZoneTaskStartTimeVisible;

  /// Whether a task's trailing completion checkbox renders
  /// (`ShowCompletionCheckboxSetting`) — a real user setting, not a dev
  /// toggle, applied to every row in this view, so one toggle covers all
  /// three views.
  final bool showCompletionCheckbox;

  final ZoneTaskCallback onTaskTap;
  final ZoneTaskCallback onToggleComplete;

  /// Taps a zone's own header — opens `showZoneFormScreen` for that zone
  /// (the caller, `TimelineScreen`, owns the navigation import; this
  /// widget only fires the callback, same "callback, not direct
  /// navigation" contract every other Timeline view uses). Null renders a
  /// non-interactive header, same as [ZoneContainerBlock.onHeaderTap]'s
  /// own "null means not tappable" contract.
  final ValueChanged<Zone>? onZoneHeaderTap;

  /// One merged, chronological sequence of every row this view renders:
  /// a [ZoneContainment] for each zone (positioned by
  /// [Zone.startMinutes]), a bare [Task] for each unzoned task (by
  /// [Task.scheduledAt], sorting after every scheduled row when unset —
  /// matches [ZoneContainerBlock]'s own in-container convention), or a
  /// bare [ExternalCalendarEvent] for each unmatched event (by
  /// [ExternalCalendarEvent.start]).
  List<Object> _mergedRows(ZoneContainmentResult result, DateTime day) {
    final containedExternalEventIds = {
      for (final containment in result.containments)
        for (final event in containment.externalEvents) event.id,
    };
    final outerExternalEvents = externalEvents
        .where((event) => !containedExternalEventIds.contains(event.id))
        .toList();

    DateTime keyFor(Object row) => switch (row) {
      ZoneContainment(:final zone) => day.add(
        Duration(minutes: zone.startMinutes),
      ),
      Task(:final scheduledAt?) => scheduledAt,
      ExternalCalendarEvent(:final start) => start,
      // An unscheduled zone-only task — sorts after every real time,
      // matching ZoneContainerBlock's own in-container convention for
      // the same case.
      _ => DateTime(9999),
    };

    // `devHideEmptyZones` (`DevHideEmptyZones`) — an opt-in OVERRIDE of
    // `ZoneContainmentResult.containments`' own documented default
    // (every zone renders regardless of member count); see that
    // provider's own doc comment. Applied here, not in
    // `resolveZoneContainment` itself, so the underlying containment
    // logic's real default is untouched.
    final containments = devHideEmptyZones
        ? result.containments
              .where((c) => c.tasks.isNotEmpty || c.externalEvents.isNotEmpty)
              .toList()
        : result.containments;

    final rows = <Object>[
      ...containments,
      ...result.unzonedTasks,
      ...outerExternalEvents,
    ]..sort((a, b) => keyFor(a).compareTo(keyFor(b)));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final day = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final result = resolveZoneContainment(
      tasks: tasks,
      zones: zones,
      day: selectedDate,
      externalEvents: externalEvents,
    );
    final rows = _mergedRows(result, day);

    // One-shot fade-in on first build — ZoneDayTimeline mounts fresh every
    // time the view-cycle button lands on Zone view, so there's no prior
    // frame to ease from; an abrupt swap otherwise reads as a rendering
    // glitch rather than a real content change (unchanged reasoning from
    // this view's earlier spatial version).
    return Stack(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: theme.motionNormal,
          curve: Curves.easeOut,
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity, child: child),
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacingScreenPadding,
              vertical: theme.spacingLg,
            ),
            itemCount: rows.length,
            // A larger gap in flat style specifically — requested directly:
            // "add gap between zones zone view (flat style)." With the
            // zone's own card background/border gone (see `flatStyle` on
            // `ZoneContainerBlock`), the original 4px separator reads as too
            // tight with nothing left to visually separate one zone from the
            // next; normal style keeps the original 4px, since its own card
            // edges already do that job.
            separatorBuilder: (_, _) => SizedBox(
              height: devZoneCardFlat ? theme.spacingMd : theme.spacingXs,
            ),
            itemBuilder: (context, index) {
              final row = rows[index];
              return switch (row) {
                ZoneContainment() => ZoneContainerBlock(
                  theme: theme,
                  zone: row.zone,
                  tasks: row.tasks,
                  externalEvents: row.externalEvents,
                  categoriesById: categoryById,
                  // Drag-and-drop is gone in the non-spatial list — every row
                  // this container renders is read-only aside from tap, so
                  // this key is never actually consulted (only reached from
                  // `onRowDragStart`, which is never wired below).
                  stackAncestorKey: _unusedStackKey,
                  onTaskTap: onTaskTap,
                  onToggleComplete: onToggleComplete,
                  durationVisible: devDurationVisible,
                  timeRangeVisible: devTimeRangeVisible,
                  startTimeOnlyVisible: devZoneTaskStartTimeVisible,
                  showCompletionCheckbox: showCompletionCheckbox,
                  flatStyle: devZoneCardFlat,
                  onHeaderTap: onZoneHeaderTap == null
                      ? null
                      : () => onZoneHeaderTap!(row.zone),
                ),
                // Left-padded by `spacingMd` — requested directly: "align
                // tasks that are not in zones same with tasks that have
                // zones, so add margin that is equal zone left padding."
                // A ZONED task's own badge sits at `spacingScreenPadding`
                // (this list's own horizontal inset) PLUS `spacingMd`
                // (ZoneContainerBlock's own card padding — see its
                // `EdgeInsets.fromLTRB` there), so an unzoned row needs the
                // exact same extra inset to line its badge up under the
                // same left edge rather than sitting `spacingMd` further
                // left than every zoned task beside it.
                Task() => Padding(
                  padding: EdgeInsets.only(left: theme.spacingMd),
                  child: TaskCapsuleBlock(
                    task: row,
                    category: row.categoryId == null
                        ? null
                        : categoryById[row.categoryId],
                    // Fixed badge size, matching List view's own individual-row
                    // look — a flat list has no time axis for a proportional
                    // pill height to read against.
                    durationIndicatedBySize: false,
                    compactText: true,
                    textLayout: devTextLayout,
                    iconsVisible: devIconsVisible,
                    durationVisible: devDurationVisible,
                    timeRangeVisible: devTimeRangeVisible,
                    showCompletionCheckbox: showCompletionCheckbox,
                    onTap: () => onTaskTap(row),
                    onToggleComplete: () => onToggleComplete(row),
                  ),
                ),
                // Same left-inset fix as the unzoned Task row above — an
                // unmatched external event is the other kind of row that
                // sits outside any zone container.
                ExternalCalendarEvent() => Padding(
                  padding: EdgeInsets.only(left: theme.spacingMd),
                  child: _UnzonedEventRow(
                    theme: theme,
                    event: row,
                    durationVisible: devDurationVisible,
                    timeRangeVisible: devTimeRangeVisible,
                  ),
                ),
                _ => const SizedBox.shrink(),
              };
            },
          ),
        ),
        // Fades the list's own top row out under `AppCalendarHeader`
        // instead of a hard cut — reported directly against the same
        // reference screenshot the header itself came from: "hard edge
        // here... should be gradient that fades under it." Mirrors
        // `_DayTimeline`'s own identical top fade (the spatial/Task-view
        // side of this same screen already had one; this view had none
        // at all).
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AppTopScrollFade(color: theme.colorSurfaceTimeline),
        ),
      ],
    );
  }
}

/// Never actually read (see [ZoneDayTimeline.build]'s own comment on
/// [ZoneContainerBlock.stackAncestorKey]) — kept only because that
/// parameter is required, not optional, on the still-drag-capable
/// [ZoneContainerBlock] this widget shares with nothing else that needs
/// dragging removed too.
final _unusedStackKey = GlobalKey();

/// A flat row for one unmatched [ExternalCalendarEvent] — same shape as
/// [ZoneContainerBlock]'s own in-container `_ZoneExternalEventRow` (time
/// then title, read-only, muted secondary color throughout so it never
/// reads as an editable Amble object), rendered as its own top-level row
/// rather than nested inside a zone since this event matched no zone's
/// window.
class _UnzonedEventRow extends StatelessWidget {
  const _UnzonedEventRow({
    required this.theme,
    required this.event,
    this.durationVisible = true,
    this.timeRangeVisible = true,
  });

  final AmbleTheme theme;
  final ExternalCalendarEvent event;
  final bool durationVisible;

  /// See [ZoneDayTimeline.devTimeRangeVisible]. Independent of
  /// [durationVisible] — requested directly: "Hide/show start end should
  /// also affect zone view."
  final bool timeRangeVisible;

  @override
  Widget build(BuildContext context) {
    final startTime = TimeOfDay.fromDateTime(event.start);
    final endTime = TimeOfDay.fromDateTime(event.end);
    final durationMinutes = event.end.difference(event.start).inMinutes;
    final timeRange = timeRangeVisible
        ? '${startTime.format(context)} - ${endTime.format(context)}'
        : null;
    final durationLabel = durationVisible
        ? '(${formatDurationLabel(durationMinutes)})'
        : null;
    final timeLabel = [?timeRange, ?durationLabel].join(' ');

    return SizedBox(
      height: zoneContainerRowHeight,
      child: GestureDetector(
        onTap: () => showExternalCalendarEventInfo(
          context: context,
          theme: theme,
          event: event,
        ),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            // Collapsed ENTIRELY when there's no time text — the column
            // and its trailing gap both, mirroring `_ZoneTaskRow`'s and
            // `_ZoneExternalEventRow`'s own guards. Without it the empty
            // `Text` collapsed to zero width but the gap SURVIVED, and
            // measured: this row's title sat at 64.0 against every other
            // row kind's 72.0 — the same 8px `spacingSm` leak reported
            // in-zone as "imported from other calendar (indent)."
            if (timeLabel.isNotEmpty) ...[
              Flexible(
                flex: 2,
                child: Text(
                  timeLabel,
                  style: theme.textTaskTitle.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: theme.spacingSm),
            ],
            // The same dashed calendar badge an IN-ZONE imported row
            // already shows (`_ZoneExternalEventRow`) — reported directly:
            // "standup is imported task but doesn't show icon with dotted
            // circle.. like those imported in zones." An unzoned imported
            // event is the same kind of object as a zoned one, so it reads
            // the same way.
            DashedPillRail(
              theme: theme,
              width: theme.sizeTaskBadge,
              height: theme.sizeTaskBadge,
            ),
            SizedBox(width: theme.spacingSm),
            Expanded(
              flex: 3,
              child: Text(
                event.title,
                style: theme.textTaskTitle.copyWith(
                  color: theme.colorTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
