import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// How tall an [AppSheet] should be. Three sizes, confirmed directly rather
/// than left as one auto-sized default for everything:
/// - [small]: sizes to its content, same as the original (only) behavior —
///   a short form or picker that shouldn't claim more room than it needs.
/// - [half]: a fixed half-viewport-height sheet, for a picker/list with
///   real content but not a full flow (e.g. the Category picker).
/// - [nearFull]: matches `StepScaffold`'s own near-full-screen inset
///   (`spacingXl` from the top) — for a sheet that's really a whole small
///   form (e.g. Add Category), not a quick picker.
enum AppSheetSize { small, half, nearFull }

/// Adaptive modal sheet — a rounded Material bottom sheet everywhere except
/// iOS/macOS, where it uses Cupertino's modal-popup styling. Screens should
/// never reach for `showModalBottomSheet`/`showCupertinoModalPopup`
/// directly; this is the only entry point, per docs/CONSTITUTION.md design
/// principle 4.
class AppSheet {
  AppSheet._();

  /// The tallest on-screen keyboard seen this session, in logical pixels.
  ///
  /// Reserved up front by [liftedForKeyboard] so a sheet with an
  /// autofocused field lands above the keyboard in ONE motion rather than
  /// settling and then being pushed. Static because it is a property of
  /// the device/IME, not of any one sheet — the first sheet to see the
  /// keyboard teaches every later one its height.
  ///
  /// Zero until a keyboard has actually been observed, so the very first
  /// such sheet in a session still does the two-step; there is no
  /// platform API that reports the height before the keyboard opens.
  /// Confirmed directly as the right trade over the alternatives (leaving
  /// the sheet behind the keyboard, or delaying its entrance).
  static double _lastKeyboardHeight = 0;

  /// [padded] wraps [builder]'s result in the sheet's standard inset.
  /// Content that manages its own padding (a picker that needs its wheels
  /// to reach the sheet's edges) passes false.
  ///
  /// [size] defaults to [AppSheetSize.small] — the original, only behavior
  /// this sheet had — so every pre-existing caller is unaffected unless it
  /// opts into a larger size explicitly.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool padded = true,
    AppSheetSize size = AppSheetSize.small,
  }) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final platform = Theme.of(context).platform;
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    /// Lifts the sheet clear of the on-screen keyboard.
    ///
    /// Reads `MediaQuery.viewInsets.bottom` DIRECTLY, every frame — the
    /// sheet's position is derived from the keyboard's own live position,
    /// so the two move as ONE motion with a single source of truth. This
    /// is what both platforms' native sheets do, and on iOS the keyboard
    /// animation is already synced to Flutter's frames, so a per-frame
    /// read tracks it exactly.
    ///
    /// Deliberately NOT an `AnimatedPadding`. A brief attempt at that
    /// (after "when opening sheets with keyboard along seems jittery")
    /// was the wrong shape: it makes the sheet run its OWN animation
    /// toward the keyboard's value, so the two have separate curves and
    /// durations and the sheet permanently trails the keyboard. That
    /// smooths the symptom while adding lag, and cannot lock the two
    /// together the way deriving one from the other does. Confirmed
    /// directly: "do one motion best pattern."
    ///
    /// Applied here so EVERY sheet gets it, rather than each caller
    /// hand-rolling its own keyboard padding.
    Widget liftedForKeyboard(BuildContext sheetContext, Widget child) {
      final live = MediaQuery.viewInsetsOf(sheetContext).bottom;
      if (live > 0) _lastKeyboardHeight = live;
      // Reserves the keyboard's REMEMBERED height while it is still
      // opening, so the sheet lands at its final position in one motion
      // instead of settling and then being shoved upward as the inset
      // grows. Reported directly: "the small sheet only opens to its
      // height (fast as we discussed) but then slower moving keyboard
      // pushes it further... can it actually get to the final position
      // and keyboard follows up?" — measured at a 300px second movement
      // on a 800px-tall screen.
      //
      // `max` of the two, never just the cached value: the live inset
      // wins once it exceeds what we remembered (a taller keyboard, or a
      // different one), and the reservation collapses to 0 for a sheet
      // with no focused field because nothing ever set the cache.
      return Padding(
        padding: EdgeInsets.only(bottom: math.max(live, _lastKeyboardHeight)),
        child: child,
      );
    }

    // Builds with the SHEET ROUTE's context, not the caller's. Building
    // eagerly with the outer context (as this used to) meant a builder
    // that called `Navigator.of(ctx).pop(value)` popped the caller's
    // route instead of the sheet — so the sheet never closed and
    // `show()` never returned its value. Only surfaced once a caller
    // actually needed a return value; every prior caller was fire-and-
    // forget, which is why it went unnoticed.
    Widget content(BuildContext sheetContext) {
      final inner = padded
          ? Padding(
              padding: EdgeInsets.all(theme.spacingLg),
              child: builder(sheetContext),
            )
          : builder(sheetContext);

      return switch (size) {
        // Unconstrained — the sheet sizes to inner's own height, same as
        // the original (only) behavior.
        AppSheetSize.small => inner,
        // A fixed fraction of the viewport, scrollable if content
        // overflows it — a picker/list with real content, not a full
        // flow.
        AppSheetSize.half => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.5,
          child: SingleChildScrollView(child: inner),
        ),
        // Matches StepScaffold's own near-full-screen inset exactly, so a
        // sheet-based flow and a route-pushed flow (task creation, Zone
        // add/edit) read as the same "this is basically a whole screen"
        // scale rather than two different near-full heights.
        AppSheetSize.nearFull => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height - theme.spacingXl,
          child: SingleChildScrollView(child: inner),
        ),
      };
    }

    // KNOWN GAP, iOS only: `showCupertinoModalPopup` exposes no
    // equivalent of `transitionAnimationController`, so this branch keeps
    // Cupertino's own native popup timing while the Material branch below
    // now matches `pushAppSheetRoute`'s faster entrance. Matching it here
    // would mean reimplementing the popup's presentation from scratch.
    if (isCupertino) {
      return showCupertinoModalPopup<T>(
        context: context,
        builder: (sheetContext) => Container(
          decoration: BoxDecoration(
            color: theme.colorSurfaceBase,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.radiusModal),
            ),
          ),
          // showCupertinoModalPopup has no Material ancestor, but sheet
          // content may still need one (e.g. a Material TextField) — an
          // adaptive layer that can only safely host Cupertino widgets
          // isn't a useful abstraction. Transparent so it doesn't fight
          // the Cupertino background above.
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              top: false,
              child: liftedForKeyboard(sheetContext, content(sheetContext)),
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      barrierColor: theme.colorScrim,
      backgroundColor: theme.colorSurfaceBase,
      // Sets the entrance's CURVE as well as its duration. The curve is
      // the part that actually mattered: Flutter's default for a modal
      // bottom sheet is `Easing.legacyDecelerate`, used for BOTH
      // directions, and it is what made this sheet still feel slow after
      // an earlier attempt set only the duration (via a custom
      // `transitionAnimationController`). Reported directly, twice —
      // "small sheet on tasks manage feels sluggish", then "create note
      // (still slow) sheet opening in manage (tasks)".
      //
      // `sheetAnimationStyle` also replaces that controller outright, which
      // removes its whole disposal problem: the controller had to be
      // released only once the sheet reached `dismissed`, and a sheet
      // left open at teardown leaked its ticker.
      //
      // Matches `pushAppSheetRoute`'s own timing so bottom sheets and
      // full-screen sheet routes feel alike: decelerate in over
      // motionNormal, standard curve out over the shorter motionFast (a
      // sheet on its way out has nothing left to show).
      sheetAnimationStyle: AnimationStyle(
        curve: theme.curveDecelerate,
        duration: theme.motionNormal,
        reverseCurve: theme.curveStandard,
        reverseDuration: theme.motionFast,
      ),
      // Without this, Material caps the sheet at a fixed fraction of the
      // screen (9/16) regardless of the keyboard — a content-sized sheet
      // with a focused TextField would then overflow the instant the
      // keyboard opened, since the sheet had no room left to grow into.
      // `isScrollControlled: true` lets it grow to fit (up to the full
      // screen height), so `MediaQuery.viewInsets.bottom` padding inside
      // the content actually has somewhere to go. Reported directly as a
      // "bottom overflowed by N pixels" dev banner on the quick-capture
      // sheet.
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(theme.radiusModal),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: liftedForKeyboard(sheetContext, content(sheetContext)),
      ),
    );
  }
}
