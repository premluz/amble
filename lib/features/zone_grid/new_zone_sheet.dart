import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_badge_chip.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_chip_strip.dart';
import '../../core/widgets/app_sheet_handle.dart';
import '../../core/widgets/app_sheet_header.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_segmented_time_field.dart';
import '../../core/widgets/app_value_chip.dart' show AppValueChipSize;
import '../../shared/models/zone_facet.dart';
import '../../shared/providers/zone_providers.dart';
import '../../shared/providers/zone_facet_providers.dart';

class NewZoneTarget {
  const NewZoneTarget({
    required this.day,
    required this.startMinutes,
    required this.endMinutes,
    this.days,
  });
  final DateTime day;
  final int startMinutes, endMinutes;
  final Set<int>? days;
  Set<int> get weekdays => days ?? {day.weekday};
}

/// In-tree sheet: the selected area stays visible while naming it. Its height
/// is bounded by the keyboard-adjusted viewport, including large text sizes.
class NewZoneSheet extends ConsumerStatefulWidget {
  const NewZoneSheet({
    super.key,
    required this.target,
    required this.onDismiss,
  });
  final NewZoneTarget target;
  final VoidCallback onDismiss;
  @override
  ConsumerState<NewZoneSheet> createState() => _NewZoneSheetState();
}

class _NewZoneSheetState extends ConsumerState<NewZoneSheet>
    with SingleTickerProviderStateMixin {
  final _title = TextEditingController();
  @override
  void initState() {
    super.initState();
    _title.addListener(() {
      _facetId = null;
    });
    // Duration is set from `theme.motionSheetSlide` in
    // `didChangeDependencies` (the theme isn't reachable yet here) —
    // `vsync` is all `initState` can safely provide. Same shape
    // `QuickCreateOverlay`'s own `_entrance` uses.
    _entrance = AnimationController(vsync: this);
  }

  String? _facetId, _error;
  bool _saving = false;
  late int _start = widget.target.startMinutes;
  late int _end = widget.target.endMinutes;

  /// Drag-to-close accumulator for the sheet's own top handle — same
  /// "distance OR velocity" threshold `quick_capture_sheet.dart`'s
  /// identical handle already uses. Originally shared a row with
  /// [AppSheetHeader]'s close/trailing controls; that row is now at the
  /// BOTTOM of the sheet instead (requested directly), so this handle
  /// lives on its own at the top and carries the drag gesture itself.
  double _dragDistance = 0;

  /// The same one-shot entrance/exit controller `QuickCreateOverlay`'s
  /// own `_entrance` establishes for the identical "in-tree sheet, no
  /// route to hook a transition on" situation — see this class's own doc
  /// comment for why a real `AppSheetRoute` can't be used here.
  /// `TweenAnimationBuilder` (the widget's PREVIOUS entrance mechanism)
  /// cannot be reversed on demand, only re-triggered by changing its own
  /// target value, which is why this became a real `AnimationController`:
  /// closing needs to play the SAME motion backward, then defer the real
  /// dismiss until it finishes.
  late final AnimationController _entrance;
  bool _entranceStarted = false;

  /// Guards [_close] against firing twice (e.g. a second drag past the
  /// close threshold while the exit is already playing).
  bool _closing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    _entrance.duration = theme.motionSheetSlide;
    _entrance.forward();
  }

  /// Plays the exit animation, then defers to [widget.onDismiss] —
  /// requested directly alongside the same fix on `QuickCreateOverlay`
  /// ("wire exit"): this sheet closed exactly as abruptly as it opened,
  /// since `widget.onDismiss` used to remove it from the Zone Grid's own
  /// `Stack` on the very next frame (see `zone_grid_screen.dart`'s own
  /// `_cancelPaint`, called synchronously), giving no time for a reverse
  /// motion. Every existing call site (`onClose`/the handle's drag
  /// gesture/`_save`'s own success path) now routes through this instead
  /// of calling `widget.onDismiss` directly.
  void _close() {
    if (_closing) return;
    _closing = true;
    _entrance.reverse().whenComplete(() {
      if (!mounted) return;
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(zoneListProvider.notifier)
          .paintWeeklyZones(
            title: _title.text,
            facetId: _facetId,
            weekdays: widget.target.weekdays,
            startMinutes: _start,
            endMinutes: _end,
          );
      if (mounted) _close();
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is StateError
              ? error.message
              : error is ArgumentError
              ? '${error.message}'
              : 'Could not save. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final names = [...ref.watch(zoneFacetListProvider)]
      ..sort((a, b) => a.name.compareTo(b.name));
    return Positioned(
      left: 0,
      right: 0,
      // `bottom: 0`, not an offset that tries to "clear" the shell's
      // floating bottom dock — reported directly that an earlier version
      // of this fix still overlapped ("still bottom toolbar overlaps").
      // Root cause: `AppBottomDock` (`main.dart`) is a PERSISTENT shell
      // overlay painted AFTER (on top of) this screen's own routed
      // content, regardless of any offset applied here — no `Positioned`
      // value on this sheet could ever out-position a widget that always
      // paints later in a DIFFERENT, outer `Stack`. Fixed at the source
      // instead: `_zoneContextDock` now renders empty groups (so
      // `AppBottomDock` renders nothing) while `_pending != null` — see
      // that method's own doc comment. With the dock no longer drawing
      // anything while this sheet is open, this sheet is free to sit
      // flush against the screen's own bottom edge again, matching every
      // other in-tree/bottom sheet's own convention (`quick_capture_sheet
      // .dart` et al.).
      bottom: 0,
      // `motionSheetSlide`/`curveDecelerate` (2026-09-24, was
      // `motionFast`/a bare `spacingMd` nudge) — the same entrance timing
      // token every `AppSheet`-based sheet now uses. This sheet still
      // can't run through the real `AppSheetRoute`/`AppSheetMotion`
      // machinery (it's an in-tree `Positioned` sibling in the Zone
      // Grid's own `Stack`, not a pushed route — the Grid and the live
      // paint selection have to stay visible behind it while naming, per
      // this class's own doc comment above).
      //
      // `AnimatedBuilder` driven by `_entrance`, not `TweenAnimationBuilder`
      // (2026-09-24, second pass) — the earlier version used
      // `TweenAnimationBuilder`, which plays once toward a target value and
      // cannot be reversed on demand; wiring a real exit (`_close()`)
      // needed a real `AnimationController` to reverse.
      child: AnimatedBuilder(
        animation: _entrance,
        builder: (context, child) {
          final value = theme.curveDecelerate.transform(_entrance.value);
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, theme.spacingMd * (1 - value)),
              child: child,
            ),
          );
        },
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .62,
          ),
          // `colorSurfaceOverlay` — the top of the elevation ramp, matching
          // every other sheet in the app (see `AppSheet`). Requested directly.
          //
          // `radiusModal` (2026-09-23, was `radiusXl`) — the same rounding
          // unification pass that added `AppSheetHeader`: every other
          // modal-shaped surface (`AppSheet`, `StepScaffold`,
          // `QuickCreateOverlay`, `AppContextMenu`'s anchored popover) uses
          // `radiusModal` for its own top corner; this sheet's comment
          // already claimed to match "every other sheet in the app" but its
          // radius hadn't actually been updated to the shared token.
          decoration: BoxDecoration(
            color: theme.colorSurfaceOverlay,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.radiusModal),
            ),
            boxShadow: theme.shadowPane,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The drag-to-close handle, alone at the very top of the
                // sheet — moved OUT of AppSheetHeader's own row (see
                // below) so the sheet's outer content padding can drop
                // its top inset entirely: requested directly ("remove any
                // padding-top margin from sheet, header should have it").
                // This handle region now owns that inset itself
                // (`spacingSm`), rather than the whole scroll body being
                // pushed down by it.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) =>
                      _dragDistance += details.delta.dy,
                  onVerticalDragEnd: (details) {
                    final farEnough = _dragDistance > theme.spacingXl;
                    final fastEnough =
                        details.velocity.pixelsPerSecond.dy > 800;
                    _dragDistance = 0;
                    if (!_saving && (farEnough || fastEnough)) {
                      _close();
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: theme.spacingSm),
                    child: AppSheetHandle(theme: theme),
                  ),
                ),
                // Flexible (loose fit), NOT Expanded — this Column stays
                // `mainAxisSize.min` (matching every other Column in this
                // sheet) so the whole sheet still SHRINKS to fit short
                // content rather than always claiming the outer
                // Container's full `maxHeight` cap. Expanded is a
                // FlexFit.tight `Flexible` — it would have forced this
                // Column to `mainAxisSize.max` to make sense, which broke
                // exactly that shrink-to-content behavior (verified with a
                // throwaway size probe: a short-content sheet rendered at
                // the full 62%-of-screen cap instead of hugging its own
                // content). Flexible's default loose fit still caps at
                // the available space when content overflows it (the
                // scroll view absorbs the rest, no exception), while
                // shrinking freely below that cap when content is short.
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: theme.spacingMd),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bare — the shared style for every entity's name.
                        AppTextField(
                          controller: _title,
                          label: 'Add title',
                          variant: AppTextFieldVariant.bare,
                        ),
                        if (names.isNotEmpty) ...[
                          SizedBox(height: theme.spacingSm),
                          // AppChipStrip, not Wrap — requested directly
                          // ("the pills should be scrollable
                          // horizontally... we should make that scrolling
                          // same across usages... reuse that class from
                          // add task"): one scrollable line, the same
                          // shared strip mechanics `TemplateChipStrip`
                          // uses for the quick-create sheet's own template
                          // cards, rather than a second hand-rolled
                          // horizontal scroller. `edgeInset: 0` — unlike
                          // `TemplateChipStrip`'s own full-bleed caller,
                          // this strip already sits inside the sheet's own
                          // `spacingMd` side padding, so it needs no
                          // additional edge inset of its own.
                          //
                          // AppBadgeChip itself, not a hand-rolled
                          // Container — unified directly ("use app badge
                          // chip but we don't need icon now so this one
                          // without icon and filled"). `leading: null`
                          // (now supported — see that param's own doc
                          // comment) renders a text-only chip; `sm` for
                          // this dense multi-tag row, confirmed via
                          // AskUserQuestion over the widget's own `md`
                          // default.
                          AppChipStrip<ZoneFacet>(
                            items: names,
                            height: appButtonHeightFor(theme, AppButtonSize.sm),
                            itemSpacing: theme.spacingXs,
                            keyOf: (name) => ValueKey(name.id),
                            itemBuilder: (context, name) => AppBadgeChip(
                              theme: theme,
                              label: name.name,
                              size: AppValueChipSize.sm,
                              selected: _facetId == name.id,
                              onTap: () => setState(() {
                                _title.text = name.name;
                                _facetId = name.id;
                              }),
                            ),
                          ),
                        ],
                        SizedBox(height: theme.spacingMd),
                        Row(
                          children: [
                            Expanded(
                              child: AppSegmentedTimeField(
                                label: 'Start',
                                first: _start ~/ 60,
                                second: _start % 60,
                                firstMax: 23,
                                onChanged: (h, m) =>
                                    setState(() => _start = h * 60 + m),
                              ),
                            ),
                            SizedBox(width: theme.spacingSm),
                            Expanded(
                              child: AppSegmentedTimeField(
                                label: 'End',
                                first: _end ~/ 60,
                                second: _end % 60,
                                firstMax: 24,
                                onChanged: (h, m) =>
                                    setState(() => _end = h * 60 + m),
                              ),
                            ),
                          ],
                        ),
                        if (_error != null)
                          Padding(
                            padding: EdgeInsets.only(top: theme.spacingSm),
                            child: Text(
                              _error!,
                              style: theme.textCaption.copyWith(
                                color: theme.colorTextSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Close left, primary action right — at the BOTTOM of the
                // sheet now, requested directly against a reference
                // screenshot ("close and add at the bottom of the
                // sheet"). Still [AppSheetHeader] — reused for the exact
                // same close-button/trailing-button styling every other
                // sheet's header row uses (`quick_capture_sheet.dart`,
                // `new_section_sheet.dart`), just placed as this sheet's
                // last row instead of its first. `handle: null` since the
                // drag handle now lives on its own at the top of the
                // sheet, not sharing this row.
                //
                // No bottom inset here — requested directly ("the sheet
                // should not have same bottom padding as side, no margin
                // bottom"): this row sits flush against the sheet's own
                // bottom edge (inside `SafeArea`), rather than matching
                // the `spacingMd` side padding on every edge.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    theme.spacingMd,
                    theme.spacingSm,
                    theme.spacingMd,
                    0,
                  ),
                  child: AppSheetHeader(
                    theme: theme,
                    onClose: _saving ? () {} : _close,
                    trailing: AppButton(
                      label: 'Add zone',
                      size: AppButtonSize.md,
                      shape: AppButtonShape.pill,
                      isLoading: _saving,
                      onPressed: _save,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
