import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_context_dock.dart';
import '../../core/widgets/app_shell_chrome.dart';
import '../../core/widgets/app_floating_create_button.dart';
import '../../core/widgets/app_layout_reveal.dart';
import '../../core/widgets/app_view_transition.dart';
import '../../core/widgets/app_option_switch_option.dart';
import '../../core/widgets/app_tab_switch.dart';
import '../../core/widgets/app_top_scroll_fade.dart';
import '../../core/widgets/app_undo_toast.dart';
import '../../core/widgets/selected_pill_border.dart';
import '../../core/widgets/resize_handle_dot.dart';
import '../../shared/models/task.dart';
import '../../shared/models/zone.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/zone_providers.dart';
import '../../shared/services/move_resize_undo.dart';
import '../../shared/services/zone_cascade_reschedule.dart';
import '../../shared/services/zone_group_move.dart';
import '../../shared/services/zone_selection_order.dart';
import '../task_detail/multi_task_edit_sheet.dart';
import '../task_detail/task_detail_sheet.dart';
import '../timeline/edit_mode_provider.dart';
import '../timeline/edit_selection_provider.dart';
import '../timeline/pending_task_draft_provider.dart';
import '../timeline/task_edge_time_label.dart';
import '../timeline/timeline_pinch_zoom.dart';
import '../timeline/timeline_screen.dart';
import '../timeline/zone_background_block.dart' show zoneBackgroundGap;
import '../zones/multi_zone_edit_sheet.dart';
import '../zones/zone_form_screen.dart';
import 'new_zone_sheet.dart';
import 'zone_grid_block.dart';
import 'zone_grid_tab.dart';
import 'zone_paint_selection.dart';

/// Opens the merged Edit screen — Tasks (spatial Timeline in Edit Mode)
/// and Zones (the Weekly Zone Authoring Grid) as two tabs of ONE screen,
/// replacing what used to be two separate header entry points (the pen
/// icon for task Edit Mode, a "Weekly zone grid" icon pushing this screen
/// on its own). See `ZoneGridScreen`'s own doc comment.
Future<void> showEditScreen(
  BuildContext context, {
  ZoneGridTab initialTab = ZoneGridTab.tasks,
  NavigatorState? navigator,
}) => (navigator ?? Navigator.of(context)).push<void>(
  layoutRevealRoute(
    context,
    (_) => ProviderScope(
      overrides: [
        editModeEnabledProvider.overrideWith(
          () => _RouteEditMode(initialTab == ZoneGridTab.tasks),
        ),
      ],
      child: ZoneGridScreen(initialTab: initialTab),
    ),
  ),
);

// The outgoing Day screen stays visible during the reveal; its mode must not
// change with the editor's tabs. Initializing here also avoids a second layout.
class _RouteEditMode extends EditModeEnabled {
  _RouteEditMode(this.initialValue);

  final bool initialValue;

  @override
  bool build() => initialValue;
}

/// Options for both `AppTabSwitch<ZoneGridTab>` call sites below — a
/// module-level const rather than rebuilt per build(), since neither the
/// values nor labels ever change.
const _zoneGridTabOptions = [
  AppOptionSwitchOption(value: ZoneGridTab.tasks, label: 'Tasks'),
  AppOptionSwitchOption(value: ZoneGridTab.zones, label: 'Zones'),
];

/// The hour-label column's full width, INCLUDING the 8px breathing room on
/// each side of the label text (see the label `Positioned` in `build`).
///
/// Reported directly: the gap between the screen edge and the hour labels
/// read as ~3px here versus ~16px on the Timeline, because this axis had
/// no left inset at all — labels started at `left: 0` with only a 4px
/// shave on the right. Both sides are now `theme.spacingSm` (8px).
///
/// **Sized as 8 (left inset) + text + 16 (clearance before lane 1).**
/// "00:00" is five glyphs of JetBrains Mono at `textCaption`'s 12px
/// (~7.2px advance each, ~36px total), so 8 + 36 + 16 = 60.
///
/// The right-hand clearance is 16px, not 8, per a direct follow-up: "right
/// gap smaller on zone edit and too big on task view make it 16px."
///
/// History worth keeping: a first attempt narrowed this to 40 on the
/// assumption the lanes could reclaim space — that left only 24px for the
/// text and wrapped every label onto two lines ("it squashed actually the
/// edit zone screen so hours spatial run in 2 lines now"). The lanes give
/// up width here rather than gaining any; the padding has to come from
/// somewhere.
const _axisWidth = 60.0;

/// **2026-09-17 — the merged Edit screen.** Was "the Weekly Zone
/// Authoring Grid" alone, opened from its own separate header icon
/// alongside a SECOND, separate entry point for the Timeline's own task
/// Edit Mode. Requested directly: "we have 2 inactive tabs on edit zone
/// screen. We need to make them work and switch edit zone with edit
/// tasks views with these tabs... one entry point instead of 2 in the
/// header." The "Events"/"Zones" tab chrome already existed (unwired,
/// `events` reserved for a future calendar-events grid) — `events` is
/// renamed to [ZoneGridTab.tasks] and wired to show the spatial Timeline
/// (forced into Edit Mode) as this screen's other tab, rather than
/// building new tab chrome from scratch.
///
/// The two tab bodies are the pre-existing, otherwise-unmodified
/// screens — this class does not merge their gesture/state systems, it
/// swaps which one is visible.
///
/// **2026-09-20 — top row reduced to a bare Tasks/Zones tab switch, no
/// icons.** Requested directly: "in edit mode on top we should only
/// have 2 tabs task and zones and close on the bottom tool nav... in
/// zones edit and close (close on the leftmost)." Close (both tabs) and
/// Edit (Zones tab only) moved into a floating bottom dock
/// (`AppDockPane`/`AppDockIconButton`, matching the Day screen's own
/// `AppBottomDock` visual language), Close always leftmost. The Tasks
/// tab's embedded `TimelineScreen` also went back to `showHeader: true`
/// (its own default) — a separate direct request: "Tasks edit mode
/// should also have calendar" — with
/// `calendarHeaderShowsCloseButton: false` so `AppCalendarHeader`'s own
/// Edit-Mode close (X) doesn't duplicate the new bottom-dock Close.
class ZoneGridScreen extends ConsumerStatefulWidget {
  const ZoneGridScreen({super.key, this.initialTab = ZoneGridTab.tasks});

  final ZoneGridTab initialTab;

  @override
  ConsumerState<ZoneGridScreen> createState() => _ZoneGridScreenState();
}

class _ZoneGridScreenState extends ConsumerState<ZoneGridScreen> {
  final _gridKey = GlobalKey();
  final _viewportKey = GlobalKey();
  Timer? _edgeScroll;
  Offset? _paintPointer;
  final _scroll = ScrollController();
  bool _saving = false;
  AppShellChromeController? _shellChromeController;

  /// The Zones tab is ALWAYS in edit mode — requested directly: "Edit
  /// zones screen should be in edit mode always no need to press edit to
  /// edit." Replaces a `_editing` flag the Edit/Done dock button used to
  /// toggle.
  ///
  /// This flag is not purely cosmetic: it arbitrates gestures. With it
  /// on, a plain drag on empty grid PAINTS a new zone selection and the
  /// scroll view takes `NeverScrollableScrollPhysics`, so vertical
  /// scrolling moves to the hour axis on the left (which already carried
  /// that handler for edit mode) and to pinch-zoom. Confirmed via
  /// AskUserQuestion over the alternative of long-press-to-paint.
  static const bool _editing = true;
  late ZoneGridTab _tab = widget.initialTab;
  ZonePaintSelection? _paint;
  Offset? _paintOrigin;
  // Captured in `build` (below) rather than read via `ref` inside
  // `dispose` — confirmed the hard way: `ConsumerState.ref.read` throws
  // "Using ref when a widget is about to or has been unmounted is
  // unsafe" once called from `dispose`, exactly as its own error message
  // says to do instead ("save the provider state in a field").
  ProviderContainer? _container;
  bool _pointerCancelled = false;
  NewZoneTarget? _pending;
  Zone? _fillSource;
  double _fillDx = 0;

  /// Live while a drag that STARTED on an unselected zone is sweeping
  /// zones into the selection — requested directly, twice: "when tap and
  /// drag zones let's make it multi select zones", then again after a
  /// first attempt was backed out: "on zone edit, tapping on an existing
  /// zone and sweeping does not make any selection."
  ///
  /// **Latched, deliberately** — set ONCE at drag start and read by every
  /// later event, never re-derived from `selected`. That is what sank the
  /// first attempt: the sweep selects its own origin zone immediately,
  /// which rebuilds that block with `selected: true`, and a dispatch that
  /// consulted `selected` per-event then swapped the in-flight gesture
  /// onto the move/fill handlers — so the sweep died after exactly one
  /// zone. The task-side sweep (`timeline_screen.dart`'s
  /// `_sweepingSelection`) solves it the same way, and that one works.
  bool _sweepingZones = false;

  /// The sweep marquee's own extent in grid-local coordinates — the
  /// visible affordance, matching the paint-selection preview's own
  /// rectangle (`'zone-paint-selection'`) rather than inventing a second
  /// "you are selecting right now" visual. Null whenever no sweep is in
  /// flight.
  Offset? _sweepAnchor;
  Offset? _sweepCurrent;

  ZoneGroupGestureKind? _moveKind;
  double _moveDy = 0;
  double _moveDx = 0;

  /// Which edge of the pending marquee is being dragged, if any — see
  /// [_MarqueeEdge]. Null whenever no marquee resize is in flight.
  ///
  /// Requested directly: "when we have marque selection and release sheet
  /// add zone shows but we should be able to resize zones in that view
  /// also — so we need to add resize handles (dots) same as on task but
  /// on all sides top bottom (resize zone time start end) left right
  /// resize sideways to include/reduce days."
  _MarqueeEdge? _resizeEdge;
  double? _resizeX;

  /// The pending marquee's own rectangle as it stood when a whole-marquee
  /// MOVE drag began, plus that drag's accumulated pixel delta — see
  /// [_moveMarquee]. All null/zero whenever no such drag is in flight.
  ///
  /// The origin is held separately from `_paint` because the move is
  /// applied as "origin plus total delta" rather than incrementally: a
  /// rounded per-event shift would drop sub-cell movement on every frame,
  /// so a slow drag would never accumulate enough to cross a boundary.
  ZonePaintSelection? _marqueeMoveOrigin;
  double _marqueeMoveDx = 0;
  double _marqueeMoveDy = 0;

  // Shared with the spatial Task view — ONE setting, adjustable here via
  // pinch-to-zoom (TimelinePinchZoom, wrapping the scrollable grid below)
  // — see TimelinePixelsPerMinuteSetting's own doc comment. Was a
  // hardcoded `const _pixelsPerMinute = 44.0 / 60` (≈0.733); the default
  // shared value (1.5) roughly doubles this screen's own vertical
  // density from what it was, an intended consequence of unifying the
  // two previously-independent scales into one, not a regression.
  double get _pixelsPerMinute =>
      ref.watch(timelinePixelsPerMinuteSettingProvider);
  double get _gridHeight => 1440 * _pixelsPerMinute;

  @override
  void initState() {
    super.initState();
    // `EditModeEnabled` is the Timeline's own toggle — this screen forces
    // it to match whichever tab is showing rather than requiring the
    // Timeline tab body to know it's being hosted here. `addPostFrameCallback`
    // because a provider must not be written mid-build (this runs during
    // `initState`, before the first frame) — mirrors `main.dart`'s own
    // out-of-range-index correction, same reasoning.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncEditMode());
  }

  void _syncEditMode() {
    if (!mounted) return;
    final wantsEditMode = _tab == ZoneGridTab.tasks;
    if (ref.read(editModeEnabledProvider) != wantsEditMode) {
      ref.read(editModeEnabledProvider.notifier).toggle();
    }
  }

  void _switchTab(ZoneGridTab tab) {
    setState(() => _tab = tab);
    // Same reasoning as `initState` above — this runs from an event
    // handler, not build, so no post-frame deferral is needed here.
    _syncEditMode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppShellChromeScope.maybeOf(context);
    if (controller == _shellChromeController) return;
    _shellChromeController?.release('edit');
    _shellChromeController = controller;
  }

  /// Closes this screen, turning Edit Mode off FIRST so the Day screen
  /// underneath never renders a frame with it still on.
  ///
  /// Reported directly: closing the Edit screen briefly flashed a
  /// container between the top nav and the calendar, carrying an
  /// accent-bordered circular button with no icon in it. That is
  /// `AppCalendarHeader`'s own Edit-Mode close (X) row — the Day screen
  /// sits mounted underneath this one (`main.dart`'s `IndexedStack`) and
  /// watches the same `editModeEnabledProvider`, so while the flag is
  /// still true it renders that row, and the glyph swaps a frame after
  /// the accent border paints.
  ///
  /// [dispose] also resets the flag, but only via `scheduleMicrotask` —
  /// Riverpod refuses writes during the pop's tree-finalize pass, so that
  /// reset lands one frame LATE, which is the frame being seen. Doing it
  /// here, from an ordinary event handler, means the flag is already
  /// false before the pop reveals anything. `dispose`'s own reset stays
  /// as the backstop for the paths that never touch this button (system
  /// back, the iOS swipe gesture).
  void _close() {
    if (ref.read(editModeEnabledProvider)) {
      ref.read(editModeEnabledProvider.notifier).toggle();
    }
    Navigator.of(context).pop();
  }

  Widget _taskContextDock(Set<String> selectedIds) => _claimOrBuildDock(
    ZoneGridTab.tasks,
    AppContextDockConfiguration(
      stateId: selectedIds.isEmpty ? 'edit-task' : 'edit-task-selection',
      groups: [
        AppContextGroup(
          id: 'context-navigation',
          actions: [
            AppContextAction(
              id: 'edit-back',
              icon: Icons.arrow_back_rounded,
              tooltip: selectedIds.isEmpty ? 'Close' : 'Clear selection',
              onPressed: selectedIds.isEmpty
                  ? _close
                  : () => ref.read(editSelectionProvider.notifier).clear(),
            ),
          ],
        ),
        if (selectedIds.isNotEmpty)
          AppContextGroup(
            id: 'edit-task-selection-actions',
            actions: [
              AppContextAction(
                id: 'edit-task-edit',
                icon: Icons.edit_outlined,
                tooltip: 'Edit selected',
                onPressed: () => _editSelectedTasks(selectedIds),
              ),
              AppContextAction(
                id: 'edit-task-remove',
                icon: Icons.delete_outline_rounded,
                tooltip: 'Remove selected',
                destructive: true,
                onPressed: () => _removeSelectedTasks(selectedIds),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _claimOrBuildDock(
    ZoneGridTab sourceTab,
    AppContextDockConfiguration configuration,
  ) {
    final controller = _shellChromeController;
    if (controller != null) {
      // Cached outgoing Tasks content must not overwrite the active Zones dock.
      if (sourceTab != _tab) {
        return const SizedBox.shrink();
      }
      controller.claim('edit', configuration);
      return const SizedBox.shrink();
    }
    return AppContextDock(configuration: configuration);
  }

  Widget _zoneContextDock(Set<String> selected, List<Zone> zones) =>
      _claimOrBuildDock(
        ZoneGridTab.zones,
        AppContextDockConfiguration(
          // Standalone screens also remove their local dock while naming.
          // Shell-hosted Edit additionally suppresses chrome without an exit
          // fade, so outgoing actions cannot paint above the inline sheet.
          stateId: _pending != null
              ? 'edit-zone-naming'
              : selected.isEmpty
              ? 'edit-zone'
              : 'edit-zone-selection',
          groups: _pending != null
              ? const []
              : [
                  AppContextGroup(
                    id: 'context-navigation',
                    actions: [
                      AppContextAction(
                        id: 'edit-back',
                        icon: Icons.arrow_back_rounded,
                        tooltip: selected.isEmpty
                            ? 'Close zones'
                            : 'Clear selection',
                        onPressed: selected.isEmpty
                            ? _close
                            : () => ref
                                  .read(zoneEditSelectionProvider.notifier)
                                  .clear(),
                      ),
                    ],
                  ),
                  if (selected.isNotEmpty)
                    AppContextGroup(
                      id: 'edit-zone-selection-actions',
                      actions: [
                        AppContextAction(
                          id: 'edit-zone-edit',
                          icon: Icons.edit_outlined,
                          tooltip: 'Edit placement',
                          onPressed: _editSelectedZones,
                        ),
                        AppContextAction(
                          id: 'edit-zone-remove',
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Remove placements',
                          destructive: true,
                          onPressed: _removeSelectedZones,
                        ),
                      ],
                    ),
                ],
        ),
      );

  void _editSelectedZones() {
    // Dock actions outlive selection rebuilds; resolve IDs when invoked.
    final selected = Set<String>.of(ref.read(zoneEditSelectionProvider));
    if (selected.isEmpty) return;
    if (selected.length == 1) {
      final zone = ref
          .read(zoneListProvider)
          .where((zone) => selected.contains(zone.id))
          .firstOrNull;
      if (zone != null) showZoneFormScreen(context, zone: zone);
      return;
    }
    showMultiZoneEditSheet(context, zoneIds: selected.toList());
  }

  /// The selection dock's own Edit action — a single task opens the
  /// ordinary detail sheet unchanged ([showTaskDetailSheet], the app's one
  /// edit entry point); 2+ opens the bulk [showMultiTaskEditSheet]
  /// (tag/track/duration/notification only), confirmed directly. Neither
  /// path clears the selection itself — closing either sheet leaves the
  /// user back on the same selection, in case they want to also Remove or
  /// re-edit it.
  void _editSelectedTasks(Set<String> selectedIds) {
    if (selectedIds.length == 1) {
      final task = ref.read(taskByIdProvider(selectedIds.first));
      if (task == null) return;
      showTaskDetailSheet(context, task: task);
      return;
    }
    showMultiTaskEditSheet(context, taskIds: selectedIds.toList());
  }

  /// The selection dock's own Remove action — every selected task is
  /// deleted via the plain single-instance path (`TaskList.deleteTask`),
  /// NEVER the recurring-scope dialog, confirmed directly per
  /// CONSTITUTION.md's existing group-delete rule (a per-task "this
  /// instance or the whole series?" prompt would stack once per selected
  /// recurring task). Mirrors the drag-to-delete-target group-delete path
  /// already on the spatial Timeline (`timeline_screen.dart`) exactly.
  ///
  /// **Undo** (2026-09-22) — every selected task is snapshotted (via
  /// [Task.toJson]) BEFORE the delete runs, same "snapshot then
  /// restore via a plain keyed re-save" mechanism `removeTask`'s own undo
  /// uses. One toast covers the whole batch — Undo restores every
  /// snapshotted task, not just one, matching how this is a single group
  /// action from the user's own perspective.
  ///
  /// **2026-09-22 — deletes via [TaskList.deleteTasksInBatch], not a loop
  /// of single-item [TaskList.deleteTask] calls.** Reported directly:
  /// selected tasks "disappear one by one" rather than together — each
  /// single-item delete refreshes `taskListProvider` on its own, so N
  /// selected tasks rebuilt the UI N separate times. The batch method
  /// runs the same per-row side effects but refreshes once, after every
  /// row is gone. Undo's own restore loop had the identical bug (reported
  /// in the same breath: "when they reappear also not at once") — now
  /// via [TaskList.restoreTasksInBatch] too.
  Future<void> _removeSelectedTasks(Set<String> selectedIds) async {
    final notifier = ref.read(taskListProvider.notifier);
    final snapshots = selectedIds
        .map((id) => ref.read(taskByIdProvider(id)))
        .whereType<Task>()
        .map((task) => task.toJson())
        .toList();
    await notifier.deleteTasksInBatch(selectedIds);
    ref.read(editSelectionProvider.notifier).clear();
    if (!mounted) return;
    AppUndoToast.show(
      context: context,
      message: 'Removed ${snapshots.length} task(s)',
      onUndo: () => notifier.restoreTasksInBatch(snapshots.map(Task.fromJson)),
    );
  }

  /// The Zones tab's own "Remove placements" action — plain deletes, no
  /// recurring-scope dialog (a zone occurrence has no equivalent of a
  /// task series here). Same snapshot-then-restore undo shape as
  /// [_removeSelectedTasks] above, via [Zone.toJson]/[Zone.fromJson] (the
  /// same round-trip export/import already proves correct) instead of
  /// [Task]'s. Wrapped in [_write] for its existing busy-flag/error-toast
  /// handling, matching every other mutating action on this tab.
  ///
  /// **2026-09-22 — deletes via [ZoneList.deleteZonesInBatch]**, same fix
  /// and same reasoning as [_removeSelectedTasks]'s own note above:
  /// selected zones were disappearing one at a time. Undo restores via
  /// [ZoneList.restoreZonesInBatch] for the same reason.
  Future<void> _removeSelectedZones() => _write(() async {
    // The shell retains action identity while selection changes.
    final selectedIds = Set<String>.of(ref.read(zoneEditSelectionProvider));
    final zones = ref.read(zoneListProvider);
    final zoneNotifier = ref.read(zoneListProvider.notifier);
    final snapshots = selectedIds
        .map((id) => zones.where((z) => z.id == id).firstOrNull)
        .whereType<Zone>()
        .map((z) => z.toJson())
        .toList();
    await zoneNotifier.deleteZonesInBatch(selectedIds);
    ref.read(zoneEditSelectionProvider.notifier).clear();
    if (!mounted) return;
    AppUndoToast.show(
      context: context,
      message: 'Removed ${snapshots.length} zone(s)',
      onUndo: () =>
          zoneNotifier.restoreZonesInBatch(snapshots.map(Zone.fromJson)),
    );
  });

  @override
  void dispose() {
    _edgeScroll?.cancel();
    _scroll.dispose();
    // `EditModeEnabled` is shared with the underlying nav-tab Timeline —
    // `main.dart`'s `IndexedStack` keeps that tab mounted (and watching
    // this same provider) the whole time this screen is pushed on top of
    // it, so leaving it forced `true` here would silently drop the user
    // back into Edit Mode on the ordinary Timeline the moment this screen
    // pops, regardless of which tab it was closed from. `toggle()` is the
    // only mutator this notifier exposes (no direct setter), so only
    // flip it when it's actually still on.
    //
    // Uses the captured `_container` (see its own field doc comment), not
    // `ref` — `ref.read` throws once called from `dispose`. The WRITE
    // itself is also deferred a microtask via `scheduleMicrotask`
    // (confirmed necessary, not just `ref.read`'s own read-side
    // restriction, by a failing test): Riverpod refuses to modify a
    // provider "while the widget tree was building," which a pop's
    // finalize-the-tree pass still counts as even from inside `dispose`.
    final container = _container;
    // The READ is guarded for the same reason the microtask below is: a
    // test-scoped container can already be disposed by the time this
    // screen unmounts, and `ProviderContainer` exposes no public
    // "is disposed" check, so catching its `StateError` is the only
    // sanctioned guard available to ordinary app code.
    bool editModeStillOn;
    try {
      editModeStillOn =
          container != null && container.read(editModeEnabledProvider);
    } on StateError {
      editModeStillOn = false;
    }
    if (container != null && editModeStillOn) {
      scheduleMicrotask(() {
        // The app's own root container outlives every screen, so this
        // try/catch is a no-op in production — it exists for tests, where
        // a ProviderContainer scoped to one test can legitimately be
        // disposed (tearDown) before this microtask gets a turn, e.g. a
        // test that never navigates away and so never needed this reset
        // at all. `ProviderContainer` has no PUBLIC "is this disposed"
        // check (only an `@internal`, test-only extension) — catching the
        // `StateError` it throws is the only sanctioned way to guard this
        // from ordinary app code.
        try {
          container.read(editModeEnabledProvider.notifier).toggle();
        } on StateError {
          // Container already disposed — nothing left to reset.
        }
      });
    }
    _shellChromeController?.release('edit');
    super.dispose();
  }

  RenderBox? get _grid =>
      _gridKey.currentContext?.findRenderObject() as RenderBox?;
  double get _columnWidth => ((_grid?.size.width ?? 394) - _axisWidth) / 7;
  (int, int) _cell(Offset point) => (
    ((point.dx - _axisWidth) / _columnWidth).floor().clamp(0, 6) + 1,
    (point.dy / _pixelsPerMinute / 5).round().clamp(0, 288) * 5,
  );

  void _startEdgeScroll() {
    _edgeScroll?.cancel();
    _edgeScroll = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final pointer = _paintPointer;
      final viewport = _viewportKey.currentContext?.findRenderObject();
      if (pointer == null || viewport is! RenderBox || !_scroll.hasClients) {
        return;
      }
      final y = viewport.globalToLocal(pointer).dy;
      final delta = y < 36
          ? -6.0
          : y > viewport.size.height - 36
          ? 6.0
          : 0.0;
      if (delta == 0) return;
      final next = (_scroll.offset + delta).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      if (next == _scroll.offset) return;
      _scroll.jumpTo(next);
      _updatePaint(pointer);
    });
  }

  void _startPaint(Offset global) {
    if (_saving || _pending != null) return;
    final box = _grid;
    if (box == null) return;
    final local = box.globalToLocal(global);
    if (local.dx < _axisWidth) return;
    final (day, minute) = _cell(local);
    _paintPointer = global;
    _startEdgeScroll();
    ref.read(zoneEditSelectionProvider.notifier).clear();
    setState(() {
      _paintOrigin = local;
      _paint = ZonePaintSelection.between(day, minute, day, minute);
    });
  }

  void _updatePaint(Offset global) {
    _paintPointer = global;
    final origin = _paintOrigin;
    if (origin == null || _grid == null) return;
    final (dayA, minuteA) = _cell(origin);
    final (dayB, minuteB) = _cell(_grid!.globalToLocal(global));
    setState(
      () => _paint = ZonePaintSelection.between(dayA, minuteA, dayB, minuteB),
    );
  }

  void _endPaint() {
    _edgeScroll?.cancel();
    _paintPointer = null;
    if (_pointerCancelled) {
      _cancelPaint();
      return;
    }
    final paint = _paint;
    if (paint == null) return;
    setState(() {
      _paintOrigin = null;
      _setPending(_target(paint));
    });
    _scrollPendingIntoView(paint.startMinutes);
  }

  NewZoneTarget _target(ZonePaintSelection paint) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    return NewZoneTarget(
      day: DateTime(monday.year, monday.month, monday.day + paint.firstDay - 1),
      days: paint.weekdays,
      startMinutes: paint.startMinutes,
      endMinutes: paint.endMinutes,
    );
  }

  void _cancelPaint() {
    _edgeScroll?.cancel();
    _paintPointer = null;
    setState(() {
      _paintOrigin = null;
      _paint = null;
      _setPending(null);
      _resizeEdge = null;
      _resizeX = null;
      // Cleared here too, or a marquee dismissed mid-move would leave the
      // grid's own `physics` gate stuck on NeverScrollableScrollPhysics
      // with no gesture left to clear it.
      _marqueeMoveOrigin = null;
      _marqueeMoveDx = 0;
      _marqueeMoveDy = 0;
    });
  }

  /// Drags one edge of the pending marquee. Vertical edges move the
  /// zone's start/end TIME; horizontal ones widen/narrow the span of
  /// WEEKDAYS it covers.
  ///
  /// **2026-09-23 — the dragged edge is CLAMPED against its opposite, not
  /// normalised past it.** This used to hand both edges to
  /// `ZonePaintSelection.between`, which takes a `min`/`max` of whatever
  /// pair it is given — so dragging the right edge left past the left one
  /// silently swapped which edge was which, and the marquee jumped sideways
  /// instead of resizing. Reported directly: "when dragging handle it
  /// actually moves across instead of resizing smoothly."
  ///
  /// Normalisation is right for the ORIGINAL paint drag (where both
  /// corners are genuinely live and either can end up first), but wrong
  /// for an edge drag, where the opposite edge is fixed and the dragged
  /// one must simply stop against it. Each edge therefore clamps to keep
  /// at least one day / one 5-minute step of the rectangle alive.
  void _resizeMarquee(_MarqueeEdge edge, Offset global) {
    final box = _grid;
    final paint = _paint;
    if (box == null || paint == null) return;
    final local = box.globalToLocal(global);
    final (_, minute) = _cell(local);
    final x = local.dx.clamp(
      _axisWidth +
          (edge == _MarqueeEdge.right ? paint.firstDay : 0) * _columnWidth,
      _axisWidth +
          (edge == _MarqueeEdge.left ? paint.lastDay - 1 : 7) * _columnWidth,
    );
    final day =
        (edge == _MarqueeEdge.right
                ? ((x - _axisWidth) / _columnWidth).round()
                : ((x - _axisWidth) / _columnWidth).round() + 1)
            .clamp(1, 7);
    final next = switch (edge) {
      _MarqueeEdge.top => ZonePaintSelection(
        paint.firstDay,
        paint.lastDay,
        math.min(minute, paint.endMinutes - 5),
        paint.endMinutes,
      ),
      _MarqueeEdge.bottom => ZonePaintSelection(
        paint.firstDay,
        paint.lastDay,
        paint.startMinutes,
        math.max(minute, paint.startMinutes + 5),
      ),
      _MarqueeEdge.left => ZonePaintSelection(
        math.min(day, paint.lastDay),
        paint.lastDay,
        paint.startMinutes,
        paint.endMinutes,
      ),
      _MarqueeEdge.right => ZonePaintSelection(
        paint.firstDay,
        math.max(day, paint.firstDay),
        paint.startMinutes,
        paint.endMinutes,
      ),
    };
    setState(() {
      if (edge == _MarqueeEdge.left || edge == _MarqueeEdge.right) {
        _resizeX = x;
      }
      _paint = next;
      // The naming sheet reads its target from `_pending`, so it has to
      // track the live rectangle or it would save the pre-resize one.
      if (_pending != null) _setPending(_target(next));
    });
  }

  double _previewLeft(ZonePaintSelection preview) =>
      _fillSource != null
      ? math.min(
          _axisWidth + (_fillSource!.weekday! - 1) * _columnWidth,
          _axisWidth + (_fillSource!.weekday! - .5) * _columnWidth + _fillDx,
        ).clamp(_axisWidth, _axisWidth + 7 * _columnWidth)
      : _resizeEdge == _MarqueeEdge.left && _resizeX != null
      ? _resizeX!
      : _axisWidth + (preview.firstDay - 1) * _columnWidth;

  double _previewRight(ZonePaintSelection preview) =>
      _fillSource != null
      ? math.max(
          _axisWidth + _fillSource!.weekday! * _columnWidth,
          _axisWidth + (_fillSource!.weekday! - .5) * _columnWidth + _fillDx,
        ).clamp(_axisWidth, _axisWidth + 7 * _columnWidth)
      : _resizeEdge == _MarqueeEdge.right && _resizeX != null
      ? _resizeX!
      : _axisWidth + preview.lastDay * _columnWidth;

  /// The marquee's own fill+ring, with no gesture of its own — the caller
  /// decides whether to wrap it in an [IgnorePointer] (a live paint/fill
  /// drag, where taking pointers would intercept the very gesture drawing
  /// it) or a move detector (an unsaved, released marquee).
  ///
  /// SelectedPillBorder, not a hand-rolled `Border.all` — design-system
  /// consolidation, requested directly ("this blue border needs to have
  /// consistent style so it doesn't diverge... should be the style of
  /// current select zone/task"). Was a single, square-cornered, 60%-alpha
  /// ring with no dark separator — see docs/DESIGN_SYSTEM.md for the
  /// canonical shape this now matches exactly.
  Widget _marqueeBody(AmbleTheme theme) => SelectedPillBorder(
    key: const ValueKey('zone-paint-selection'),
    theme: theme,
    contentRadius: BorderRadius.circular(theme.radiusMd),
    fillColor: theme.colorAccent.withValues(alpha: .09),
    child: const SizedBox.expand(),
  );

  /// Drags the WHOLE pending marquee, keeping its size and moving both
  /// axes at once — requested directly: "when drawn and release should be
  /// able to drag and move drawn zones that are not saved yet."
  ///
  /// Tracks the finger by DELTA rather than by absolute cell, so the
  /// marquee keeps its grab offset instead of snapping its top-left corner
  /// to wherever the finger happens to be. The accumulated pixel delta is
  /// what's kept ([_marqueeMoveDx]/[_marqueeMoveDy]); the snapped
  /// day/minute shift is derived from it each frame, so sub-cell movement
  /// accumulates properly instead of being rounded away every event.
  void _moveMarquee(Offset delta) {
    final origin = _marqueeMoveOrigin;
    if (origin == null) return;
    _marqueeMoveDx += delta.dx;
    _marqueeMoveDy += delta.dy;

    final dayShift = (_marqueeMoveDx / _columnWidth).round();
    final minuteShift = (_marqueeMoveDy / _pixelsPerMinute / 5).round() * 5;

    // Clamp as a RIGID body: the span never changes, it just stops at the
    // grid's edges. Shifting each edge independently would squash the
    // marquee against a boundary instead of halting it.
    final span = origin.lastDay - origin.firstDay;
    final firstDay = (origin.firstDay + dayShift).clamp(1, 7 - span);
    final duration = origin.endMinutes - origin.startMinutes;
    final startMinutes = (origin.startMinutes + minuteShift).clamp(
      0,
      1440 - duration,
    );
    final next = ZonePaintSelection(
      firstDay,
      firstDay + span,
      startMinutes,
      startMinutes + duration,
    );
    setState(() {
      _paint = next;
      // The naming sheet reads its target from `_pending`, so it has to
      // track the live rectangle or it would save the pre-move one — the
      // same rule `_resizeMarquee` follows.
      if (_pending != null) _setPending(_target(next));
    });
  }

  /// Begins a drag-to-multi-select sweep from an UNSELECTED zone — see
  /// [_sweepingZones] for why the decision is latched here rather than
  /// re-derived per event.
  ///
  /// The origin zone is selected by ID, not by hit-testing the pointer:
  /// a drag is only recognised once the finger passes touch slop, so by
  /// the time this fires the pointer can already sit over a neighbour.
  /// (The task-side sweep hit exactly that, and it silently skipped the
  /// very zone the drag began on.) We know which zone started it without
  /// looking at coordinates at all.
  void _startZoneSweep(Zone origin, Offset global) {
    if (_saving || _pending != null) return;
    final box = _grid;
    if (box == null) return;
    _sweepingZones = true;
    final local = box.globalToLocal(global);
    setState(() {
      _sweepAnchor = local;
      _sweepCurrent = local;
    });
    ref.read(zoneEditSelectionProvider.notifier).add(origin.id);
  }

  /// Adds every zone the sweep's rectangle now covers. Purely ADDITIVE —
  /// a zone already selected is skipped rather than toggled, so sweeping
  /// back across one (or wobbling inside it) can't undo the sweep's own
  /// work.
  ///
  /// Hit-tested against the zones' own (weekday, minute) windows via
  /// [_cell], the same mapping the paint selection uses, rather than
  /// against render boxes — the block that started the drag holds the
  /// pointer for the whole gesture, so a real hit test would only ever
  /// report that same block.
  void _updateZoneSweep(Offset global, List<Zone> zones) {
    if (!_sweepingZones) return;
    final box = _grid;
    if (box == null) return;
    final local = box.globalToLocal(global);
    setState(() => _sweepCurrent = local);

    final anchor = _sweepAnchor;
    if (anchor == null) return;
    final (dayA, minuteA) = _cell(anchor);
    final (dayB, minuteB) = _cell(local);
    final firstDay = math.min(dayA, dayB);
    final lastDay = math.max(dayA, dayB);
    final startMinutes = math.min(minuteA, minuteB);
    final endMinutes = math.max(minuteA, minuteB);

    final selection = ref.read(zoneEditSelectionProvider);
    final notifier = ref.read(zoneEditSelectionProvider.notifier);
    for (final zone in zones) {
      final weekday = zone.weekday;
      if (weekday == null || weekday < firstDay || weekday > lastDay) continue;
      // Overlap, not containment — a sweep that merely grazes a zone
      // still catches it, which is what "drag across these" means.
      if (zone.endMinutes <= startMinutes) continue;
      if (zone.startMinutes >= endMinutes) continue;
      if (selection.contains(zone.id)) continue;
      notifier.add(zone.id);
    }
  }

  /// Ends the sweep. The selection it produced stays; only the marquee
  /// goes away.
  void _endZoneSweep() {
    if (!_sweepingZones) return;
    _sweepingZones = false;
    setState(() {
      _sweepAnchor = null;
      _sweepCurrent = null;
    });
  }

  /// Scrolls the new zone's own START to the top of the visible strip once
  /// the sheet opens — reported directly: creating a zone low on screen put
  /// it behind the sheet, which covers the lower ~62% of the viewport.
  /// Called after every path that sets [_pending].
  void _scrollPendingIntoView(int startMinutes) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = (startMinutes * _pixelsPerMinute - _pixelsPerMinute * 30)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      if ((target - _scroll.offset).abs() < 1) return;
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  void _tapEmpty(TapUpDetails details) {
    if (_saving) return;
    // **2026-09-23 — a single tap anywhere outside an unsaved marquee
    // dismisses it**, rather than doing nothing. Requested directly:
    // "single tap outside closed sheet and removes marquee then all items
    // active." This is a TAP only — `onTapUp` never fires for a
    // tap-and-move, so a drag that starts outside still scrolls the grid
    // normally (the other half of the same request: "if not single tap
    // but tap and move > then should just be scroll").
    //
    // Returns immediately afterwards: dismissing is the whole action, and
    // the same tap must NOT also fall through to painting a new one-hour
    // marquee below.
    if (_pending != null) {
      _cancelPaint();
      return;
    }
    if (ref.read(zoneEditSelectionProvider).isNotEmpty) {
      ref.read(zoneEditSelectionProvider.notifier).clear();
      return;
    }
    if (_grid == null) return;
    final local = _grid!.globalToLocal(details.globalPosition);
    if (local.dx < _axisWidth) return;
    final (day, minute) = _cell(local);
    final start = minute.clamp(0, 1435);
    final paint = ZonePaintSelection(
      day,
      day,
      start,
      math.min(start + 60, 1440),
    );
    setState(() {
      _paint = paint;
      _setPending(_target(paint));
    });
    _scrollPendingIntoView(start);
  }

  void _setPending(NewZoneTarget? target) {
    _pending = target;
    _shellChromeController?.setDockObscured(
      target != null || ref.read(pendingTaskDraftProvider) != null,
    );
  }

  void _startFill(Zone zone) {
    if (_saving) return;
    setState(() {
      _fillSource = zone;
      _fillDx = 0;
    });
  }

  ZonePaintSelection? get _fillSelection {
    final zone = _fillSource;
    if (zone?.weekday == null) return null;
    final endDay = (zone!.weekday! + (_fillDx / _columnWidth).round()).clamp(
      1,
      7,
    );
    return ZonePaintSelection.between(
      zone.weekday!,
      zone.startMinutes,
      endDay,
      zone.endMinutes,
    );
  }

  Future<void> _finishFill() async {
    final source = _fillSource;
    final selection = _fillSelection;
    if (source == null || selection == null) return;
    final existing = ref.read(zoneListProvider);
    final days = selection.weekdays
        .where(
          (day) => !existing.any(
            (z) =>
                z.isWeeklyPlacement &&
                !z.archived &&
                z.weekday == day &&
                z.facetId == source.facetId &&
                z.startMinutes == source.startMinutes &&
                z.endMinutes == source.endMinutes,
          ),
        )
        .toSet();
    setState(() {
      _fillSource = null;
      _fillDx = 0;
    });
    if (days.isEmpty) return;
    await _write(() async {
      await ref
          .read(zoneListProvider.notifier)
          .paintWeeklyZones(
            title: source.title,
            facetId: source.facetId,
            weekdays: days,
            startMinutes: source.startMinutes,
            endMinutes: source.endMinutes,
          );
    });
  }

  Future<void> _write(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        AppUndoToast.show(
          context: context,
          message: error is StateError
              ? error.message
              : 'Could not save this change.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finishMove(List<Zone> zones) async {
    final kind = _moveKind;
    final delta = (_moveDy / _pixelsPerMinute / 5).round() * 5;
    final dayDelta = (_moveDx / _columnWidth).round();
    setState(() {
      _moveKind = null;
      _moveDy = 0;
      _moveDx = 0;
    });
    if (kind == null || (delta == 0 && dayDelta == 0)) return;
    final selection = ref.read(zoneEditSelectionProvider);
    final moves = <ZoneMove>[];
    for (final z in zones.where((z) => selection.contains(z.id))) {
      final weekday = (z.weekday! + dayDelta).clamp(1, 7);
      final start =
          z.startMinutes +
          (kind == ZoneGroupGestureKind.resizeBottom ? 0 : delta);
      final end =
          z.endMinutes + (kind == ZoneGroupGestureKind.resizeTop ? 0 : delta);
      // Running off the end of the day, or inverting the window, is
      // genuinely impossible rather than a refusal — clamp and carry on.
      // Overlap is NOT a refusal any more ("never prevent action"):
      // neighbours are pushed, or trimmed to a sliver only when one would
      // otherwise be swallowed whole. See `resolveZonePlacement`.
      if (start < 0 || end > 1440 || start >= end) continue;
      moves.addAll(
        resolveZonePlacement(
          placedZoneId: z.id,
          placedOriginalStartMinutes: z.startMinutes,
          placedStartMinutes: start,
          placedEndMinutes: end,
          // Resolve collisions in the destination weekday, not the source.
          otherZones: zones
              .where(
                (o) =>
                    o.id != z.id &&
                    o.weekday == weekday &&
                    !selection.contains(o.id),
              )
              .toList(),
          tasksByZoneId: const {},
        ).map(
          (move) => ZoneMove(
            zoneId: move.zoneId,
            newStartMinutes: move.newStartMinutes,
            newEndMinutes: move.newEndMinutes,
            taskMoves: move.taskMoves,
            newWeekday: move.zoneId == z.id ? weekday : null,
          ),
        ),
      );
    }
    if (moves.isEmpty) return;
    final zoneIds = moves.map((m) => m.zoneId).toSet();
    final taskIds = moves
        .expand((m) => m.taskMoves)
        .map((t) => t.taskId)
        .toSet();
    await _write(
      () => commitZoneChangeWithUndo(
        context,
        ref,
        zoneIds: zoneIds,
        taskIds: taskIds,
        message: zoneIds.length > 1
            ? 'Moved ${zoneIds.length} zone(s)'
            : 'Moved zone',
        commit: () =>
            ref.read(zoneListProvider.notifier).commitZoneCascade(moves),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    _shellChromeController?.updateHeader(
      _tab.name,
      AppTabSwitch<ZoneGridTab>(
        options: _zoneGridTabOptions,
        value: _tab,
        onChanged: _switchTab,
      ),
    );
    // The underlying Day calendar must never bleed through the Edit crossfade.
    return ColoredBox(
      color: theme.colorSurfacePrimary,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    _container = ProviderScope.containerOf(context);
    ref.listen(pendingTaskDraftProvider, (_, draft) {
      _shellChromeController?.setDockObscured(_pending != null || draft != null);
    });
    _shellChromeController?.setDockObscured(
      _pending != null || ref.watch(pendingTaskDraftProvider) != null,
    );
    // `editModeEnabledProvider` is `autoDispose` (by design — see its own
    // doc comment) and resets to `false` the instant it has zero
    // watchers. While the Zones tab is showing, the embedded
    // `TimelineScreen` isn't mounted and nothing else watches it, so a
    // bare `ref.read`-then-`toggle()` in `_syncEditMode` was found (via a
    // failing test) to be reset back to `false` by autoDispose before the
    // next frame's freshly-mounted `TimelineScreen` ever got a chance to
    // watch it — this screen has to hold its OWN live watch the whole
    // time it exists, bridging that gap.
    ref.watch(editModeEnabledProvider);

    // The Tasks tab hosts the pre-existing, unmodified spatial Timeline
    // (forced into its own Edit Mode by `_syncEditMode`) rather than any
    // of this class's own zone-grid body/gestures below — see this
    // class's own doc comment for why these two tabs swap wholesale
    // rather than sharing state.
    if (_tab == ZoneGridTab.tasks) {
      return AppViewTransition(
        viewId: 'edit-tasks',
        child: Scaffold(
          backgroundColor: theme.colorSurfacePrimary,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    // **2026-09-20 — bare tab switch, no icons.** Requested
                    // directly: "in edit mode on top we should only have 2
                    // tabs task and zones" — Close (and, on the Zones tab,
                    // Edit) moved to a bottom dock instead (see below).
                    if (_shellChromeController == null)
                      Padding(
                        padding: EdgeInsets.all(theme.spacingMd),
                        child: AppTabSwitch<ZoneGridTab>(
                          options: _zoneGridTabOptions,
                          value: _tab,
                          onChanged: _switchTab,
                        ),
                      ),
                    // **2026-09-20 — the calendar is back.** Requested
                    // directly: "Tasks edit mode should also have
                    // calendar." `showHeader` flips true so `TimelineScreen`
                    // renders its own `AppCalendarHeader` again (Today +
                    // the date accordion, via that header's own
                    // Edit-Mode-collapsed branch — `editModeEnabledProvider`
                    // is already forced on for this tab by `_syncEditMode`).
                    // `showCloseButton: false` on the embedded
                    // `TimelineScreen`... see that widget's own field —
                    // this screen's Close now lives in the bottom dock
                    // instead, so the header's own X would be a duplicate.
                    const Expanded(
                      child: TimelineScreen(
                        mode: TimelineDisplayMode.spatial,
                        calendarHeaderShowsCloseButton: false,
                      ),
                    ),
                  ],
                ),
                // **2026-09-20 — hidden while a quick-create draft is
                // live.** Reported directly: this dock painted on top of
                // the tap-empty-space mini sheet, which is an in-tree
                // overlay nested inside the embedded `TimelineScreen`
                // above, not a pushed route — Stack paint order always
                // puts a later sibling (this dock) above an entire earlier
                // sibling's subtree, regardless of how deep the mini sheet
                // sits inside it. Matches the Day screen's own identical
                // gate on `AppBottomDock` (`pendingTaskDraftProvider`).
                //
                // **2026-09-21 — swaps to a selection context menu (back
                // arrow / Edit / Remove) whenever `editSelectionProvider`
                // is non-empty.** Requested directly: "on edit task mode
                // when item(s) selected we need selection context menu."
                // Back-arrow CLEARS the selection only (Edit Mode itself
                // stays active, confirmed via AskUserQuestion) rather than
                // closing this screen the way the plain Close icon used to
                // — a genuinely different action, hence the icon change.
                if (ref.watch(pendingTaskDraftProvider) == null)
                  Builder(
                    builder: (context) {
                      final selectedIds = ref.watch(editSelectionProvider);
                      return Positioned(
                        left: theme.spacingMd,
                        bottom: theme.spacingMd,
                        child: SafeArea(
                          top: false,
                          child: _taskContextDock(selectedIds),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final zones = ref
        .watch(zoneListProvider)
        .where((z) => z.isWeeklyPlacement && !z.archived)
        .toList();
    final selected = ref.watch(zoneEditSelectionProvider);
    final preview = _fillSelection ?? _paint;
    final previewTitle = _fillSource?.title ?? 'New zone';
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return AppViewTransition(
      viewId: 'edit-zones',
      child: Scaffold(
        backgroundColor: theme.colorSurfacePrimary,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // **2026-09-20 — bare tab switch, no icons.** See this
                  // class's own doc comment for the full change — Edit and
                  // Close moved to a bottom dock below.
                  if (_shellChromeController == null)
                    Padding(
                      padding: EdgeInsets.all(theme.spacingMd),
                      child: AppTabSwitch<ZoneGridTab>(
                        options: _zoneGridTabOptions,
                        value: _tab,
                        onChanged: _switchTab,
                      ),
                    ),
                  // **2026-09-24 — selection tooling MOVED to the bottom
                  // dock.** Requested directly: "spacing of tooling in zone
                  // edit mode we have tooling opened on top... align with
                  // edit tasks and should be at bottom." This used to be a
                  // top `Row` of loose `AppButton` circles; see the bottom
                  // `AppDockPane` near this screen's own Close dock for the
                  // replacement, which now branches on `selected.isEmpty`
                  // the same way the Tasks tab's own dock already does.
                  if (selected.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacingMd,
                      ),
                      child: Text(
                        '${selected.length} selected',
                        style: theme.textCaption,
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: _axisWidth,
                      top: theme.spacingSm,
                      bottom: theme.spacingSm,
                    ),
                    child: Row(
                      children: [
                        for (final label in labels)
                          Expanded(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: theme.textCaption,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    // TimelinePinchZoom wraps the whole viewport — pinch
                    // works in both view mode (the opaque
                    // 'zone-paint-surface' GestureDetector below owns
                    // long-press) and edit mode (that same detector owns
                    // pan instead) without needing to change based on
                    // `_editing`, since TimelinePinchZoom observes pointers
                    // passively rather than claiming the gesture arena —
                    // see that widget's own doc comment.
                    child: TimelinePinchZoom(
                      child: Stack(
                        key: _viewportKey,
                        children: [
                          SingleChildScrollView(
                            controller: _scroll,
                            // Every hour label is centred ON its own tick line,
                            // so the 00:00 label at the very top extends half a
                            // caption line ABOVE the content box and the one at
                            // the day's end sits flush against the bottom —
                            // both clipped. Reported directly: "need larger
                            // padding top bottom as cant see 00 and 00 end
                            // day."
                            //
                            // `spacingLg` matches the Timeline's own fix for
                            // the identical report on its hour gutter (see
                            // `timeline_screen.dart`'s scroll padding, where
                            // spacingMd was explicitly found too small to clear
                            // half a caption line).
                            padding: EdgeInsets.symmetric(
                              vertical: theme.spacingLg,
                            ),
                            // Suppressed only while a gesture is actually in
                            // flight — NOT unconditionally, even though this
                            // tab is permanently in edit mode. `_editing`
                            // used to appear in this list back when it was a
                            // toggle; keeping it here once it became `true`
                            // for good would have disabled grid scrolling
                            // outright.
                            physics:
                                _paintOrigin != null ||
                                    _fillSource != null ||
                                    _moveKind != null ||
                                    _resizeEdge != null ||
                                    _marqueeMoveOrigin != null
                                ? const NeverScrollableScrollPhysics()
                                : null,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final width =
                                    (constraints.maxWidth - _axisWidth) / 7;
                                return SizedBox(
                                  key: _gridKey,
                                  height: _gridHeight,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned.fill(
                                        child: Listener(
                                          onPointerDown: (_) =>
                                              _pointerCancelled = false,
                                          onPointerCancel: (_) {
                                            _pointerCancelled = true;
                                            _cancelPaint();
                                          },
                                          child: GestureDetector(
                                            key: const ValueKey(
                                              'zone-paint-surface',
                                            ),
                                            behavior: HitTestBehavior.opaque,
                                            // Long-press owns painting, and
                                            // pan is deliberately NOT wired:
                                            // a plain vertical drag belongs
                                            // to the scroll view, which is
                                            // the "normal vertical swipe
                                            // scrolls rather than painting"
                                            // behaviour this screen has
                                            // always had. Both branches used
                                            // to be wired and switched on
                                            // `_editing`; with edit mode
                                            // permanent, wiring pan instead
                                            // would mean the grid could never
                                            // be scrolled by dragging it.
                                            onTapUp: _tapEmpty,
                                            onLongPressStart: (d) =>
                                                _startPaint(d.globalPosition),
                                            onLongPressMoveUpdate: (d) =>
                                                _updatePaint(d.globalPosition),
                                            onLongPressEnd: (_) => _endPaint(),
                                            onLongPressCancel: _cancelPaint,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: _axisWidth,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onVerticalDragUpdate: _editing
                                              ? (d) {
                                                  if (_scroll.hasClients) {
                                                    _scroll.jumpTo(
                                                      (_scroll.offset -
                                                              d.delta.dy)
                                                          .clamp(
                                                            0.0,
                                                            _scroll
                                                                .position
                                                                .maxScrollExtent,
                                                          ),
                                                    );
                                                  }
                                                }
                                              : null,
                                        ),
                                      ),
                                      // `<= 24`, not `< 24`. The day's closing
                                      // label is a real 25th tick at the grid's
                                      // bottom edge: with `< 24` the last one
                                      // drawn was 23:00 and the final hour of
                                      // the grid carried no label at all, which
                                      // no amount of scroll padding could
                                      // reveal — reported directly, "still cant
                                      // fully scroll on zone edit to see 00 end
                                      // of day."
                                      for (var hour = 0; hour <= 24; hour++)
                                        Positioned(
                                          // 8px clear of the screen edge and
                                          // 8px clear of the first lane —
                                          // requested directly, replacing a
                                          // zero left inset that left the
                                          // labels almost touching the edge.
                                          left: theme.spacingSm,
                                          // Derived from the same scale the
                                          // zones are laid out on, never a
                                          // second hardcoded 44 — a literal
                                          // here silently drifts from every
                                          // block beside it the moment the
                                          // scale changes.
                                          top: hour * 60 * _pixelsPerMinute,
                                          width:
                                              _axisWidth - theme.spacingSm * 2,
                                          child: IgnorePointer(
                                            // Requested directly: the blue
                                            // accent time badge shown while
                                            // creating/editing a task
                                            // (`TaskEdgeTimeLabel`) pads its
                                            // own text `theme.spacingSm` in
                                            // from its box's left edge — this
                                            // plain axis label had no internal
                                            // padding of its own, so its text
                                            // sat visibly left of the badge's
                                            // text despite sharing the same
                                            // `left: theme.spacingSm` box
                                            // origin. Matches the identical
                                            // fix on `TaskBoundaryMarkers`'
                                            // own left-aligned gutter case.
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                left: theme.spacingSm,
                                              ),
                                              child: Text(
                                                '${hour.toString().padLeft(2, '0')}:00',
                                                // LEFT-aligned, matching the
                                                // Timeline's own hour labels
                                                // (`TaskBoundaryMarkers` with
                                                // `leftInset` set and NO
                                                // `columnWidth`, which is what
                                                // switches it to right-aligned).
                                                //
                                                // Right-alignment was why earlier
                                                // width changes looked like they
                                                // did nothing: the glyphs hugged
                                                // the box's RIGHT edge, so
                                                // shrinking the box moved them
                                                // right while the left gap only
                                                // appeared constant by
                                                // coincidence. Measured with a
                                                // throwaway geometry probe before
                                                // changing it.
                                                textAlign: TextAlign.left,
                                                // Never wrap. `_axisWidth` is sized
                                                // from a measured-by-arithmetic
                                                // glyph width, which a device font
                                                // fallback or a larger text scale
                                                // could exceed — and the failure
                                                // mode is silent two-line labels
                                                // that squash the whole axis
                                                // (reported directly once already).
                                                // One line, clipped if it ever must
                                                // be, rather than reflowing.
                                                maxLines: 1,
                                                softWrap: false,
                                                overflow: TextOverflow.clip,
                                                // colorTextSecondary, not
                                                // colorTextTertiary — unified
                                                // directly: "hours of day have
                                                // different color on different
                                                // screens... needs unified."
                                                // Matches TaskBoundaryMarkers'
                                                // own hour-tick color on the
                                                // spatial Timeline exactly, so
                                                // the same "HH:MM" label reads
                                                // identically regardless of
                                                // which screen it's on.
                                                //
                                                // textCaptionMono, not
                                                // textCaption — this is a
                                                // genuinely numeric/temporal
                                                // label (TypePrimitives
                                                // .fontFamily's own mono
                                                // carve-out), and
                                                // TaskBoundaryMarkers' own
                                                // hour label already reads
                                                // textCaptionMono; this one
                                                // had drifted onto the sans
                                                // style, reported directly
                                                // as a font mismatch between
                                                // this screen and everywhere
                                                // else.
                                                style: theme.textCaptionMono
                                                    .copyWith(
                                                      color: theme
                                                          .colorTextSecondary,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      for (var day = 2; day <= 7; day++)
                                        Positioned(
                                          left: _axisWidth + (day - 1) * width,
                                          top: 0,
                                          bottom: 0,
                                          child: IgnorePointer(
                                            child: Container(
                                              width: theme.borderWidthHairline,
                                              color: theme.colorBorder
                                                  .withValues(alpha: .25),
                                            ),
                                          ),
                                        ),
                                      for (var day = 1; day <= 7; day++)
                                        Positioned(
                                          left: _axisWidth + (day - 1) * width,
                                          width: width,
                                          top: 0,
                                          bottom: 0,
                                          // **2026-09-23 — every existing
                                          // zone is inert while an UNSAVED
                                          // marquee is on screen.** Requested
                                          // directly: "when marquee is drawn
                                          // and released... tap and move is
                                          // scroll (not drawing a new marquee
                                          // or selecting tapped item) so when
                                          // not saved marquee drawn other
                                          // interactions are not active."
                                          // Tapping an existing zone used to
                                          // select it straight through the
                                          // pending sheet; now the tap falls
                                          // to the paint surface underneath,
                                          // where `_tapEmpty` dismisses the
                                          // marquee instead (see its own
                                          // comment). Re-enabled the moment
                                          // `_pending` clears.
                                          child: IgnorePointer(
                                            ignoring: _pending != null,
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                // The selected zone paints LAST
                                                // among this day's siblings —
                                                // see `selectedZonesLast`'s own
                                                // doc comment. Overlapping/
                                                // adjacent zones are a
                                                // designed-for, common case on
                                                // this screen (see `_Phantom`'s
                                                // own doc comment).
                                                for (final zone
                                                    in selectedZonesLast(
                                                      zones.where(
                                                        (z) => z.weekday == day,
                                                      ),
                                                      selected,
                                                    ))
                                                  _block(
                                                    zone,
                                                    zones,
                                                    theme,
                                                    selected.contains(zone.id),
                                                    _axisWidth +
                                                        (day - 1) * width,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      // The live drag-to-multi-select sweep
                                      // marquee — deliberately the SAME
                                      // shape as the paint-selection
                                      // preview below it (`SelectedPillBorder`
                                      // over a translucent accent fill,
                                      // `IgnorePointer`ed so it can never
                                      // intercept the drag drawing it), so
                                      // "you are selecting right now" reads
                                      // identically whether you started on
                                      // empty grid or on an existing zone.
                                      if (_sweepAnchor case final anchor?)
                                        if (_sweepCurrent case final current?)
                                          Positioned(
                                            left: math.min(
                                              anchor.dx,
                                              current.dx,
                                            ),
                                            width: (current.dx - anchor.dx)
                                                .abs(),
                                            top: math.min(
                                              anchor.dy,
                                              current.dy,
                                            ),
                                            height: (current.dy - anchor.dy)
                                                .abs(),
                                            child: IgnorePointer(
                                              child: SelectedPillBorder(
                                                key: const ValueKey(
                                                  'zone-sweep-selection',
                                                ),
                                                theme: theme,
                                                contentRadius:
                                                    BorderRadius.circular(
                                                      theme.radiusMd,
                                                    ),
                                                fillColor: theme.colorAccent
                                                    .withValues(alpha: .09),
                                                child: const SizedBox.expand(),
                                              ),
                                            ),
                                          ),
                                      if (preview != null) ...[
                                        Positioned(
                                          key: const ValueKey(
                                            'zone-marquee-body',
                                          ),
                                          left: _previewLeft(preview),
                                          width:
                                              _previewRight(preview) -
                                              _previewLeft(preview),
                                          top:
                                              preview.startMinutes *
                                              _pixelsPerMinute,
                                          height:
                                              (preview.endMinutes -
                                                  preview.startMinutes) *
                                              _pixelsPerMinute,
                                          // **2026-09-23 — an UNSAVED marquee
                                          // is draggable as a whole.**
                                          // Requested directly: "when drawn
                                          // and release should be able to
                                          // drag and move drawn zones that
                                          // are not saved yet." Only while
                                          // `_pending != null` — the same
                                          // rectangle also previews a live
                                          // paint/fill drag, and taking
                                          // pointers during those would
                                          // intercept the very gesture
                                          // drawing it (which is why this was
                                          // an unconditional `IgnorePointer`
                                          // before).
                                          //
                                          // `onPan*`, not an axis-specific
                                          // pair: a move genuinely travels
                                          // both axes at once, unlike the
                                          // edge handles (each of which
                                          // changes exactly one). The
                                          // scrollable can't steal it because
                                          // `physics` is already
                                          // `NeverScrollableScrollPhysics`
                                          // while a marquee move is in
                                          // flight — see the `physics:` gate
                                          // above, which now includes
                                          // `_marqueeMoveOrigin`.
                                          child: _pending == null
                                              ? IgnorePointer(
                                                  child: _marqueeBody(theme),
                                                )
                                              : RawGestureDetector(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  gestures: {
                                                    _EagerPanRecognizer:
                                                        GestureRecognizerFactoryWithHandlers<
                                                          _EagerPanRecognizer
                                                        >(
                                                          () =>
                                                              _EagerPanRecognizer(
                                                                debugOwner:
                                                                    this,
                                                              ),
                                                          (instance) => instance
                                                            ..onStart = (_) {
                                                              setState(() {
                                                                _marqueeMoveOrigin =
                                                                    _paint;
                                                                _marqueeMoveDx =
                                                                    0;
                                                                _marqueeMoveDy =
                                                                    0;
                                                              });
                                                            }
                                                            ..onUpdate = (d) {
                                                              _moveMarquee(
                                                                d.delta,
                                                              );
                                                            }
                                                            ..onEnd = (_) {
                                                              setState(() {
                                                                _marqueeMoveOrigin =
                                                                    null;
                                                              });
                                                            }
                                                            ..onCancel = () {
                                                              setState(() {
                                                                _marqueeMoveOrigin =
                                                                    null;
                                                              });
                                                            },
                                                        ),
                                                  },
                                                  child: _marqueeBody(theme),
                                                ),
                                        ),
                                        for (final day in preview.weekdays)
                                          Positioned(
                                            left:
                                                _axisWidth +
                                                (day - 1) * width +
                                                theme.spacingXs,
                                            width:
                                                width - 2 * theme.spacingXs,
                                            top:
                                                preview.startMinutes *
                                                    _pixelsPerMinute +
                                                theme.spacingXs / 2,
                                            height: math.max(
                                              2,
                                              (preview.endMinutes -
                                                          preview
                                                              .startMinutes) *
                                                      _pixelsPerMinute -
                                                  theme.spacingXs,
                                            ),
                                            child: IgnorePointer(
                                              child: _Phantom(
                                                key: ValueKey(
                                                  'zone-phantom-$day',
                                                ),
                                                theme: theme,
                                                title: previewTitle,
                                              ),
                                            ),
                                          ),
                                        // TaskEdgeTimeLabel, not a plain accent-
                                        // colored Text — design-system
                                        // consolidation, requested directly:
                                        // every other "show the hour" moment in
                                        // the app (task create/edit, zone
                                        // resize) already uses this shared
                                        // accent-BACKGROUND pill; this was the
                                        // one remaining plain-text case with no
                                        // background at all. Two separate
                                        // labels (start/end), matching the
                                        // pending-create pill's own two-label
                                        // shape, rather than one combined
                                        // "start – end" string, since
                                        // TaskEdgeTimeLabel takes one TimeOfDay.
                                        // See docs/DESIGN_SYSTEM.md.
                                        // **In the HOUR COLUMN, centred ON each
                                        // edge** — requested directly: "the hour
                                        // start end (with bg accent) should be on
                                        // the left column where hours are (same
                                        // pattern / positioning / object) as with
                                        // edit task."
                                        //
                                        // `left: 0` (the axis's own left edge,
                                        // where the hour labels themselves sit)
                                        // rather than `_axisWidth`, plus the
                                        // `FractionalTranslation` half-shift that
                                        // straddles the boundary — exactly the
                                        // geometry `PendingTaskPill` uses for its
                                        // own start/end labels, so the two read
                                        // identically. Replaces a version sitting
                                        // just RIGHT of the axis and nudged clear
                                        // of the edges by spacingLg/spacingXs,
                                        // which lined up with neither the hours
                                        // nor the task view's own treatment.
                                        Positioned(
                                          left: 0,
                                          top:
                                              preview.startMinutes *
                                              _pixelsPerMinute,
                                          child: FractionalTranslation(
                                            translation: const Offset(0, -0.5),
                                            child: IgnorePointer(
                                              child: TaskEdgeTimeLabel(
                                                theme: theme,
                                                time: TimeOfDay(
                                                  hour:
                                                      preview.startMinutes ~/
                                                      60,
                                                  minute:
                                                      preview.startMinutes % 60,
                                                ),
                                                showLine: false,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 0,
                                          top:
                                              preview.endMinutes *
                                              _pixelsPerMinute,
                                          child: FractionalTranslation(
                                            translation: const Offset(0, -0.5),
                                            child: IgnorePointer(
                                              child: TaskEdgeTimeLabel(
                                                theme: theme,
                                                time: TimeOfDay(
                                                  hour:
                                                      preview.endMinutes ~/ 60,
                                                  minute:
                                                      preview.endMinutes % 60,
                                                ),
                                                showLine: false,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Four resize dots, one per edge,
                                        // each centred on its own edge's
                                        // midpoint — "do is in the middle of
                                        // the marque horz middle and vert
                                        // middle". Top/bottom change the
                                        // zone's start/end time; left/right
                                        // widen or narrow the weekday span.
                                        //
                                        // Last in this Stack so they paint
                                        // above the marquee fill and stay
                                        // grabbable — every sibling above is
                                        // `IgnorePointer`ed, so nothing
                                        // competes for these gestures.
                                        ...() {
                                          final left = _previewLeft(preview);
                                          final right = _previewRight(preview);
                                          final top =
                                              preview.startMinutes *
                                              _pixelsPerMinute;
                                          final bottom =
                                              preview.endMinutes *
                                              _pixelsPerMinute;
                                          Widget at(
                                            double x,
                                            double y,
                                            _MarqueeEdge edge,
                                          ) => Positioned(
                                            key: ValueKey(edge),
                                            // The hit box is clamped INSIDE
                                            // the grid, and only the painted
                                            // dot is centred on the edge.
                                            //
                                            // Flutter does not hit-test a
                                            // child outside its parent's
                                            // bounds, `Clip.none` or not —
                                            // `ResizeHandle`'s own doc
                                            // comment documents this and
                                            // solves it the same way. A box
                                            // centred on the edge hangs half
                                            // outside the grid's own
                                            // `SizedBox`, and the whole
                                            // handle then takes no pointers
                                            // at all (confirmed here: the
                                            // dots rendered correctly and
                                            // `hitTestable` still matched
                                            // zero widgets).
                                            left:
                                                (x -
                                                        theme.spacingMinTapTarget /
                                                            2)
                                                    .clamp(
                                                      0.0,
                                                      math.max(
                                                        0.0,
                                                        constraints.maxWidth -
                                                            theme
                                                                .spacingMinTapTarget,
                                                      ),
                                                    ),
                                            top:
                                                (y -
                                                        theme.spacingMinTapTarget /
                                                            2)
                                                    .clamp(
                                                      0.0,
                                                      math.max(
                                                        0.0,
                                                        _gridHeight -
                                                            theme
                                                                .spacingMinTapTarget,
                                                      ),
                                                    ),
                                            child: IgnorePointer(
                                              ignoring: _fillSource != null,
                                              child: _MarqueeResizeHandle(
                                                theme: theme,
                                                alignment: switch (edge) {
                                                  _MarqueeEdge.top =>
                                                    Alignment.topCenter,
                                                  _MarqueeEdge.bottom =>
                                                    Alignment.bottomCenter,
                                                  _MarqueeEdge.left =>
                                                    Alignment.centerLeft,
                                                  _MarqueeEdge.right =>
                                                    Alignment.centerRight,
                                                },
                                                vertical:
                                                    edge == _MarqueeEdge.top ||
                                                    edge == _MarqueeEdge.bottom,
                                                onDrag: (global) {
                                                  _resizeEdge = edge;
                                                  _resizeMarquee(edge, global);
                                                },
                                                onDragEnd: () => setState(() {
                                                  _resizeEdge = null;
                                                  _resizeX = null;
                                                }),
                                              ),
                                            ),
                                          );
                                          return [
                                            at(
                                              (left + right) / 2,
                                              top,
                                              _MarqueeEdge.top,
                                            ),
                                            at(
                                              (left + right) / 2,
                                              bottom,
                                              _MarqueeEdge.bottom,
                                            ),
                                            at(
                                              left,
                                              (top + bottom) / 2,
                                              _MarqueeEdge.left,
                                            ),
                                            at(
                                              right,
                                              (top + bottom) / 2,
                                              _MarqueeEdge.right,
                                            ),
                                          ];
                                        }(),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: AppTopScrollFade(
                              color: theme.colorSurfacePrimary,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: AppTopScrollFade(
                              color: theme.colorSurfacePrimary,
                              fromBottom: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_pending == null)
              AppFloatingCreateButton(
                onPressed: () {
                  final now = DateTime.now();
                  final start = (now.hour * 60).clamp(0, 1380);
                  final paint = ZonePaintSelection(
                    now.weekday,
                    now.weekday,
                    start,
                    start + 60,
                  );
                  setState(() {
                    _paint = paint;
                    _setPending(_target(paint));
                  });
                  _scrollPendingIntoView(start);
                },
              ),
            // **2026-09-20 — Close (leftmost) and Edit, in a floating
            // bottom dock.** Requested directly: "in zones edit and close
            // (close on the leftmost)" — matching the Tasks tab's own new
            // dock (Close alone) and the Day screen's `AppBottomDock`
            // visual language.
            //
            // **2026-09-24 — now branches on `selected.isEmpty`, same shape
            // as the Tasks tab's own dock above.** Requested directly:
            // "spacing of tooling in zone edit mode we have tooling opened
            // on top... align with edit tasks and should be at bottom...
            // separated from go back arrow." This dock used to be a fixed
            // single pane (just the back arrow) regardless of selection
            // state, while the Edit/Remove/Clear tooling lived in a
            // separate top `Row` instead — moved here, and the back arrow
            // split into its own pane rather than combined with Edit/Remove
            // (see the Tasks tab's own matching fix and its doc comment).
            Positioned(
              left: theme.spacingMd,
              bottom: theme.spacingMd,
              child: SafeArea(
                top: false,
                child: _zoneContextDock(selected, zones),
              ),
            ),
            // **2026-09-20 — moved AFTER the bottom dock above.** Reported
            // directly: the dock painted on top of this sheet while naming
            // a new zone, since both are plain `Positioned` siblings in the
            // same `Stack` and the dock used to come last. Stack children
            // paint in order, so the sheet now comes last instead.
            if (_pending case final target?)
              NewZoneSheet(
                key: ValueKey(target),
                target: target,
                onDismiss: _cancelPaint,
              ),
          ],
        ),
      ),
    );
  }

  Widget _block(
    Zone zone,
    List<Zone> zones,
    AmbleTheme theme,
    bool selected,
    double dayColumnLeft,
  ) {
    final delta = selected ? (_moveDy / _pixelsPerMinute / 5).round() * 5 : 0;
    final start =
        zone.startMinutes +
        (_moveKind == ZoneGroupGestureKind.resizeBottom ? 0 : delta);
    final end =
        zone.endMinutes +
        (_moveKind == ZoneGroupGestureKind.resizeTop ? 0 : delta);
    void begin(ZoneGroupGestureKind kind) => setState(() {
      _moveKind = kind;
      _moveDy = 0;
      _moveDx = 0;
    });
    void update(DragUpdateDetails d) => setState(() {
      _moveDy += d.delta.dy;
      if (_moveKind == ZoneGroupGestureKind.move) _moveDx += d.delta.dx;
    });
    return ZoneGridBlock(
      key: ValueKey(zone.id),
      theme: theme,
      zone: zone,
      horizontalOffset: selected ? _moveDx : 0,
      extending: _fillSource?.id == zone.id,
      top: start * _pixelsPerMinute,
      // zoneBackgroundGap trimmed off the BOTTOM only — mirrors
      // ZoneBackgroundBlock's own rule on the spatial Timeline exactly
      // (top edge lands precisely on start time; the standing gap between
      // two back-to-back zones comes entirely from the earlier one's own
      // bottom). Previously missing here — two zones whose times were
      // exactly back-to-back rendered with their blocks visually
      // touching. See docs/DESIGN_SYSTEM.md's "Zone pane indicator"
      // section.
      height: math.max(5, (end - start) * _pixelsPerMinute - zoneBackgroundGap),
      isSelected: selected,
      dayColumnLeft: dayColumnLeft,
      liveStartMinutes: selected && _moveKind != null ? start : null,
      liveEndMinutes: selected && _moveKind != null ? end : null,
      onTap: () => ref.read(zoneEditSelectionProvider.notifier).toggle(zone.id),
      // A vertical drag means two different things depending on whether
      // this zone was ALREADY selected when the finger went down:
      // selected -> move it (and every other selected zone) in time, the
      // long-standing behaviour; unselected -> sweep it and whatever else
      // the finger crosses into the selection. Requested directly ("when
      // tap and drag zones let's make it multi select zones"), with the
      // selected-zone half deliberately left alone (confirmed via
      // AskUserQuestion) so group move-to-reschedule still works.
      //
      // The two can't collide: they're the same callback slot, resolved
      // by `selected` at build time, so only one is ever wired for a
      // given zone on a given frame.
      // The unselected (sweep) half is additionally gated on [_editing],
      // matching the paint-selection surface's own `onPanStart: _editing`
      // gating right above: OUTSIDE edit mode the grid is vertically
      // scrollable (`physics` falls back to the default), so a vertical
      // drag there legitimately belongs to the scroll view — that's the
      // long-standing "normal vertical swipe scrolls rather than
      // painting" behaviour this must not break. Wiring the sweep
      // unconditionally handed the zone block a competing vertical-drag
      // recognizer that the scrollable won in the arena anyway, so the
      // sweep silently never fired; gating it here makes the split
      // explicit instead of relying on who wins the arena.
      // `_sweepingZones` is checked BEFORE `selected`, and that order is
      // load-bearing rather than stylistic — see its own doc comment for
      // the bug it prevents (the sweep selects its origin, the rebuild
      // flips `selected`, and a `selected`-first dispatch then hands the
      // live gesture to the move handlers mid-drag).
      onMoveStart: _sweepingZones
          ? (d) => _updateZoneSweep(d.globalPosition, zones)
          : selected
          ? (_) => begin(ZoneGroupGestureKind.move)
          : _editing
          ? (d) => _startZoneSweep(zone, d.globalPosition)
          : null,
      onMoveUpdate: _sweepingZones
          ? (d) => _updateZoneSweep(d.globalPosition, zones)
          : selected
          ? update
          : _editing
          ? (d) => _updateZoneSweep(d.globalPosition, zones)
          : null,
      onMoveEnd: _sweepingZones
          ? (_) => _endZoneSweep()
          : selected
          ? (_) => _finishMove(zones)
          : _editing
          ? (_) => _endZoneSweep()
          : null,
      onResizeTopStart: selected
          ? (_) => begin(ZoneGroupGestureKind.resizeTop)
          : null,
      onResizeTopUpdate: selected ? update : null,
      onResizeTopEnd: selected ? (_) => _finishMove(zones) : null,
      onResizeBottomStart: selected
          ? (_) => begin(ZoneGroupGestureKind.resizeBottom)
          : null,
      onResizeBottomUpdate: selected ? update : null,
      onResizeBottomEnd: selected ? (_) => _finishMove(zones) : null,
      // Only side handles extend across days; body gestures use onMove.
      onExtendStart: _sweepingZones
          ? (d) => _updateZoneSweep(d.globalPosition, zones)
          : selected
          ? (d) {
              _startFill(zone);
              if (_grid != null) {
                setState(
                  () => _fillDx =
                      _grid!.globalToLocal(d.globalPosition).dx -
                      _axisWidth -
                      (zone.weekday! - .5) * _columnWidth,
                );
              }
            }
          : _editing
          ? (d) => _startZoneSweep(zone, d.globalPosition)
          : null,
      onExtendUpdate: _sweepingZones
          ? (d) => _updateZoneSweep(d.globalPosition, zones)
          : selected
          ? (d) => setState(
              () => _fillDx =
                  _grid!.globalToLocal(d.globalPosition).dx -
                  _axisWidth -
                  (zone.weekday! - .5) * _columnWidth,
            )
          : _editing
          ? (d) => _updateZoneSweep(d.globalPosition, zones)
          : null,
      onExtendEnd: _sweepingZones
          ? (_) => _endZoneSweep()
          : selected
          ? (_) => _finishFill()
          : _editing
          ? (_) => _endZoneSweep()
          : null,
    );
  }
}

/// The paint preview. **No blocked/"Overlap" state** — confirmed directly
/// ("never prevent action"): an overlapping paint is always allowed, and
/// the neighbours it lands on are pushed aside (or, only when one would be
/// fully swallowed, trimmed to [kZoneSliverMinutes]) on release. Showing a
/// refusal here would promise a block the commit path no longer performs.
class _Phantom extends StatelessWidget {
  const _Phantom({super.key, required this.theme, required this.title});
  final AmbleTheme theme;
  final String title;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: theme.colorSurfaceSecondary.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(theme.radiusMd),
    ),
    child: Center(
      child: RotatedBox(
        quarterTurns: 1,
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: theme.textCaption.copyWith(color: theme.colorTextSecondary),
        ),
      ),
    ),
  );
}

// Tasks / Zones switcher — was a private, 2-option-only `_TabSwitcher`/
// `_Segment` pair here; promoted to the shared `AppTabSwitch<T>`
// (core/widgets/app_tab_switch.dart) 2026-09-19 so the same segmented-
// control shape could be reused for other mutually-exclusive option rows
// without a second private copy. See that widget's own doc comment for
// the full history and `_zoneGridTabOptions` above for this screen's
// options list.

/// Which edge of the pending-zone marquee a resize handle drags.
///
/// [top]/[bottom] change the zone's start/end TIME; [left]/[right] change
/// how many WEEKDAYS it spans. See `_ZoneGridScreenState._resizeMarquee`.
enum _MarqueeEdge { top, bottom, left, right }

/// A [PanGestureRecognizer] that commits at half the normal touch slop, so
/// dragging the unsaved marquee's BODY beats the grid's own enclosing
/// vertical scrollable.
///
/// Same mechanism (and the same reasoning) as
/// `_EagerHorizontalDragRecognizer` in `zone_grid_block.dart` — see that
/// class for the full write-up. In short: both recognizers race the same
/// pointer and whichever passes its slop first takes the gesture, so a
/// plain `onPan*` here lost to the scroll view and the marquee never
/// moved at all. The screen's own `physics` gate cannot help, because the
/// flag it keys off (`_marqueeMoveOrigin`) is set by the very `onStart`
/// that was losing.
///
/// Scoped to the marquee's own rectangle, deliberately: the rest of the
/// grid keeps ordinary scrolling while a marquee is on screen, which is
/// the requested "tap and move > then should just be scroll" behaviour.
class _EagerPanRecognizer extends PanGestureRecognizer {
  _EagerPanRecognizer({super.debugOwner});

  /// Claims the pointer the instant it lands, rather than waiting to
  /// out-race the scrollable past touch slop.
  ///
  /// Lowering the slop threshold (the approach
  /// `_EagerHorizontalDragRecognizer` uses, and which works there) is NOT
  /// enough here: that one only has to beat a VERTICAL recognizer on a
  /// horizontal movement, so the two cross their thresholds at clearly
  /// different times. This recognizer is a PAN competing with the scroll
  /// view on the very same axis, so a vertical drag satisfies both at
  /// essentially the same moment and the arena's own ordering decides —
  /// which the scrollable won every time, leaving the marquee immovable.
  ///
  /// Declaring victory in `addAllowedPointer` is safe precisely because
  /// this recognizer is scoped to the marquee's own rectangle: a touch
  /// that lands there is unambiguously aimed at the marquee, never at the
  /// grid behind it. Everywhere else on the grid keeps ordinary scrolling.
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// One resize dot on the pending-zone marquee — the four-sided
/// counterpart to `ResizeHandle` (`features/timeline/resize_handle.dart`),
/// which only ever needed top/bottom and so wires vertical drags only.
///
/// Deliberately the SAME visual as that widget's own dot (a `spacingSm`
/// `colorAccent` circle) so "this edge is draggable" reads identically on
/// a zone marquee and on a task pill. The gesture differs: this one takes
/// pan (both axes) rather than a vertical drag, since the same widget
/// serves horizontal edges too.
///
/// Positioned by the caller at an edge's own midpoint — centred on the
/// boundary via [FractionalTranslation], per the request that dots sit
/// "in the middle of the marque horz middle and vert middle."
class _MarqueeResizeHandle extends StatelessWidget {
  const _MarqueeResizeHandle({
    required this.theme,
    required this.onDrag,
    required this.onDragEnd,
    required this.vertical,
    required this.alignment,
  });

  final AmbleTheme theme;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;

  /// Whether this handle drags along the vertical axis (a top/bottom
  /// edge, changing time) or the horizontal one (a left/right edge,
  /// changing the weekday span).
  final bool vertical;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    // An AXIS-SPECIFIC recognizer, never `onPan*`. The grid scrolls
    // vertically and `ZoneGridBlock` already claims both axes for its own
    // move/extend drags, so a pan recognizer here loses the arena to the
    // scrollable and the handle silently takes no drags at all (observed
    // directly: the dots rendered and hit-tested fine, but the callback
    // never fired once). Declaring the ONE axis this edge actually needs
    // is what `ZoneGridBlock` itself does, for exactly this reason.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: vertical ? (d) => onDrag(d.globalPosition) : null,
      onVerticalDragUpdate: vertical ? (d) => onDrag(d.globalPosition) : null,
      onVerticalDragEnd: vertical ? (_) => onDragEnd() : null,
      onVerticalDragCancel: vertical ? onDragEnd : null,
      onHorizontalDragStart: vertical ? null : (d) => onDrag(d.globalPosition),
      onHorizontalDragUpdate: vertical ? null : (d) => onDrag(d.globalPosition),
      onHorizontalDragEnd: vertical ? null : (_) => onDragEnd(),
      onHorizontalDragCancel: vertical ? null : onDragEnd,
      // A generous invisible touch area around a small visible dot —
      // the same target-vs-visual split `ResizeHandle` documents, sized
      // to `spacingMinTapTarget` so these stay grabbable on a dense grid.
      child: SizedBox(
        width: theme.spacingMinTapTarget,
        height: theme.spacingMinTapTarget,
        child: Center(
          child: Transform.translate(
            offset:
                Offset(-alignment.x, -alignment.y) *
                ResizeHandleDot.edgeInset(theme),
            child: ResizeHandleDot(theme: theme),
          ),
        ),
      ),
    );
  }
}
