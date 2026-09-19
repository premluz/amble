import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_button.dart';
import 'app_option_switch_option.dart';
import 'app_press_feedback.dart';

/// A row of mutually-exclusive options sharing one recessed track, with the
/// selected option raised on its own filled highlight — "All / Crypto /
/// Stocks / Perps" style. Generalizes the Weekly Zone Edit screen's
/// previously-private, 2-option-only `_TabSwitcher`/`_Segment`
/// (`zone_grid_screen.dart`) into a reusable, arbitrary-length primitive,
/// per docs/DECISIONS.md's "two duplicates accepted, three gets promoted"
/// rule — this is that promotion, done ahead of a third private copy
/// rather than after one appeared, since the pattern was already about to
/// be reused for a new component (the reference request that prompted
/// this file).
///
/// Semantically and visually distinct from [AppConnectedButtons]: both are
/// mutually-exclusive selection among N options (see
/// [AppOptionSwitchOption]), but this one shows every option on one shared
/// track (a segmented control), while [AppConnectedButtons] fuses the
/// options into one outer capsule with dividers between them (a joined
/// button group). Pick this for a wider set of short, similarly-weighted
/// filter/category options; pick [AppConnectedButtons] for exactly 2-3
/// weightier, button-like choices.
///
/// Shares [AppButton]'s own variant palette and [AppButtonSize] height
/// scale exactly (refined 2026-09-19 alongside that widget's own pass) —
/// see [AppButton]'s class doc for the secondary variant's blurred-glass
/// reasoning, reused here unchanged.
class AppTabSwitch<T> extends StatelessWidget {
  const AppTabSwitch({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
  });

  final List<AppOptionSwitchOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Reuses [AppButtonVariant] directly (not a separate enum) — one source
  /// of truth for what "primary/secondary/ghost" means across every
  /// selectable control, confirmed directly. Governs the SELECTED
  /// segment's highlight only; unselected segments always show through to
  /// the shared track regardless of variant, same as [AppConnectedButtons].
  final AppButtonVariant variant;

  /// Overall track height — reuses [AppButtonSize] directly so this
  /// control sits flush alongside an [AppButton]/[AppConnectedButtons] in
  /// the same row without a manual height override at any call site.
  final AppButtonSize size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final isGhost = variant == AppButtonVariant.ghost;
    final height = appButtonHeightFor(theme, size);

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Ghost has no track fill at all — matching AppButton's own ghost
          // (transparent at rest) — so a row of ghost segments reads as
          // plain text options with only the selected one raised, rather
          // than a boxed control.
          color: isGhost ? null : theme.colorSurfaceSecondary,
          // radiusPill (the live "Pill shape" setting), not a fixed radiusLg
          // — requested directly so the whole button/tab-switch family
          // reshapes together when that setting changes, matching
          // AppButton's own pill shape and AppConnectedButtons' capsule.
          borderRadius: BorderRadius.circular(theme.radiusPill),
        ),
        child: Row(
          children: [
            for (final option in options)
              Expanded(
                child: _TabSwitchSegment(
                  theme: theme,
                  label: option.label,
                  selected: option.value == value,
                  variant: variant,
                  onTap: () => onChanged(option.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabSwitchSegment extends StatelessWidget {
  const _TabSwitchSegment({
    required this.theme,
    required this.label,
    required this.selected,
    required this.variant,
    required this.onTap,
  });

  final AmbleTheme theme;
  final String label;
  final bool selected;
  final AppButtonVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == AppButtonVariant.primary;
    final isSecondary = variant == AppButtonVariant.secondary;
    // Selected-segment highlight follows AppButton's own variant palette:
    // primary is the flat accent fill (the track itself is already a
    // secondary-toned surface, so primary's highlight stays a plain, un-
    // blurred fill — nothing sits behind it that needs blurring through).
    // Secondary's highlight is the same translucent glass tint
    // AppButton.secondary uses, blurring the track's own fill underneath
    // it, so a selected segment reads as "raised one more step" rather
    // than a second flat color layered on the first.
    final selectedTextColor = isPrimary
        ? theme.colorSurfacePrimary
        : theme.colorTextPrimary;

    final highlight = !selected
        ? const SizedBox.shrink()
        : (isPrimary
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorAccent,
                    borderRadius: BorderRadius.circular(theme.radiusPill),
                  ),
                )
              : (isSecondary
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(theme.radiusPill),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: theme.blurOverlaySigma,
                            sigmaY: theme.blurOverlaySigma,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              // 0.16, matching AppButton._secondaryTint's
                              // own raised alpha (0.08 read as too subtle
                              // in practice).
                              color: theme.colorTextPrimary.withValues(
                                alpha: 0.16,
                              ),
                              borderRadius: BorderRadius.circular(
                                theme.radiusPill,
                              ),
                            ),
                          ),
                        ),
                      )
                    // Ghost: no visible highlight surface at all — only the
                    // text weight/color below marks the selected segment.
                    : const SizedBox.shrink()));

    return AppPressFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.radiusPill),
      rippleColor: selected ? selectedTextColor : theme.colorTextPrimary,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: highlight),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacingSm,
              vertical: theme.spacingSm,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textBody.copyWith(
                color: selected ? selectedTextColor : theme.colorTextSecondary,
                // Not bold — matches AppButton's own text weight fix;
                // selected/unselected are distinguished by the highlight
                // surface and color, not by boldness.
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
