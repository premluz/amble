import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_button.dart';
import 'app_option_switch_option.dart';
import 'app_press_feedback.dart';

/// Two or more mutually-exclusive options fused into ONE outer capsule —
/// "Money | Investments" style — rather than [AppTabSwitch]'s shared-track-
/// with-sliding-highlight look. See [AppTabSwitch]'s own doc comment for
/// when to pick which; this is the joined-button-group treatment, for a
/// small number of weightier, button-like choices rather than a wider row
/// of short filter labels.
///
/// No existing component in this design system rendered a fused capsule
/// before this — confirmed by survey: [AppSelectableChip] (the closest
/// prior art) renders each option as its own separately-shaped rounded
/// rect with a gap between them, the opposite visual treatment. This is
/// genuinely new geometry, not a reskin of an existing widget.
///
/// Shares [AppButton]'s own variant palette and [AppButtonSize] height
/// scale exactly (refined 2026-09-19 — "connected buttons should take
/// full height... should be same as others") — see [AppButton]'s class
/// doc for the secondary variant's blurred-glass reasoning, reused here
/// unchanged.
class AppConnectedButtons<T> extends StatelessWidget {
  const AppConnectedButtons({
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

  /// Reuses [AppButtonVariant] directly — see [AppTabSwitch]'s matching
  /// field doc for why (one source of truth for primary/secondary/ghost
  /// across every selectable control). Governs the selected segment's fill
  /// only.
  final AppButtonVariant variant;

  /// Overall capsule height — reuses [AppButtonSize] directly so this
  /// control sits flush alongside an [AppButton]/[AppTabSwitch] in the
  /// same row, rather than the fixed vertical padding this widget used
  /// before (which made its height drift from an adjacent `AppButton`'s).
  final AppButtonSize size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final isGhost = variant == AppButtonVariant.ghost;
    final isSecondary = variant == AppButtonVariant.secondary;
    // radiusPill (the live, setting-driven capsule shape every real
    // pill/task-block tracks — see GlassPillSurface) rather than a fixed
    // literal, so this control's roundness follows the same user-facing
    // "Pill shape" setting every other capsule in the app already does.
    final outerRadius = theme.radiusPill;
    final radius = BorderRadius.circular(outerRadius);
    final height = appButtonHeightFor(theme, size);

    final row = Row(
      children: [
        for (var i = 0; i < options.length; i++)
          Expanded(
            child: _ConnectedSegment(
              theme: theme,
              label: options[i].label,
              selected: options[i].value == value,
              variant: variant,
              // A divider between adjacent UNSELECTED segments reads as
              // one continuous fused group — but never drawn against a
              // selected neighbor, whose own fill already provides all
              // the visual separation needed (a hairline on top of a
              // filled edge would just look like a stray artifact).
              showLeadingDivider:
                  i > 0 &&
                  options[i].value != value &&
                  options[i - 1].value != value,
              onTap: () => onChanged(options[i].value),
            ),
          ),
      ],
    );

    // Secondary's track is the same blurred glass tint AppButton.secondary
    // uses — everything below (the ClipRRect'd Row of segments) sits ON
    // TOP of that blur, same layering AppButton uses for its own
    // secondary fill.
    final track = !isSecondary
        ? DecoratedBox(
            decoration: BoxDecoration(
              // Ghost's track is transparent, matching AppTabSwitch/
              // AppButton's own ghost treatment — only a hairline outline
              // marks the capsule's extent when nothing is filled.
              color: isGhost ? null : theme.colorSurfaceSecondary,
              borderRadius: radius,
              border: isGhost
                  ? Border.all(
                      color: theme.colorBorder,
                      width: theme.borderWidthHairline,
                    )
                  : null,
            ),
            child: row,
          )
        : ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: theme.blurOverlaySigma,
                sigmaY: theme.blurOverlaySigma,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // 0.16, matching AppButton._secondaryTint's own raised
                  // alpha (0.08 read as too subtle in practice).
                  color: theme.colorTextPrimary.withValues(alpha: 0.16),
                  borderRadius: radius,
                ),
                child: row,
              ),
            ),
          );

    return SizedBox(
      height: height,
      child: ClipRRect(
        // Clips each segment's own selected-fill rectangle to the outer
        // capsule's rounded corners — without this, a selected first/last
        // segment's square inner corners would visibly poke past the
        // rounded outer edge.
        borderRadius: radius,
        child: track,
      ),
    );
  }
}

class _ConnectedSegment extends StatelessWidget {
  const _ConnectedSegment({
    required this.theme,
    required this.label,
    required this.selected,
    required this.variant,
    required this.showLeadingDivider,
    required this.onTap,
  });

  final AmbleTheme theme;
  final String label;
  final bool selected;
  final AppButtonVariant variant;
  final bool showLeadingDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == AppButtonVariant.primary;
    final isSecondary = variant == AppButtonVariant.secondary;
    // Same primary/secondary/ghost -> fill/text mapping as
    // AppTabSwitch/AppButton — see either's build() for the identical
    // reasoning. Secondary's own selected fill is one step MORE opaque
    // than the track's own blurred tint (0.16 -> 0.24), so a selected
    // segment still reads as visually distinct from its unselected
    // siblings even though both sit on the same blurred glass base.
    final fillColor = isPrimary
        ? theme.colorAccent
        : (isSecondary ? theme.colorTextPrimary.withValues(alpha: 0.24) : null);
    final selectedTextColor = isPrimary
        ? theme.colorSurfacePrimary
        : theme.colorTextPrimary;

    // Selected fill is its own fully-rounded pill floating INSIDE the
    // track, inset by a small gap on every side — matching AppTabSwitch's
    // own "sliding highlight" geometry (2026-09-19 refinement: "rounding
    // of selected on both sides of button, currently inner side 0
    // rounding square" — edge-to-edge square fills clipped only by the
    // outer capsule left a selected middle/inner segment with hard
    // square corners facing its neighbors instead of rounding on every
    // side). Applied to every segment, selected or not, so the label's
    // position never shifts when selection changes.
    final insetPadding = EdgeInsets.symmetric(
      horizontal: theme.spacingXs,
      vertical: theme.spacingXs / 2,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showLeadingDivider
            ? Border(
                left: BorderSide(
                  color: theme.colorBorder,
                  width: theme.borderWidthHairline,
                ),
              )
            : null,
      ),
      child: AppPressFeedback(
        onTap: onTap,
        rippleColor: selected ? selectedTextColor : theme.colorTextPrimary,
        child: Container(
          alignment: Alignment.center,
          padding: insetPadding,
          decoration: selected && fillColor != null
              ? BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(theme.radiusPill),
                )
              : null,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textBody.copyWith(
              color: selected ? selectedTextColor : theme.colorTextSecondary,
              // Not bold in either state — matches AppButton/AppTabSwitch's
              // own text weight fix; selected/unselected are distinguished
              // by the fill and color, not by boldness.
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
