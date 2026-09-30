import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_sheet_handle.dart';

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
const quickCreateSheetMinFraction = 0.35;

/// The MINIMISED state's height fraction — the third of the sheet's three
/// states, below [quickCreateSheetMinFraction].
///
/// Requested directly against a reference screenshot: "when scrolled, we
/// need this state: just the title is shown, and there is this little
/// handle to expand or tap to expand. When tapped, it expands to this
/// mini sheet... So we need 3 states."
///
/// Sized to the handle plus one line of title text and nothing else —
/// deliberately not a fraction of the content, since the whole point is
/// that only the title survives. Reached by dragging the handle DOWN from
/// the small sheet (confirmed directly, in preference to collapsing on
/// timeline scroll), and left by tapping it or dragging back up.
const quickCreateSheetMinimisedFraction = 0.11;

/// Drives the height of `QuickCreateOverlay`'s own panel
/// (`lib/features/timeline/quick_create_overlay.dart`): small (where it
/// opens), minimised (the title alone), or closed. It never expands past
/// small — requested directly (2026-09-30): "we should not have expand
/// sheet to fill"; a drag up just settles back.
///
/// **Not** used to size a pushed `Navigator` route — an earlier version
/// of this feature did exactly that, and Flutter's `Navigator` wraps every
/// route BELOW the topmost one in an `AbsorbPointer`, so the Timeline (and
/// the draggable placeholder pill on it) could never stay interactive. The
/// overlay lives directly in `TimelineScreen`'s own widget tree instead.
class QuickCreateSheetHeightController extends ChangeNotifier {
  QuickCreateSheetHeightController({required double initialFraction})
    : _fraction = initialFraction;

  double _fraction;
  double get fraction => _fraction;

  /// Whether the sheet is in its MINIMISED state, where only the title and
  /// the handle show. See [quickCreateSheetMinimisedFraction].
  bool _minimised = false;
  bool get minimised => _minimised;

  /// How far below [quickCreateSheetMinimisedFraction] a drag has to pull
  /// before it counts as "drag down to close" rather than settling into
  /// the minimised state — requested directly ("the sheet should also be
  /// closing with this handle"). A drag that only dips slightly below the
  /// floor (finger overshoot) still snaps back via [settle].
  static const _closeThreshold = 0.06;

  /// How far BELOW the small floor a drag has to reach before releasing
  /// minimises rather than snapping back to small. A small absolute step,
  /// NOT the midpoint between the two floors: a midpoint rule made the
  /// gesture require dragging most of the way ("difficult to do").
  static const _minimiseThreshold = 0.06;

  /// Pixels/second of drag velocity that decides on release regardless of
  /// distance — the "flick" half of Android's own bottom-sheet settle rule,
  /// a bit above Flutter's `kMinFlingVelocity` (50) so a slow, deliberate
  /// re-position doesn't read as a flick.
  static const _flingVelocity = 300.0;

  /// Follows the finger, but never above the small height (no expanding);
  /// below the floor is allowed — [settle] reads it to decide on closing.
  void updateFraction(double fraction) {
    _fraction = fraction.clamp(0.0, quickCreateSheetMinFraction);
    notifyListeners();
  }

  /// Snaps to what the drag implies: close (returns true — the caller,
  /// `QuickCreateOverlay`, tears the draft down), minimise, or back to
  /// small. Called on the handle's own drag-end. [velocity] is the release
  /// velocity in pixels/second (negative = upward).
  bool settle({double velocity = 0}) {
    // Flick UP: back to small, from anywhere.
    if (velocity <= -_flingVelocity) {
      restoreToSmall();
      return false;
    }
    // Flick DOWN: small collapses to minimised; minimised closes.
    if (velocity >= _flingVelocity) {
      if (_minimised) return true;
      minimise();
      return false;
    }

    // Below the minimised floor by a real margin — close.
    if (_fraction < quickCreateSheetMinimisedFraction - _closeThreshold) {
      return true;
    }
    // A real pull below the small floor minimises; anything shallower
    // settles back to small.
    if (_fraction < quickCreateSheetMinFraction - _minimiseThreshold) {
      minimise();
    } else {
      restoreToSmall();
    }
    return false;
  }

  /// Collapses to the MINIMISED state, where only the title shows.
  void minimise() {
    _minimised = true;
    _fraction = quickCreateSheetMinimisedFraction;
    notifyListeners();
  }

  /// Back to the SMALL sheet — the state the overlay opens in. Called by
  /// a tap on the minimised sheet ("when tapped, it expands to this mini
  /// sheet, not a minimized sheet, but a small sheet as it is at the
  /// beginning") as well as by an upward drag from minimised.
  void restoreToSmall() {
    _minimised = false;
    _fraction = quickCreateSheetMinFraction;
    notifyListeners();
  }
}

/// The drag handle itself — rendered by `QuickCreateOverlay` at the top
/// of its small panel. Draws the bar via the shared [AppSheetHandle] (see
/// its own doc comment for the exact token values), wrapped in this
/// widget's own gesture handling rather than reusing a bigger shared
/// widget for the drag itself — its own drag drives a
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
    // The MINIMISED floor, matching `QuickCreateOverlay`'s own height
    // math exactly. These two must agree: the overlay converts the
    // controller's fraction back into a real height against this same
    // floor, and when they disagreed (the overlay rebased onto minimised
    // while this still used the small floor) a short upward drag stopped
    // expanding at all — caught by
    // `tap_empty_space_quick_create_test.dart`.
    final minHeight = viewportHeight * quickCreateSheetMinimisedFraction;
    final travel = fullHeight - minHeight;

    return GestureDetector(
      // Tap restores the small sheet — but ONLY from minimised, which is
      // where it was actually asked for ("this little handle to expand or
      // tap to expand. When tapped, it expands to this mini sheet").
      //
      // Deliberately null in every other state rather than also opening
      // the full sheet from small: a live `onTap` recognizer keeps the
      // gesture arena unresolved for longer, and measured directly, that
      // cost the FIRST ~35px of a short upward drag to touch slop —
      // enough to drop a 70px drag from 0.419 to 0.379 and miss the
      // expand threshold entirely. That regressed
      // `tap_empty_space_quick_create_test.dart`'s own "a SHORT upward
      // drag is enough to expand", itself written against a direct report
      // that expanding was "difficult to do". Minimised has no such
      // conflict: there is no short-drag-to-expand gesture competing
      // there, since any upward drag from minimised settles to small
      // anyway.
      onTap: controller.minimised ? controller.restoreToSmall : null,
      onVerticalDragUpdate: (details) {
        if (travel <= 0) return;
        // `details.delta.dy / travel` is a 0..1 ratio of the real pixel
        // travel between the two heights; `controller.fraction` lives on
        // the ABSOLUTE [quickCreateSheetMinimisedFraction, 1.0] scale
        // (see its own doc comment), so the ratio must be scaled up to
        // match before subtracting, or a full-height drag would move the
        // fraction by only part of the range.
        final fractionRange = 1.0 - quickCreateSheetMinimisedFraction;
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
      //
      // Top-aligned with a small top inset, not centered in the whole
      // (button-height) row — requested directly against a screenshot:
      // "move the handle higher up." Centering in the full row put it at
      // the same vertical mid-point as the X/Schedule buttons beside it,
      // reading as one more control in that row rather than a separate
      // "sheet can be dragged" affordance sitting above the row's real
      // content. `AppButton.subtleTint`-colored, not `colorTextSecondary`
      // — see [AppSheetHandle]'s own doc comment.
      //
      // `spacingSm` (2026-09-22, one rung down from the original
      // `spacingXs`) — this sheet is the reference implementation for
      // docs/DESIGN_SYSTEM.md's unified "Sheets" section, and the
      // unification's own reference value is "slightly lower than
      // currently."
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: theme.spacingSm),
          child: AppSheetHandle(theme: theme),
        ),
      ),
    );
  }
}
