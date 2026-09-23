import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_press_feedback.dart';

/// A circular, icon-only adaptive mic button — same shape as [AppButton]'s
/// circle shape, but with a second visual state for "actively listening,"
/// since a mic button (unlike a plain icon button) has to show the user
/// dictation is live. Cupertino on iOS, Material elsewhere; screens never
/// reach for `CupertinoButton`/`FloatingActionButton` directly, per
/// docs/CONSTITUTION.md design principle 4.
class AppMicButton extends StatelessWidget {
  const AppMicButton({
    super.key,
    required this.isListening,
    required this.onPressed,
    this.isPrimary = true,
    this.size,
  });

  /// True while dictation is actively capturing speech — swaps the icon
  /// (mic → stop) and the fill color to [AmbleTheme.colorTaskAlert], the
  /// same "notable, distinct from ordinary chrome" token already used for
  /// Quick Capture's own recurrence-token highlight, so a listening mic
  /// reads as a live, attention-worthy state rather than just another
  /// pressed button.
  final bool isListening;
  final VoidCallback? onPressed;

  /// False renders the resting (non-listening) state as a neutral
  /// [AmbleTheme.colorSurfaceField] fill — matching [HeaderCircleButton]'s
  /// own default look — instead of the saturated accent fill, for a
  /// caller that wants the mic to read as a secondary action alongside a
  /// primary "Done"/"Save" button rather than competing with it. The
  /// listening state is unaffected either way — it's always the alert
  /// color, since "actively recording" is never a muted state.
  final bool isPrimary;

  /// Overrides the button's default diameter (`theme.spacingXl * 1.5`) —
  /// null keeps that default, every existing caller's unchanged look. The
  /// quick-capture sheet's header row passes `theme.spacingXl` here to
  /// match [HeaderCircleButton]'s own size exactly, requested directly:
  /// "voice record should be same size as done."
  final double? size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final resolvedSize = size ?? theme.spacingXl * 1.5;
    final restingColor = isPrimary
        ? theme.colorAccent
        : theme.colorSurfaceField;
    final restingIconColor = isPrimary
        ? theme.colorSurfacePrimary
        : theme.colorTextPrimary;

    // Same single-interaction treatment as [AppButton]'s circle shape,
    // which this mirrors — see AppPressFeedback's doc comment for why the
    // Cupertino/Material branch was dropped in favour of one wrapper.
    return AppPressFeedback(
      onTap: onPressed,
      shape: BoxShape.circle,
      // Both fills (accent, and the alert color while listening) are
      // saturated, so the wash rides on the same light foreground the
      // icon uses rather than a dark one that wouldn't register.
      rippleColor: isPrimary ? theme.colorSurfacePrimary : theme.colorTextPrimary,
      child: Container(
        width: resolvedSize,
        height: resolvedSize,
        decoration: BoxDecoration(
          color: isListening ? theme.colorTaskAlert : restingColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
          color: isListening ? theme.colorSurfacePrimary : restingIconColor,
        ),
      ),
    );
  }
}
