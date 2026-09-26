import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_modal_scope.dart';

/// How far up the sheet starts, as a fraction of its own height.
///
/// It begins already half on screen and fades in from there, rather than
/// travelling the full height from fully offscreen. Requested directly:
/// "fade in and move up from 50% of position feeling more rapid with nice
/// easing." Halving the distance is most of what makes the entrance read
/// as quick — the sheet is recognisable almost immediately instead of
/// arriving at the end of a long slide.
const double _sheetEntranceOffset = 0.5;

/// Pushes [builder] as the app's standard slide-up modal sheet route.
///
/// One shared route rather than the five near-identical `PageRouteBuilder`s
/// this replaced (task detail, zone form, template form, tracked-behavior
/// form, add-category) — they had drifted into copies of the same twenty
/// lines, so a change to how sheets enter meant editing all five and
/// hoping none was missed.
///
/// The entrance is deliberately NOT Flutter's default full-height slide:
/// it starts at [_sheetEntranceOffset] of the sheet's height, fades in
/// over the same window, and uses a decelerating curve
/// ([AmbleTheme.curveDecelerate]) so the motion is already at speed when
/// it becomes visible instead of ramping up. Requested directly: "make
/// animations of sheets more modern, faster, smoother, kind of that they
/// feel more responsive."
///
/// Dismissal is deliberately quicker than the entrance
/// ([AmbleTheme.motionFast] vs [AmbleTheme.motionNormal]) — a sheet on its
/// way out has nothing left to show, and matching the entrance's duration
/// makes closing feel like waiting.
Future<T?> pushAppSheetRoute<T>(BuildContext context, WidgetBuilder builder) {
  final theme = Theme.of(context).extension<AmbleTheme>()!;
  final modalBuilder = rootModalBuilder(context, builder);
  return Navigator.of(context, rootNavigator: true).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      // Dims the screen behind the sheet. Was transparent, which left the
      // page underneath at full brightness competing with the modal — the
      // sheet is inset from the top, so what's behind it is visible and
      // needs pushing back.
      barrierColor: theme.colorScrim,
      // Zero duration — requested directly: "remove animation completely
      // for switching views... change screens no animation." The
      // transitionsBuilder below is otherwise unchanged (harmless at zero
      // duration: it just resolves to its end state on the next frame)
      // rather than restructuring this into a plain, non-animated push.
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: theme.curveDecelerate,
          // Reverse runs on the standard curve: a dismissal reads better
          // accelerating away than decelerating into nothing.
          reverseCurve: theme.curveStandard,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, _sheetEntranceOffset),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => modalBuilder(context),
    ),
  );
}

/// How far up a full-screen route starts, as a fraction of its own
/// height — much smaller than [_sheetEntranceOffset]: this fills the
/// whole screen, so it should read as arriving immediately, not
/// revealing from halfway the way a sheet does.
const double _fullScreenEntranceOffset = 0.15;

/// Pushes [builder] as a true full-screen takeover — [AmbleTheme]'s first
/// full-screen (not slide-up-sheet) modal convention, added for the
/// voice-capture flow (`voice_capture_screen.dart`) and meant to be
/// reused by any future full-screen feature rather than each inventing
/// its own transition.
///
/// Shares [pushAppSheetRoute]'s easing/timing tokens
/// ([AmbleTheme.curveDecelerate]/[AmbleTheme.curveStandard],
/// [AmbleTheme.motionNormal]/[AmbleTheme.motionFast]) so every modal in
/// the app accelerates and decelerates the same way — only the shape of
/// the transition differs: `opaque: true` (a full-screen page has nothing
/// left showing behind it, so no scrim/barrier color is needed) and a
/// much smaller slide offset ([_fullScreenEntranceOffset]) since the page
/// already covers the screen rather than revealing from partway up.
Future<T?> pushFullScreenRoute<T>(BuildContext context, WidgetBuilder builder) {
  final theme = Theme.of(context).extension<AmbleTheme>()!;
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: true,
      // Zero duration — see pushAppSheetRoute's own note above.
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: theme.curveDecelerate,
          reverseCurve: theme.curveStandard,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, _fullScreenEntranceOffset),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    ),
  );
}

/// Pushes [builder] as a plain full-screen route with NO transition
/// animation at all — the instant-navigation counterpart to a bare
/// `Navigator.push(MaterialPageRoute(...))`, which this replaces at every
/// call site that used to push a secondary screen (Settings sub-pages,
/// the Zones/Templates/Categories list screens, onboarding) with
/// Flutter's own default platform slide/fade. Requested directly: "remove
/// animation completely for switching views... change screens no
/// animation."
///
/// `MaterialPageRoute` itself exposes no duration/curve override at all
/// (its `transitionDuration` is fixed), so going instant means a plain
/// `PageRouteBuilder` with a zero-duration, no-op `transitionsBuilder`
/// instead — not a parameter tweak to the widget those 14 call sites used
/// before.
Route<T> instantRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}
