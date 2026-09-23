import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_button.dart' show AppButton, AppButtonVariant;
import 'app_press_feedback.dart';

/// A small pill-shaped tap target with a filled/unfilled selected state —
/// the shared shape behind the Repeats day-of-week chips, the Duration
/// modal's preset chips, the Appearance screen's Pill size/Text size
/// pickers, and the Inbox's own Section tabs (extracted so all of these
/// consume the exact same component per direct request: "should be same
/// comp as (days in repeat)"). No fixed width — callers that need a row of
/// equal-width chips wrap each one in `Expanded`; callers with
/// variable-length labels (duration presets like "15m", "1h") leave it
/// intrinsic.
///
/// **2026-09-23 — uses `theme.radiusPill`, not a hardcoded `radiusMd`.**
/// Reported directly: some Settings chip rows (Pill size/Text size) looked
/// square while others (Light/Dark/System, `ThemeModeSelector`'s own
/// `_ModeChip`) were fully round. Root cause was two independently
/// hand-built chip widgets, each with its OWN fixed radius, and NEITHER
/// actually tracking the live "Pill shape" setting (`theme.radiusPill`) —
/// this fixes the shared one, and `ThemeModeSelector` now consumes this
/// same widget instead of its own private copy (see that file's own doc
/// comment).
///
/// **2026-09-23 — [variant], defaulting to [AppButtonVariant.secondary].**
/// Requested directly: "In settings all should be secondary. In inbox
/// also tabs should be secondary." Every existing caller (Appearance's
/// Pill size/Text size/Theme mode, Repeats days, Duration presets, Inbox
/// Section tabs) previously filled its SELECTED chip with a flat
/// `colorAccent` — a primary-style treatment with no variant knob at all
/// — regardless of what look the surrounding screen used elsewhere.
/// Secondary now reuses [AppButton.subtleTint] directly (the same
/// blurred-glass tint token `AppButton`'s own secondary variant and
/// `AppTabSwitch`'s own secondary segment highlight already share) rather
/// than picking a new alpha — see that token's own doc comment for why
/// `colorTextPrimary`-derived, not `colorSurfaceBlurOverlay`. Primary
/// (the old flat-accent look) stays available for any future caller that
/// specifically wants it, but no current caller passes it.
class AppSelectableChip extends StatelessWidget {
  const AppSelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.variant = AppButtonVariant.secondary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final isSecondary = variant == AppButtonVariant.secondary;
    final radius = BorderRadius.circular(theme.radiusPill);

    // Secondary's foreground stays `colorTextPrimary` in BOTH states — a
    // translucent tint doesn't need (and wouldn't contrast well with) the
    // inverted light text primary's flat accent fill requires.
    final foreground = !selected
        ? theme.colorTextSecondary
        : (isSecondary ? theme.colorTextPrimary : theme.colorSurfacePrimary);

    final content = Container(
      height: theme.spacingXl,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: theme.spacingSm),
      decoration: BoxDecoration(
        // Primary's selected fill is the original flat `colorAccent`,
        // painted directly here (no blur needed). Secondary's selected
        // fill is applied by the `BackdropFilter` wrap below instead — this
        // stays transparent in that case, or the opaque `colorSurfaceTimeline`
        // painted here would sit on TOP of the blur tint and hide it.
        color: selected
            ? (isSecondary ? null : theme.colorAccent)
            : theme.colorSurfaceTimeline,
        borderRadius: radius,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textCaption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return AppPressFeedback(
      onTap: onTap,
      borderRadius: radius,
      // The wash rides on the chip's own foreground color — see
      // AppButton's own identical reasoning on its `rippleColor`.
      rippleColor: foreground,
      child: selected && isSecondary
          ? ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: theme.blurOverlaySigma,
                  sigmaY: theme.blurOverlaySigma,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppButton.subtleTint(theme),
                    borderRadius: radius,
                  ),
                  child: content,
                ),
              ),
            )
          : content,
    );
  }
}
