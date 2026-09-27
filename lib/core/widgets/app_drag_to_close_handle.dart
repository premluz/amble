import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_sheet_handle.dart';

/// Live drag state behind [AppDragToCloseHandle] — a sheet creates one,
/// passes it to the handle, and reads [offset] in its own `build` (via an
/// `AnimatedBuilder`/`ListenableBuilder`) to translate its content by that
/// many pixels as the drag happens.
///
/// **The responsive/non-responsive toggle lives on [AppDragToCloseHandle]
/// itself** (its own `responsive` parameter), not here — this controller
/// always tracks the real drag distance and always resolves the same
/// close/settle decision on release, regardless of which mode the handle
/// is in. What differs is only whether the handle publishes [offset] as
/// the drag happens (responsive) or holds it back until release
/// (non-responsive, the previous behavior every existing caller had).
/// Keeping the tracking/decision logic unconditional and gating only the
/// PUBLISHING means both modes share one threshold implementation instead
/// of two copies that could drift apart.
class AppDragToCloseController extends ChangeNotifier {
  double _offset = 0;

  /// Current live drag offset in pixels — positive is downward (toward
  /// close), matching the same sign convention `DragUpdateDetails.delta.dy`
  /// already uses. Zero at rest, whether idle or mid-settle-animation once
  /// [AppDragToCloseHandle] has finished animating back.
  double get offset => _offset;

  void _setOffset(double value) {
    if (_offset == value) return;
    _offset = value;
    notifyListeners();
  }
}

/// The drag-to-close gesture behind a sheet's own handle bar — extracted
/// from `quick_capture_sheet.dart`'s and `new_zone_sheet.dart`'s own
/// near-identical hand-rolled `GestureDetector`s (both: accumulate
/// `details.delta.dy` silently, decide close-or-not only once the finger
/// lifts). See docs/DESIGN_SYSTEM.md's "Sheets > Drag handle" section for
/// the full account of the two modes this documents.
///
/// **Responsive by default** (requested directly: "the handle pattern in
/// sheets should be responsive when grabbed to drag, similar to quick
/// create task on timeline... new zone doesn't [respond] and at some
/// point triggers close... let's keep second option as toggle of this
/// pattern, default is drag responsive"). Responsive means the sheet
/// visually follows the finger in real time via [controller]'s own
/// [AppDragToCloseController.offset] — the same expectation
/// `QuickCreateSheetHandle`/`QuickCreateSheetHeightController` already set
/// for the Timeline's own quick-create task sheet, which this generalizes
/// rather than duplicates (that widget's own fraction/small/minimised
/// system is a SEPARATE, richer feature for a sheet with multiple sizes;
/// this handle is for the simpler "one size, drag down enough and it
/// closes" case every OTHER handle-bearing sheet actually needs).
///
/// `responsive: false` restores the previous behavior exactly: the drag
/// is tracked but never published to [controller], so the sheet sits
/// visually still until release, then only [onClose] (or nothing) fires
/// based on the same distance/velocity threshold.
class AppDragToCloseHandle extends StatefulWidget {
  const AppDragToCloseHandle({
    super.key,
    required this.theme,
    required this.controller,
    required this.onClose,
    this.responsive = true,
    this.closeDistance,
    this.closeVelocity = 800.0,
  });

  final AmbleTheme theme;
  final AppDragToCloseController controller;

  /// Fired once a release resolves to "close" — the caller owns actually
  /// tearing the sheet down (matching `QuickCreateSheetHandle
  /// .onCloseRequested`'s own contract), this widget only reports the
  /// gesture.
  final VoidCallback onClose;

  /// Whether the sheet visually follows the finger during the drag (the
  /// default) or stays still until release, matching every existing
  /// caller's previous behavior. See this class's own doc comment.
  final bool responsive;

  /// How far down the handle must be dragged before a release counts as
  /// "close" — defaults to `theme.spacingXl`, matching both existing
  /// callers' own previous threshold exactly, so adopting this widget in
  /// place of their hand-rolled gesture changes nothing about WHEN a drag
  /// closes, only whether it's visually responsive along the way.
  final double? closeDistance;

  /// Pixels/second of downward velocity that closes on release regardless
  /// of distance — the "flick" half of the threshold, matching both
  /// existing callers' own previous `800.0` exactly.
  final double closeVelocity;

  @override
  State<AppDragToCloseHandle> createState() => _AppDragToCloseHandleState();
}

class _AppDragToCloseHandleState extends State<AppDragToCloseHandle>
    with SingleTickerProviderStateMixin {
  double _dragDistance = 0;
  late final AnimationController _snapBack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1),
  );

  @override
  void dispose() {
    _snapBack.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _dragDistance += details.delta.dy;
    if (widget.responsive) {
      // Never follows the finger UPWARD past rest — this handle only ever
      // closes downward (there is no "drag up" state for a fixed-size
      // sheet to settle into, unlike `QuickCreateSheetHandle`'s own
      // three-state system), so a negative drag is clamped to zero rather
      // than letting the sheet visually lift above its own resting
      // position for no reason.
      widget.controller._setOffset(_dragDistance < 0 ? 0 : _dragDistance);
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    final distance = _dragDistance;
    final velocity = details.velocity.pixelsPerSecond.dy;
    _dragDistance = 0;
    final farEnough =
        distance > (widget.closeDistance ?? widget.theme.spacingXl);
    final fastEnough = velocity > widget.closeVelocity;
    if (farEnough || fastEnough) {
      widget.onClose();
      return;
    }
    // Not far/fast enough to close — snap any live-followed offset back
    // to rest. A no-op when `responsive` is false, since the controller's
    // offset never left zero in the first place.
    _animateBackToRest();
  }

  void _animateBackToRest() {
    final from = widget.controller.offset;
    if (from == 0) return;
    _snapBack
      ..stop()
      ..duration = widget.theme.motionFast
      ..reset();
    final animation = CurvedAnimation(
      parent: _snapBack,
      curve: widget.theme.curveStandard,
    );
    void listener() {
      widget.controller._setOffset(from * (1 - animation.value));
    }

    animation.addListener(listener);
    _snapBack.forward().whenComplete(() {
      animation.removeListener(listener);
      widget.controller._setOffset(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      // Top-aligned with a small top inset, matching both existing
      // callers' own identical positioning exactly (see
      // `QuickCreateSheetHandle`'s own doc comment on why: it reads as a
      // separate drag affordance rather than one more control on a
      // header row's own centre line).
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: widget.theme.spacingSm),
          child: AppSheetHandle(theme: widget.theme),
        ),
      ),
    );
  }
}
