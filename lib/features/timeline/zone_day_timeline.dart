import '../../core/widgets/what_matters_motion.dart';
import 'package:flutter/material.dart';

import '../../core/dev_config.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_top_scroll_fade.dart';
import 'add_task_note_sheet.dart';
import '../../shared/models/category.dart';
import '../../shared/models/tag_color_style.dart';
import '../../shared/models/external_calendar_event.dart';
import '../../shared/models/task.dart';
import '../../shared/models/zone.dart';
import '../../shared/services/zone_containment.dart';
import 'external_event_block.dart' show showExternalCalendarEventInfo;
import 'external_event_capsule_block.dart' show DashedPillRail;
import 'task_capsule_block.dart';
import 'day_view_reveal.dart';
import 'zone_container_block.dart'
    show
        WhatMattersRow,
        ZoneContainerBlock,
        ZoneRowTimeLabel,
        zoneContainerRowHeight,
        zoneContentLeftInset,
        zoneRowTimeLabelReservedWidth,
        zoneTaskTimeLabel;

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
    this.tagColorStyle = TagColorStyle.pill,
    this.whatMattersEnabled = false,
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

  /// Whether a tag's color fills the whole pill/badge or just the small
  /// badge behind its icon — a real user setting, applied to every row in
  /// this view exactly like [showCompletionCheckbox] above. See
  /// `TagColorStyleSetting`'s own doc comment.
  final TagColorStyle tagColorStyle;

  /// The "What Matters" lens — a real user setting, not a dev toggle.
  /// Threaded to every row this view renders: each zone's own
  /// [ZoneContainerBlock] (member task rows) and unzoned tasks'
  /// [TaskCapsuleBlock]s. Zone view's own half of the lens fades AND
  /// collapses a non-important row (reported directly: "as the fade out
  /// they make room for others to shift up"), unlike the Spatial view's
  /// fade-only treatment — see `ZoneContainerBlock`/`_ZoneTaskRow`'s own
  /// doc comments for that animation.
  final bool whatMattersEnabled;

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
    //
    // What Matters keeps these containers mounted so rows can release before
    // their zones collapse. Only the explicit developer filter removes rows.
    final hideEmptyZones = devHideEmptyZones;
    final containments = hideEmptyZones
        ? result.containments.where((c) {
            final visibleTasks = c.tasks;
            return visibleTasks.isNotEmpty || c.externalEvents.isNotEmpty;
          }).toList()
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

    return DayViewReveal(child: Stack(
      children: [
        ListView.separated(
          // LEFT is [zoneContentLeftInset] — column 2's own start under
          // the three-column contract (`AmbleTheme.timelineZoneLeft`),
          // the same x the spatial view's own zone band starts at.
          //
          // RIGHT is [AmbleTheme.spacingTimelineGutter] explicitly, not
          // [AmbleTheme.spacingScreenPadding] — they resolve to the same
          // primitive today, but this edge IS one of the Timeline's own
          // four equal gaps (content-to-edge), so it reads from the
          // Timeline's own token rather than agreeing with it by
          // coincidence. See `TimelineColumns`' own doc comment for why
          // that distinction is the whole point of this rebuild.
          //
          // The [ZoneRowTimeLabel]s inside these rows still escape back
          // out to [zoneRowTimeLabelEdgeInset] (== `spacingTimelineGutter`,
          // see that widget's own doc comment), so the two views line up
          // on the hour label AND the zone edge.
          padding: EdgeInsets.only(
            left: zoneContentLeftInset(theme, context),
            right: theme.spacingTimelineGutter,
            top: theme.spacingLg,
            bottom: theme.spacingLg,
          ),
          itemCount: rows.length,
          // A larger gap in flat style specifically — requested directly:
          // "add gap between zones zone view (flat style)." With the
          // zone's own card background/border gone (see `flatStyle` on
          // `ZoneContainerBlock`), the original 4px separator reads as too
          // tight with nothing left to visually separate one zone from the
          // next; normal style keeps the original 4px, since its own card
          // edges already do that job.
          separatorBuilder: (_, index) => WhatMattersMotion(
            hidden: whatMattersEnabled && _recedes(rows[index]),
            collapse: true,
            move: false,
            child: SizedBox(
              height: devZoneCardFlat ? theme.spacingMd : theme.spacingXs,
            ),
          ),
          itemBuilder: (context, index) {
            final row = rows[index];
            // **2026-09-22 — no per-row entrance stagger any more.**
            // Requested directly: "remove animation completely for
            // switching views... change screens no animation." This
            // used to wrap each row in `AppStaggeredEntrance` (a
            // staggered fade-in on top of the list's own whole-view
            // fade-in below, added specifically to make the Task<->Zone
            // view switch feel alive) — confirmed via AskUserQuestion
            // that removing "no animation" for view switches also
            // covers this per-item reveal, not just the whole-view
            // crossfade.
            return switch (row) {
              ZoneContainment() => WhatMattersMotion(
                key: ValueKey(row.zone.id),
                hidden: whatMattersEnabled && !row.tasks.any((task) => task.isImportant),
                collapse: true,
                move: false,
                child: ZoneContainerBlock(
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
                // Swipe-right — requested directly ("wire for zoned"),
                // matching this view's own unzoned rows below exactly
                // (same `showAddTaskNoteSheet` call, same "always
                // active, no Edit Mode concept here" reasoning).
                onAddNote: (task) => showAddTaskNoteSheet(context, task),
                durationVisible: devDurationVisible,
                timeRangeVisible: devTimeRangeVisible,
                startTimeOnlyVisible: devZoneTaskStartTimeVisible,
                showCompletionCheckbox: showCompletionCheckbox,
                flatStyle: devZoneCardFlat,
                whatMattersEnabled: whatMattersEnabled,
                onHeaderTap: onZoneHeaderTap == null
                    ? null
                    : () => onZoneHeaderTap!(row.zone),
              )),
              // **Mirrors [ZoneContainerBlock]'s own card LEFT padding**
              // (`spacingLg`), so an unzoned row's badge lines up with a
              // zoned one's. A zoned task sits inside that card and so
              // picks the inset up from it; an unzoned row has no card of
              // its own and has to add the same value here, or the two
              // kinds start at different x — the reported misalignment
              // this row's own tests pin.
              //
              // A leading time column, matching `_ZoneTaskRow`'s own
              // exact one (same [zoneTaskTimeLabel] format/toggles,
              // width, and style) — reported directly: an unzoned row's
              // title otherwise sat further LEFT than a zoned row's own
              // title, since `TaskCapsuleBlock`'s `compactText` mode
              // shows time INLINE within the title text rather than as a
              // separate leading column the way `_ZoneTaskRow` does.
              // `TaskCapsuleBlock` itself gets `timeRangeVisible:
              // durationVisible: false` here so its own inline text
              // carries the bare title only, not a second copy of the
              // time.
              Task() => WhatMattersRow(
                theme: theme,
                hidden: whatMattersEnabled && !row.isImportant,
                child: Padding(
                  padding: EdgeInsets.only(left: theme.spacingLg),
                  // IntrinsicHeight, not a fixed height — TaskCapsuleBlock
                  // sizes itself naturally here (badgeSize floor, or the
                  // 48px completion-checkbox tap target when that's
                  // taller — see its own `textHeaderHeight` doc comment),
                  // and the leading time column beside it only needs to
                  // stretch to match, not impose its own fixed row height.
                  // Keyed here, not on the outer Padding — a Padding
                  // widget's own top-left is its PARENT's edge (before
                  // the padding is applied), which is the wrong thing to
                  // measure against for "how far right does this row's
                  // own content start."
                  child: IntrinsicHeight(
                    key: ValueKey('unzoned-task-row-${row.id}'),
                    child: Builder(
                      builder: (context) {
                        final timeLabel = zoneTaskTimeLabel(
                          context,
                          scheduledAt: row.scheduledAt,
                          durationMinutes: row.durationMinutes,
                          timeRangeVisible: devTimeRangeVisible,
                          durationVisible: devDurationVisible,
                          startTimeOnlyVisible: devZoneTaskStartTimeVisible,
                        );
                        return Row(
                          // `start`, not `stretch` — see the time
                          // label's own comment just below for why.
                          // `TaskCapsuleBlock` still gets its full
                          // natural height inside its own `Expanded`
                          // regardless of this row's cross-axis
                          // alignment; only the LABEL needed to stop
                          // stretching.
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Escapes back to the spatial Task view's own
                            // hour-label position via [ZoneRowTimeLabel] —
                            // see that widget's own class doc comment
                            // (`zone_container_block.dart`) for the full
                            // "why not just reuse TaskBoundaryMarkers
                            // directly" reasoning, and
                            // docs/DESIGN_SYSTEM.md's "Zone row hour
                            // label" section. Replaces an earlier
                            // `Transform.translate` coordinate hack.
                            //
                            // Same [leftPaddingToEscape] total as
                            // `_ZoneTaskRow`'s own copy of this widget
                            // ([zoneContentLeftInset] list inset +
                            // `spacingMd`) — this row reaches it via its
                            // OWN `Padding(left: spacingMd)` wrapper above
                            // rather than a zone card's padding, but the
                            // total is identical, which is exactly what
                            // keeps unzoned and zoned times lined up with
                            // each other.
                            // **2026-09-20** — no trailing `SizedBox` gap
                            // any more. With
                            // [zoneRowTimeLabelReservedWidth] at 0 the
                            // label occupies no row width at all (its
                            // text escapes via `Positioned`), so an 8px
                            // spacer after it was pure offset — and it
                            // pushed this unzoned row's title 8px right
                            // of a zoned row's, breaking exactly the
                            // shared x-origin this file's own alignment
                            // test pins. `_ZoneTaskRow` dropped its
                            // matching spacer for the same reason.
                            // **2026-09-20 — vertical misalignment fix.**
                            // Reported directly against a screenshot: an
                            // unzoned row's time text sat visibly off
                            // the badge's own vertical center. Root
                            // cause: with the enclosing `Row` previously
                            // `stretch`ed (to give `TaskCapsuleBlock`
                            // its full natural height, up to the
                            // completion checkbox's 48px tap target),
                            // this zero-width label was ALSO stretched
                            // to that same full height and centered
                            // within it — but the badge inside
                            // `TaskCapsuleBlock` is `topCenter`-anchored
                            // at [theme.sizeTaskBadge] from the row's
                            // TOP (see that widget's own hardened
                            // `textHeaderHeight` comment on exactly this
                            // "centers within the wrong box" failure
                            // mode, previously fixed for the title
                            // text but never applied here). Pinning
                            // this label to a `sizeTaskBadge`-tall box
                            // at the row's own top gives it the
                            // identical vertical anchor the badge
                            // itself uses, regardless of how tall the
                            // row grows around it.
                            if (timeLabel.isNotEmpty)
                              SizedBox(
                                height: theme.sizeTaskBadge,
                                child: ZoneRowTimeLabel(
                                  theme: theme,
                                  text: timeLabel,
                                  leftPaddingToEscape:
                                      zoneContentLeftInset(theme, context) +
                                      theme.spacingLg,
                                  reservedWidth: zoneRowTimeLabelReservedWidth,
                                ),
                              ),
                            Expanded(
                              child: TaskCapsuleBlock(
                                task: row,
                                category: row.categoryId == null
                                    ? null
                                    : categoryById[row.categoryId],
                                // Fixed badge size, matching List view's own
                                // individual-row look — a flat list has no
                                // time axis for a proportional pill height to
                                // read against.
                                durationIndicatedBySize: false,
                                compactText: true,
                                textLayout: devTextLayout,
                                iconsVisible: devIconsVisible,
                                // Both false: this row's own leading time
                                // column above already shows time/duration —
                                // see this branch's own doc comment.
                                durationVisible: false,
                                timeRangeVisible: false,
                                showCompletionCheckbox: showCompletionCheckbox,
                                tagColorStyle: tagColorStyle,
                                onTap: () => onTaskTap(row),
                                onToggleComplete: () => onToggleComplete(row),
                                // Swipe-right — requested directly ("slide
                                // right add note"). This view has no Edit Mode
                                // concept at all (TaskCapsuleBlock's own
                                // editModeEnabled defaults to false here, never
                                // passed), so the swipe is always active,
                                // matching "on timeline spatial and non
                                // spatial only (not on edit)".
                                onAddNote: () =>
                                    showAddTaskNoteSheet(context, row),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Same left-inset fix as the unzoned Task row above — an
              // unmatched external event is the other kind of row that
              // sits outside any zone container.
              ExternalCalendarEvent() => WhatMattersMotion(
                key: ValueKey(row.id),
                hidden: whatMattersEnabled,
                collapse: true,
                child: Padding(
                padding: EdgeInsets.only(left: theme.spacingLg),
                child: _UnzonedEventRow(
                  theme: theme,
                  event: row,
                  durationVisible: devDurationVisible,
                  timeRangeVisible: devTimeRangeVisible,
                  startTimeOnlyVisible: devZoneTaskStartTimeVisible,
                ),
              )),
              _ => const SizedBox.shrink(),
            };
          },
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
    ));
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
    this.startTimeOnlyVisible = false,
  });

  final AmbleTheme theme;
  final ExternalCalendarEvent event;
  final bool durationVisible;

  /// See [ZoneDayTimeline.devTimeRangeVisible]. Independent of
  /// [durationVisible] — requested directly: "Hide/show start end should
  /// also affect zone view."
  final bool timeRangeVisible;

  /// See [ZoneDayTimeline.devZoneTaskStartTimeVisible]. **2026-09-20 —
  /// now also reaches this row**, not just zoned/unzoned task rows —
  /// see `_ZoneExternalEventRow`'s own matching doc comment for why.
  final bool startTimeOnlyVisible;

  @override
  Widget build(BuildContext context) {
    final durationMinutes = event.end.difference(event.start).inMinutes;
    // Reuses the same helper the task rows already compute their own
    // time label with — see `_ZoneExternalEventRow`'s own matching
    // comment.
    final timeLabel = zoneTaskTimeLabel(
      context,
      scheduledAt: event.start,
      durationMinutes: durationMinutes,
      timeRangeVisible: timeRangeVisible,
      durationVisible: durationVisible,
      startTimeOnlyVisible: startTimeOnlyVisible,
    );

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
            // **2026-09-20 — now uses [ZoneRowTimeLabel], same as the
            // unzoned TASK row above and `_ZoneTaskRow`.** Reported
            // directly: an imported event's time never got the same
            // left-pulled treatment native tasks' own time labels do —
            // this row rendered its time as ordinary in-flow text
            // instead of escaping back to [zoneRowTimeLabelEdgeInset],
            // so it visibly sat further right than a task row's time
            // beside it. `leftPaddingToEscape` is the identical value
            // the unzoned task row above uses (this row sits inside the
            // same `Padding(left: spacingMd)` wrapper), and the
            // `SizedBox(height: theme.sizeTaskBadge)` wrapper matches
            // that same fix's own vertical-alignment half.
            if (timeLabel.isNotEmpty)
              SizedBox(
                height: theme.sizeTaskBadge,
                child: ZoneRowTimeLabel(
                  theme: theme,
                  text: timeLabel,
                  leftPaddingToEscape:
                      zoneContentLeftInset(theme, context) + theme.spacingLg,
                  reservedWidth: zoneRowTimeLabelReservedWidth,
                ),
              ),
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

// Use task identity/importance rather than labels to classify occupied zones.
bool _recedes(Object row) => switch (row) {
  ZoneContainment() => !row.tasks.any((task) => task.isImportant),
  Task() => !row.isImportant,
  ExternalCalendarEvent() => true,
  _ => false,
};
