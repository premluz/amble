import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_subtle_icon_button.dart';
import '../../core/widgets/app_floating_create_button.dart';
import '../../core/widgets/app_top_scroll_fade.dart';
import '../../core/widgets/app_undo_toast.dart';
import '../../shared/models/zone.dart';
import '../../shared/providers/zone_providers.dart';
import '../../shared/services/zone_cascade_reschedule.dart';
import '../../shared/services/zone_group_move.dart';
import '../timeline/edit_mode_provider.dart';
import '../timeline/edit_selection_provider.dart';
import '../timeline/timeline_screen.dart';
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
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(builder: (_) => ZoneGridScreen(initialTab: initialTab)),
);

const _pixelsPerMinute = 44.0 / 60;

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
const _gridHeight = 1440 * _pixelsPerMinute;

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
/// swaps which one is visible. `TimelineScreen` is rendered with
/// `showHeader: false` so its own Edit-Mode-collapsed header (just a
/// close button) doesn't duplicate this screen's own top row.
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
  bool _editing = false, _saving = false;
  late ZoneGridTab _tab = widget.initialTab;
  ZonePaintSelection? _paint;
  Offset? _paintOrigin;
  // Captured in `build` (below) rather than read via `ref` inside
  // `dispose` — confirmed the hard way: `ConsumerState.ref.read` throws
  // "Using ref when a widget is about to or has been unmounted is
  // unsafe" once called from `dispose`, exactly as its own error message
  // says to do instead ("save the provider state in a field").
  ProviderContainer? _container;
  Offset? _downGlobal;
  bool _pointerCancelled = false;
  NewZoneTarget? _pending;
  Zone? _fillSource;
  double _fillDx = 0;
  ZoneGroupGestureKind? _moveKind;
  double _moveDy = 0;

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
    if (container != null && container.read(editModeEnabledProvider)) {
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
      _pending = _target(paint);
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
      _pending = null;
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
    if (_saving || _pending != null) return;
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
      _pending = _target(paint);
    });
    _scrollPendingIntoView(start);
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
    setState(() {
      _moveKind = null;
      _moveDy = 0;
    });
    if (kind == null || delta == 0) return;
    final selection = ref.read(zoneEditSelectionProvider);
    final moves = <ZoneMove>[];
    for (final z in zones.where((z) => selection.contains(z.id))) {
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
          // Only this zone's OWN weekday column can collide with it —
          // weekly placements on other days are independent windows.
          otherZones: zones
              .where(
                (o) =>
                    o.id != z.id &&
                    o.weekday == z.weekday &&
                    !selection.contains(o.id),
              )
              .toList(),
          tasksByZoneId: const {},
        ),
      );
    }
    if (moves.isEmpty) return;
    await _write(
      () => ref.read(zoneListProvider.notifier).commitZoneCascade(moves),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    _container = ProviderScope.containerOf(context);
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
      return Scaffold(
        backgroundColor: theme.colorSurfacePrimary,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(theme.spacingMd),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabSwitcher(
                        theme: theme,
                        tab: _tab,
                        onChanged: _switchTab,
                      ),
                    ),
                    SizedBox(width: theme.spacingSm),
                    AppSubtleIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: TimelineScreen(
                  mode: TimelineDisplayMode.spatial,
                  showHeader: false,
                ),
              ),
            ],
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
    return Scaffold(
      backgroundColor: theme.colorSurfacePrimary,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(theme.spacingMd),
                  child: Row(
                    children: [
                      // Tasks / Zones tab chrome — 2026-09-17, was "Events" /
                      // "Zones" with Events reserved and non-interactive; see
                      // `zone_grid_tab.dart`'s own doc comment for the rename.
                      Expanded(
                        child: _TabSwitcher(
                          theme: theme,
                          tab: _tab,
                          onChanged: _switchTab,
                        ),
                      ),
                      SizedBox(width: theme.spacingSm),
                      AppSubtleIconButton(
                        icon: _editing
                            ? Icons.check_rounded
                            : Icons.edit_outlined,
                        tooltip: _editing ? 'Finish editing' : 'Edit zones',
                        onTap: () {
                          _cancelPaint();
                          ref.read(zoneEditSelectionProvider.notifier).clear();
                          setState(() => _editing = !_editing);
                        },
                      ),
                      SizedBox(width: theme.spacingSm),
                      AppSubtleIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close zones',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                if (selected.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: theme.spacingMd),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${selected.length} selected',
                            style: theme.textCaption,
                          ),
                        ),
                        if (selected.length == 1)
                          AppSubtleIconButton(
                            icon: Icons.tune_rounded,
                            tooltip: 'Edit placement',
                            onTap: () {
                              final zone = zones
                                  .where((z) => selected.contains(z.id))
                                  .firstOrNull;
                              if (zone != null) {
                                showZoneFormScreen(context, zone: zone);
                              }
                            },
                          ),
                        AppSubtleIconButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Remove placements',
                          onTap: () => _write(() async {
                            for (final id in selected.toList()) {
                              await ref
                                  .read(zoneListProvider.notifier)
                                  .deleteZone(id);
                            }
                            ref
                                .read(zoneEditSelectionProvider.notifier)
                                .clear();
                          }),
                        ),
                        AppSubtleIconButton(
                          icon: Icons.deselect_rounded,
                          tooltip: 'Clear selection',
                          onTap: () => ref
                              .read(zoneEditSelectionProvider.notifier)
                              .clear(),
                        ),
                      ],
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
                        physics:
                            _editing ||
                                _paintOrigin != null ||
                                _fillSource != null ||
                                _moveKind != null
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
                                      onPointerDown: (e) {
                                        _downGlobal = e.position;
                                        _pointerCancelled = false;
                                      },
                                      onPointerCancel: (_) {
                                        _pointerCancelled = true;
                                        _cancelPaint();
                                      },
                                      child: GestureDetector(
                                        key: const ValueKey(
                                          'zone-paint-surface',
                                        ),
                                        behavior: HitTestBehavior.opaque,
                                        onTapUp: _tapEmpty,
                                        onLongPressStart: !_editing
                                            ? (d) =>
                                                  _startPaint(d.globalPosition)
                                            : null,
                                        onLongPressMoveUpdate: !_editing
                                            ? (d) =>
                                                  _updatePaint(d.globalPosition)
                                            : null,
                                        onLongPressEnd: !_editing
                                            ? (_) => _endPaint()
                                            : null,
                                        onLongPressCancel: !_editing
                                            ? _cancelPaint
                                            : null,
                                        onPanStart: _editing
                                            ? (d) => _startPaint(
                                                _downGlobal ?? d.globalPosition,
                                              )
                                            : null,
                                        onPanUpdate: _editing
                                            ? (d) =>
                                                  _updatePaint(d.globalPosition)
                                            : null,
                                        onPanEnd: _editing
                                            ? (_) => _endPaint()
                                            : null,
                                        onPanCancel: _editing
                                            ? _cancelPaint
                                            : null,
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
                                                  (_scroll.offset - d.delta.dy)
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
                                      width: _axisWidth - theme.spacingSm * 2,
                                      child: IgnorePointer(
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
                                          style: theme.textCaption.copyWith(
                                            color: theme.colorTextTertiary,
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
                                          color: theme.colorBorder.withValues(
                                            alpha: .25,
                                          ),
                                        ),
                                      ),
                                    ),
                                  for (var day = 1; day <= 7; day++)
                                    Positioned(
                                      left: _axisWidth + (day - 1) * width,
                                      width: width,
                                      top: 0,
                                      bottom: 0,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          for (final zone in zones.where(
                                            (z) => z.weekday == day,
                                          ))
                                            _block(
                                              zone,
                                              zones,
                                              theme,
                                              selected.contains(zone.id),
                                            ),
                                        ],
                                      ),
                                    ),
                                  if (preview != null) ...[
                                    Positioned(
                                      left:
                                          _axisWidth +
                                          (preview.firstDay - 1) * width,
                                      width:
                                          (preview.lastDay -
                                              preview.firstDay +
                                              1) *
                                          width,
                                      top:
                                          preview.startMinutes *
                                          _pixelsPerMinute,
                                      height:
                                          (preview.endMinutes -
                                              preview.startMinutes) *
                                          _pixelsPerMinute,
                                      child: IgnorePointer(
                                        child: DecoratedBox(
                                          key: const ValueKey(
                                            'zone-paint-selection',
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorAccent.withValues(
                                              alpha: .09,
                                            ),
                                            border: Border.all(
                                              color: theme.colorAccent
                                                  .withValues(alpha: .6),
                                              width: theme.borderWidthHairline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    for (final day in preview.weekdays)
                                      if (_fillSource?.weekday != day)
                                        Positioned(
                                          left:
                                              _axisWidth +
                                              (day - 1) * width +
                                              theme.spacingXs,
                                          width: width - 2 * theme.spacingXs,
                                          top:
                                              preview.startMinutes *
                                                  _pixelsPerMinute +
                                              theme.spacingXs / 2,
                                          height: math.max(
                                            2,
                                            (preview.endMinutes -
                                                        preview.startMinutes) *
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
                                    Positioned(
                                      left: _axisWidth,
                                      top: math.max(
                                        0,
                                        preview.startMinutes *
                                                _pixelsPerMinute -
                                            theme.spacingLg,
                                      ),
                                      child: IgnorePointer(
                                        child: Text(
                                          '${_time(preview.startMinutes)} – ${_time(preview.endMinutes)}',
                                          style: theme.textCaption.copyWith(
                                            color: theme.colorAccent,
                                          ),
                                        ),
                                      ),
                                    ),
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
                  _pending = _target(paint);
                });
                _scrollPendingIntoView(start);
              },
            ),
          if (_pending case final target?)
            NewZoneSheet(
              key: ValueKey(target),
              target: target,
              onDismiss: _cancelPaint,
            ),
        ],
      ),
    );
  }

  Widget _block(Zone zone, List<Zone> zones, AmbleTheme theme, bool selected) {
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
    });
    void update(DragUpdateDetails d) => setState(() => _moveDy += d.delta.dy);
    return ZoneGridBlock(
      key: ValueKey(zone.id),
      theme: theme,
      zone: zone,
      top: start * _pixelsPerMinute,
      height: math.max(5, (end - start) * _pixelsPerMinute),
      isSelected: selected,
      wiggleEnabled: false,
      liveStartMinutes: selected && _moveKind != null ? start : null,
      liveEndMinutes: selected && _moveKind != null ? end : null,
      onTap: () {
        setState(() => _editing = true);
        ref.read(zoneEditSelectionProvider.notifier).toggle(zone.id);
      },
      onMoveStart: selected ? (_) => begin(ZoneGroupGestureKind.move) : null,
      onMoveUpdate: selected ? update : null,
      onMoveEnd: selected ? (_) => _finishMove(zones) : null,
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
      onExtendStart: selected
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
          : null,
      onExtendUpdate: selected
          ? (d) => setState(
              () => _fillDx =
                  _grid!.globalToLocal(d.globalPosition).dx -
                  _axisWidth -
                  (zone.weekday! - .5) * _columnWidth,
            )
          : null,
      onExtendEnd: selected ? (_) => _finishFill() : null,
    );
  }
}

String _time(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

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

/// Tasks / Zones, per the reviewed mockup — restored on direct request
/// after a rewrite replaced it with a "Your usual week" heading.
///
/// **2026-09-17 — both segments now wired.** Was "Events" / "Zones" with
/// Events genuinely inert (no `onTap` at all, reserved for a future
/// calendar-events grid never built) — see `zone_grid_tab.dart`'s own
/// doc comment for the rename/repurposing.
class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({
    required this.theme,
    required this.tab,
    required this.onChanged,
  });
  final AmbleTheme theme;
  final ZoneGridTab tab;
  final ValueChanged<ZoneGridTab> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: theme.colorSurfaceSecondary,
      borderRadius: BorderRadius.circular(theme.radiusLg),
    ),
    child: Row(
      children: [
        Expanded(
          child: _Segment(
            theme: theme,
            label: 'Tasks',
            selected: tab == ZoneGridTab.tasks,
            onTap: () => onChanged(ZoneGridTab.tasks),
          ),
        ),
        Expanded(
          child: _Segment(
            theme: theme,
            label: 'Zones',
            selected: tab == ZoneGridTab.zones,
            onTap: () => onChanged(ZoneGridTab.zones),
          ),
        ),
      ],
    ),
  );
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final AmbleTheme theme;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: EdgeInsets.symmetric(vertical: theme.spacingSm),
      decoration: selected
          ? BoxDecoration(
              color: theme.colorSurfacePrimary,
              borderRadius: BorderRadius.circular(theme.radiusLg),
            )
          : null,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textBody.copyWith(
          color: onTap == null
              ? theme.colorTextTertiary
              : theme.colorTextPrimary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    ),
  );
}
