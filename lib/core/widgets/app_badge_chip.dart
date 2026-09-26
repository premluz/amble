import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_button.dart' show AppButton, AppButtonSize, appButtonHeightFor;
import 'app_press_feedback.dart';
import 'app_value_chip.dart' show AppValueChipSize, AppValueChipVariant;

/// A pill-shaped chip combining a leading badge/icon with a label,
/// optionally selectable — the shared shape behind the quick-create mini
/// sheet's template chips (systematized directly: "systematize badge
/// (just displayed, selectable variant on off)... current reference is
/// quick task add presets/templates badges").
///
/// **Selected state never changes the chip's footprint.** The old
/// `TemplateChip` this replaces toggled its `Container.border` between
/// `null` and `Border.all(...)` — the border track wasn't even reserved
/// when unselected, so selecting a chip grew its total size by the
/// border's own width on every edge (worse than the more common "reserve
/// a transparent border, swap its color" trick, which is at least
/// size-stable). Fixed here the same way [SelectedPillBorder] already
/// fixed the identical bug for task/zone pills, confirmed via
/// AskUserQuestion as the technique to reuse: the ring paints as a
/// `Positioned.fill` OVERLAY on top of the full-size fill, inside an
/// unpadded `Stack`, rather than via `Padding` or a `Container.border`
/// that would consume layout space and shrink/grow the content box.
///
/// **Single accent ring, not [SelectedPillBorder]'s dual-ring
/// (dark-separator + accent) treatment** — confirmed via AskUserQuestion.
/// That widget's second, always-dark ring exists specifically so a
/// selection ring stays visible against an arbitrary, possibly-already-
/// blue pill fill (task/zone colors span the whole category palette —
/// see its own doc comment). This chip's fill is always the neutral
/// [AmbleTheme.colorSurfaceSecondary], never a category color, so that
/// risk doesn't exist here and the extra ring would only add visual
/// weight a neutral background doesn't need.
///
/// Not built on [SelectedPillBorder] itself: that widget owns fill +
/// rings only, with no padding/tap-handling/label-layout of its own, and
/// its two-ring shape is tuned for a different (colored-pill) context —
/// see its own doc comment's "Is it reusable as-is" reasoning. This
/// widget borrows the OVERLAY-not-padding technique, not the widget.
///
/// Non-selectable usage: omit [selected]/[onTap] (both null, the
/// defaults) to render a plain, non-interactive badge+label chip with no
/// ring and no gesture handling — the "just displayed" variant requested
/// alongside the selectable one.
///
/// **2026-09-23 — fill matches [AppButton.secondary]'s own translucent
/// glass tint (`AppButton.subtleTint` under a `BackdropFilter`), not the
/// old flat `colorSurfaceSecondary`.** Reported directly against a
/// reference (the quick-create mini sheet's own preset chips — "Running" /
/// "Laundry" / "Read for class"): the dark, opaque fill didn't match the
/// lighter secondary-button surface used elsewhere. "Ensure that this same
/// token is used for the secondary button and the badge background" —
/// same fix, same token, as [HeaderCircleButton]/[AppMicButton] got
/// alongside this. **Vertical padding also now equals the horizontal
/// (`theme.spacingSm` on every side)**, per the same report: "the top
/// padding should be the same as the left and right" — previously
/// `spacingXs / 2` vertical vs. `spacingSm` horizontal, a real asymmetry,
/// not merely visually tight.
///
/// **2026-09-26 — [variant] and [theme.radiusPill], not a fixed
/// [AmbleTheme.radiusXl].** Unified against [AppValueChip] (the task
/// composer's field chip), requested directly: "it should also have same
/// variants as that widget we added value chip, and also rounding same."
/// Reuses [AppValueChipVariant] rather than a second, identical enum — see
/// that type's own doc comment. Defaults to [AppValueChipVariant.filled],
/// preserving every existing call site's look exactly (neither current
/// caller — `template_chip_strip.dart`, `multi_task_edit_sheet.dart` —
/// passes a variant).
///
/// **2026-09-26 — [size], reusing [AppValueChipSize] the same way
/// [variant] reuses [AppValueChipVariant].** Requested directly: "app
/// badge chip should have sizes same as app value[chip] and same font
/// weight and sizes." Controls this chip's own height and text style
/// ONLY — confirmed via AskUserQuestion — [leading] stays entirely
/// caller-sized, exactly as today (both real callers already size their
/// own `CategoryBadge`/`Icon` to `theme.spacingLg` independently of this
/// widget). Font weight needed no change: [AppValueChip] is `w700` for a
/// SET value and `w500` for its placeholder, and this chip's `label` is
/// always real content, never a placeholder — it was already `w700`,
/// [AppValueChip]'s own "has a value" weight, before this change.
/// Defaults to [AppValueChipSize.md] — the closest rung to this chip's
/// pre-existing, unparameterized height (`spacingLg` leading + `spacingSm`
/// padding on every side ≈ 40px, [AppButtonSize.md]'s own height exactly)
/// — so neither existing caller shifts size on this change alone, though
/// the text itself does shrink slightly: this chip used `theme.textBody`
/// (`TypePrimitives.size3`) before, larger than any rung
/// [AppValueChip] itself ever uses (`md` tops out at `textLabel`,
/// `size2`) — an unavoidable consequence of genuinely sharing one scale,
/// not a bug.
class AppBadgeChip extends StatelessWidget {
  const AppBadgeChip({
    super.key,
    required this.theme,
    this.leading,
    required this.label,
    this.selected = false,
    this.onTap,
    this.variant = AppValueChipVariant.filled,
    this.size = AppValueChipSize.md,
  });

  final AmbleTheme theme;

  /// The chip's leading visual — typically a [CategoryBadge] at a size
  /// matching this chip's own scale (the quick-create reference uses
  /// `theme.spacingLg`). Not fixed to [CategoryBadge] specifically: any
  /// small leading widget (an icon, a color swatch) fits the same slot.
  /// Sized entirely by the CALLER — [size] does not touch this, see this
  /// class's own 2026-09-26 doc comment.
  ///
  /// **2026-09-26 — now optional.** A text-only chip (no leading
  /// badge/icon at all) is a real, requested variant — the Zone facet
  /// picker's own tag chips ("Morning", "Commute", "Work"…) have no icon.
  /// `null` omits both the leading slot and its trailing gap entirely,
  /// rather than reserving empty space for one.
  final Widget? leading;

  final String label;

  /// Null renders a plain, non-interactive chip — no ring, no tap
  /// handling. Non-null renders the selectable variant; the ring shows
  /// only when this is `true`.
  final bool? selected;

  /// Required when [selected] is non-null (the selectable variant), since
  /// a selectable chip with no tap handler would be dead UI. Left null
  /// for the "just displayed" variant.
  final VoidCallback? onTap;

  /// Filled (the original look) or outlined — see this class's own
  /// 2026-09-26 doc comment.
  final AppValueChipVariant variant;

  /// This chip's own height/text-style rung, reusing [AppValueChip]'s
  /// scale — see this class's own 2026-09-26 doc comment.
  final AppValueChipSize size;

  AppButtonSize get _buttonSize => switch (size) {
    AppValueChipSize.xs => AppButtonSize.xs,
    AppValueChipSize.sm => AppButtonSize.sm,
    AppValueChipSize.md => AppButtonSize.md,
  };

  // Mirrors AppValueChip's own `_textStyle` mapping exactly (same rungs,
  // same styles) — the whole point of sharing [AppValueChipSize] is that
  // the two widgets' text sizes line up, not just their enum names.
  TextStyle _textStyle() => switch (size) {
    AppValueChipSize.xs || AppValueChipSize.sm => theme.textCaption,
    AppValueChipSize.md => theme.textLabel,
  };

  @override
  Widget build(BuildContext context) {
    // radiusPill, not a fixed radiusXl — tracks the live "Pill shape"
    // setting the same way AppValueChip/AppButton/AppSelectableChip
    // already do, so this chip's corners can never visibly drift from
    // its siblings again.
    final radius = BorderRadius.circular(theme.radiusPill);
    final ringWidth = theme.borderWidthHairline;
    final isSelectable = selected != null;
    final isOutlined = variant == AppValueChipVariant.outlined;
    final minHeight = appButtonHeightFor(theme, _buttonSize);

    final content = ConstrainedBox(
      // A MINIMUM, not a fixed height: unlike AppValueChip (no leading
      // slot), this chip's caller-sized `leading` could in principle be
      // taller than a small rung's own height (e.g. a `spacingXl` leading
      // inside an `xs` chip) — clamping to a fixed height would clip it.
      // Every real caller today sizes `leading` to `spacingLg` (24px),
      // comfortably under even the smallest rung here, but this stays
      // safe rather than assuming that forever.
      constraints: BoxConstraints(minHeight: minHeight),
      child: Stack(
        // Centered, not the default topStart — a caller that constrains
        // this chip to a fixed height taller than its own content (e.g.
        // TemplateChipStrip's SizedBox) otherwise pins the Padding+Row to
        // the top, misaligning the badge/label against the chip's own
        // rounded fill. Reported directly against the quick-create sheet's
        // template chips.
        alignment: Alignment.center,
        children: [
          Padding(
            // Equal on every side — see this class's own doc comment on the
            // vertical/horizontal asymmetry this fixes.
            padding: EdgeInsets.all(theme.spacingSm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading case final leading?) ...[
                  leading,
                  SizedBox(width: theme.spacingSm),
                ],
                Text(
                  label,
                  style: _textStyle().copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // The selection ring — an OVERLAY, not Padding, so it never
          // changes the chip's own size (see this widget's own doc
          // comment). Present in the tree only while selectable AND filled;
          // outlined already carries its own accent-colored border at the
          // same radius for the selected state (see the `decorated` branch
          // below), so this ring would otherwise double-paint an identical
          // border on top of it.
          if (isSelectable && !isOutlined)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected! ? theme.colorAccent : Colors.transparent,
                      width: ringWidth,
                    ),
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // Outlined never paints the glass fill — a plain bordered box instead,
    // mirroring AppValueChip's own outlined branch exactly (border color
    // tracks state: accent while selected, the neutral hairline
    // otherwise; a non-selectable outlined chip always gets the neutral
    // border since it has no state to reflect).
    final Widget decorated;
    if (isOutlined) {
      decorated = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: (isSelectable && selected!)
                ? theme.colorAccent
                : theme.colorBorder,
            width: ringWidth,
          ),
        ),
        child: content,
      );
    } else {
      final filled = DecoratedBox(
        decoration: BoxDecoration(
          color: AppButton.subtleTint(theme),
          borderRadius: radius,
        ),
        child: content,
      );

      // ClipRRect + BackdropFilter — the same glass recipe AppButton's own
      // secondary variant and HeaderCircleButton's default now share,
      // rather than a flat translucent color painted with nothing
      // blurred behind it (which reads as a dim, not glass — see
      // GlassPillSurface's own doc comment on this exact distinction).
      decorated = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: theme.blurOverlaySigma,
            sigmaY: theme.blurOverlaySigma,
          ),
          child: filled,
        ),
      );
    }

    if (!isSelectable) return decorated;

    return AppPressFeedback(
      onTap: onTap,
      borderRadius: radius,
      child: decorated,
    );
  }
}
