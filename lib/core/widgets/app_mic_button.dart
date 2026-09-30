import 'package:flutter/material.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';
import 'app_press_feedback.dart';

/// A circular, icon-only adaptive mic button — matching the header close
/// control at rest, with a distinct state for actively listening.
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

  /// False renders the resting (non-listening) state with the same
  /// [ChipTokens.restFill] and [ChipTokens.restText] as [HeaderCircleButton],
  /// so a secondary mic reads as the same quiet header chrome as close. The
  /// listening state remains the alert color, since active recording is
  /// never a muted state.
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
        : ChipTokens.restFill(theme);
    final restingIconColor = isPrimary
        ? theme.colorSurfacePrimary
        : ChipTokens.restText(theme);

    final filled = Container(
      width: resolvedSize,
      height: resolvedSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isListening ? theme.colorTaskAlert : restingColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
        color: isListening ? theme.colorSurfacePrimary : restingIconColor,
      ),
    );

    // Same single-interaction treatment as the header close control.
    return AppPressFeedback(
      onTap: onPressed,
      shape: BoxShape.circle,
      rippleColor: isPrimary
          ? theme.colorSurfacePrimary
          : ChipTokens.restText(theme),
      child: filled,
    );
  }
}
