import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../core/widgets/app_sheet_handle.dart';
import '../../core/widgets/app_sheet_header.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_segmented_time_field.dart';
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

  /// Drag-to-close accumulator for the header's own handle — same
  /// "distance OR velocity" threshold `quick_capture_sheet.dart`'s
  /// identical handle already uses (2026-09-24, added here to match: this
  /// sheet previously had no drag-to-close gesture at all, unlike every
  /// other `AppSheetHeader` caller).
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
            child: SingleChildScrollView(
              padding: EdgeInsets.all(theme.spacingMd),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close left, primary action right — unified with the
                  // Timeline quick-create task sheet's own header row
                  // (`QuickCreateOverlay`), requested directly. No title
                  // text here, matching that sheet, which also has none.
                  //
                  // `handle` added 2026-09-24 — this sheet previously had
                  // no drag-to-close gesture at all, unlike every other
                  // `AppSheetHeader` caller. Same gesture shape
                  // `quick_capture_sheet.dart`'s identical handle uses
                  // (distance-or-velocity threshold), calling `_close()`
                  // instead of `Navigator.pop` — this sheet is an in-tree
                  // widget, not a route.
                  AppSheetHeader(
                    theme: theme,
                    onClose: _saving ? () {} : _close,
                    handle: GestureDetector(
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
                      // Top-aligned with a small inset, matching the
                      // reference `AppSheetHandle` positioning exactly —
                      // see `quick_capture_sheet.dart`'s own identical
                      // handle for why (reads as a separate drag
                      // affordance, not one more control on the buttons'
                      // own centre line).
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: theme.spacingSm),
                          child: AppSheetHandle(theme: theme),
                        ),
                      ),
                    ),
                    trailing: AppButton(
                      label: 'Add zone',
                      size: AppButtonSize.md,
                      shape: AppButtonShape.pill,
                      isLoading: _saving,
                      onPressed: _save,
                    ),
                  ),
                  SizedBox(height: theme.spacingMd),
                  // Bare — the shared style for every entity's name.
                  AppTextField(
                    controller: _title,
                    label: 'Add title',
                    variant: AppTextFieldVariant.bare,
                  ),
                  if (names.isNotEmpty) ...[
                    SizedBox(height: theme.spacingSm),
                    Wrap(
                      spacing: theme.spacingXs,
                      runSpacing: theme.spacingXs,
                      children: [
                        for (final name in names)
                          AppPressFeedback(
                            onTap: () => setState(() {
                              _title.text = name.name;
                              _facetId = name.id;
                            }),
                            borderRadius: BorderRadius.circular(theme.radiusMd),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: theme.spacingSm,
                                vertical: theme.spacingXs,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorSurfaceSecondary,
                                borderRadius: BorderRadius.circular(
                                  theme.radiusMd,
                                ),
                              ),
                              child: Text(name.name, style: theme.textCaption),
                            ),
                          ),
                      ],
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
        ),
      ),
    );
  }
}
