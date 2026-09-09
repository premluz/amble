import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';

/// The small mode's starting/minimum height fraction.
///
/// History, since this value has moved twice on direct feedback: "a
/// small one, a 25% of screen" originally, then revised DOWN ("should be
/// even smaller that [the] sheet") to the least the panel's own content
/// could occupy — and now back UP, because that minimum was achieved
/// partly by letting the content scroll, which was reported as wrong:
/// "sheet should be larger height so there is not scrolling of content."
///
/// So this is now sized so the whole panel — header row, Name field, and
/// the template chip strip — fits WITHOUT the inner scroll view ever
/// engaging on an ordinary phone portrait viewport. The scroll view is
/// still there as a defensive floor for genuinely short viewports (see
/// `QuickCreateOverlay`), but it must not be what makes the normal case
/// fit. Raising this is the correct fix if content is ever added to the
/// panel; letting it scroll is not.
const quickCreateSheetMinFraction = 0.34;

/// Drives the height of `QuickCreateOverlay`'s own small-to-near-full
/// panel (`lib/features/timeline/quick_create_overlay.dart`) — requested
/// directly: tap empty Timeline space opens "a small sheet with a task
/// name input without the keyboard opened... a little handle in the
/// middle that the user can extend to near full size add sheet."
///
/// **Not** used to size a pushed `Navigator` route — an earlier version
/// of this feature did exactly that (a `QuickCreateSheetShell` widget
/// wrapping the pushed route's content), and it was confirmed broken by
/// direct testing: Flutter's `Navigator` unconditionally wraps every
/// route BELOW the topmost one in an `AbsorbPointer`, regardless of
/// `barrierColor`/`opaque` — so a pushed route can never leave Timeline
/// (and the draggable placeholder pill on it) interactive underneath it.
/// The overlay that now owns this controller lives directly in
/// `TimelineScreen`'s own widget tree instead, with no `Navigator`
/// involved at all until the user actually expands past the threshold —
/// see `quick_create_overlay.dart`'s own doc comment for the promotion
/// step, which is what pushes the real, ordinary
/// `showTaskDetailSheet` route once expansion completes.
class QuickCreateSheetHeightController extends ChangeNotifier {
  QuickCreateSheetHeightController({required double initialFraction})
    : _fraction = initialFraction;

  double _fraction;
  double get fraction => _fraction;

  bool _expanded = false;
  bool get expanded => _expanded;

  /// How far below [quickCreateSheetMinFraction] a drag has to pull
  /// before it counts as "drag down to close" rather than just settling
  /// back to the small height — requested directly ("the sheet should
  /// also be closing with this handle that expands it"). Expressed on
  /// the same absolute-fraction scale as [fraction] itself; a drag that
  /// only dips slightly below the floor (finger overshoot) still snaps
  /// back to small via [settle], matching a real bottom sheet's own
  /// "small nudge doesn't dismiss it" feel.
  static const _closeThreshold = 0.06;

  /// How far ABOVE the small floor a drag has to reach before releasing
  /// expands rather than snapping back. Deliberately a small absolute
  /// step, NOT the midpoint between small and full — reported directly
  /// as "difficult to do": a midpoint rule made expansion require
  /// dragging roughly half the screen, where Android's own non-modal
  /// bottom sheet expands from a short pull or a flick. Paired with
  /// [_expandVelocity] below so a quick upward flick expands regardless
  /// of how far it actually travelled.
  static const _expandThreshold = 0.06;

  /// Pixels/second of upward drag velocity that expands (or downward
  /// that closes) on release regardless of distance — the "flick"
  /// half of Android's own bottom-sheet settle rule. Flutter's own
  /// `kMinFlingVelocity` (50) is the floor for what counts as a fling at
  /// all; this is deliberately a bit above it so a slow, deliberate
  /// re-position doesn't read as a flick.
  static const _expandVelocity = 300.0;

  void updateFraction(double fraction) {
    // Allowed to go BELOW the small floor now (down to 0), unlike the
    // expand side which stays clamped at 1.0 — the space below the floor
    // is what [settle] reads to decide whether this drag meant "close."
    _fraction = fraction.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Snaps to whichever of the three outcomes the drag implies: close
  /// (returns true — the caller, `QuickCreateOverlay`, is responsible
  /// for actually tearing the draft down), expand, or settle back to the
  /// small floor. Called on the handle's own drag-end.
  ///
  /// [velocity] is the release velocity in pixels/second on the vertical
  /// axis (negative = upward, matching Flutter's own screen coordinates).
  /// A fast enough flick decides the outcome on its own, ignoring how
  /// far the drag actually moved — that velocity path is what makes a
  /// short upward flick expand the sheet, per direct report that
  /// expanding was "difficult to do."
  bool settle({double velocity = 0}) {
    // Flick wins outright, in whichever direction it went.
    if (velocity <= -_expandVelocity) {
      expand();
      return false;
    }
    if (velocity >= _expandVelocity) return true;

    if (_fraction < quickCreateSheetMinFraction - _closeThreshold) {
      return true;
    }
    _expanded = _fraction >= quickCreateSheetMinFraction + _expandThreshold;
    _fraction = _expanded ? 1.0 : quickCreateSheetMinFraction;
    notifyListeners();
    return false;
  }

  /// Expands straight to full — called when the handle's drag reaches the
  /// full-height target.
  void expand() {
    _expanded = true;
    _fraction = 1.0;
    notifyListeners();
  }
}

/// The drag handle itself — rendered by `QuickCreateOverlay` at the top
/// of its small panel. Visual style matches `ResizeHandle`'s own bar
/// (`lib/features/timeline/resize_handle.dart`) for a consistent "this is
/// draggable" affordance across the app, though this widget lives here
/// rather than reusing that one directly — its own drag drives a
/// [QuickCreateSheetHeightController], not a task/zone resize callback
/// triple, a different enough contract to not force a shared signature
/// onto both.
class QuickCreateSheetHandle extends StatelessWidget {
  const QuickCreateSheetHandle({
    super.key,
    required this.theme,
    required this.controller,
    required this.viewportHeight,
    required this.onCloseRequested,
  });

  final AmbleTheme theme;
  final QuickCreateSheetHeightController controller;

  /// Needed to convert a drag's pixel delta into the same fraction space
  /// the caller's own height-clamp box animates — passed down rather
  /// than re-derived via `MediaQuery` here, so both stay in exact
  /// agreement.
  final double viewportHeight;

  /// Fired when a drag ends far enough below the small floor to count as
  /// "drag down to close" (see [QuickCreateSheetHeightController.settle]'s
  /// own doc comment for the threshold) — requested directly. The
  /// caller (`QuickCreateOverlay`) owns actually tearing the draft down;
  /// this widget only reports the gesture.
  final VoidCallback onCloseRequested;

  @override
  Widget build(BuildContext context) {
    final fullHeight = viewportHeight - theme.spacingXl;
    final minHeight = viewportHeight * quickCreateSheetMinFraction;
    final travel = fullHeight - minHeight;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (travel <= 0) return;
        // `details.delta.dy / travel` is a 0..1 ratio of the real pixel
        // travel between the two heights; `controller.fraction` lives on
        // the ABSOLUTE [quickCreateSheetMinFraction, 1.0] scale (see its
        // own doc comment), so the ratio must be scaled up to match
        // before subtracting, or a full-height drag would move the
        // fraction by only `1.0 - quickCreateSheetMinFraction` instead of
        // the full range.
        final fractionRange = 1.0 - quickCreateSheetMinFraction;
        controller.updateFraction(
          controller.fraction - (details.delta.dy / travel) * fractionRange,
        );
      },
      onVerticalDragEnd: (details) {
        // Velocity forwarded so a short upward FLICK expands without
        // needing to drag most of the way — see the controller's own
        // `settle`/`_expandVelocity` doc comments. Reported directly as
        // "difficult to do" before this.
        if (controller.settle(velocity: details.velocity.pixelsPerSecond.dy)) {
          onCloseRequested();
        }
      },
      behavior: HitTestBehavior.opaque,
      // Sizes to whatever box the caller gives it (it is `Positioned
      // .fill`ed inside the sheet's header row) rather than imposing a
      // height of its own — the bar is only the visual affordance, while
      // the whole surrounding row is the hit target, so the drag catches
      // the way Android's own non-modal bottom sheet header does rather
      // than demanding a precise hit on a hairline.
      child: Align(
        child: Container(
          width: theme.spacingXl * 1.2,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorTextSecondary,
            borderRadius: BorderRadius.circular(theme.radiusSm),
          ),
        ),
      ),
    );
  }
}
