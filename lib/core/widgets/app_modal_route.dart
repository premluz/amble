import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

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
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      // Dims the screen behind the sheet. Was transparent, which left the
      // page underneath at full brightness competing with the modal — the
      // sheet is inset from the top, so what's behind it is visible and
      // needs pushing back.
      barrierColor: theme.colorScrim,
      transitionDuration: theme.motionNormal,
      reverseTransitionDuration: theme.motionFast,
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
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    ),
  );
}
