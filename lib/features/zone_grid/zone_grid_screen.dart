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
import '../timeline/edit_selection_provider.dart';
import '../zones/zone_form_screen.dart';
import 'new_zone_sheet.dart';
import 'zone_grid_block.dart';
import 'zone_grid_tab.dart';
import 'zone_paint_selection.dart';

Future<void> showZoneGridScreen(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const ZoneGridScreen()));

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

class ZoneGridScreen extends ConsumerStatefulWidget {
  const ZoneGridScreen({super.key});
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
  ZoneGridTab _tab = ZoneGridTab.zones;
  ZonePaintSelection? _paint;
  Offset? _paintOrigin;
  Offset? _downGlobal;
  bool _pointerCancelled = false;
  NewZoneTarget? _pending;
  Zone? _fillSource;
  double _fillDx = 0;
  ZoneGroupGestureKind? _moveKind;
  double _moveDy = 0;

  @override
  void dispose() {
    _edgeScroll?.cancel();
    _scroll.dispose();
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
                      // Events / Zones tab chrome, restored per direct request. Only
                      // Zones is built — Events stays genuinely non-interactive (no
                      // onTap at all), matching how this app treats an out-of-scope
                      // control elsewhere rather than a disabled-looking one that
                      // still swallows taps. See `zone_grid_tab.dart`.
                      Expanded(
                        child: _TabSwitcher(
                          theme: theme,
                          tab: _tab,
                          onChanged: (tab) => setState(() => _tab = tab),
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

/// Events / Zones, per the reviewed mockup — restored on direct request
/// after a rewrite replaced it with a "Your usual week" heading.
///
/// **Events is deliberately inert**: no `onTap` wired at all, rather than a
/// disabled-looking control that still intercepts taps. It's a parallel
/// grid for tasks/calendar events — a separate, comparably-sized feature.
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
            label: 'Events',
            selected: tab == ZoneGridTab.events,
            onTap: null,
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
