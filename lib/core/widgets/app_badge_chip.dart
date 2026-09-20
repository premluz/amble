import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_press_feedback.dart';

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
class AppBadgeChip extends StatelessWidget {
  const AppBadgeChip({
    super.key,
    required this.theme,
    required this.leading,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final AmbleTheme theme;

  /// The chip's leading visual — typically a [CategoryBadge] at a size
  /// matching this chip's own scale (the quick-create reference uses
  /// `theme.spacingLg`). Not fixed to [CategoryBadge] specifically: any
  /// small leading widget (an icon, a color swatch) fits the same slot.
  final Widget leading;

  final String label;

  /// Null renders a plain, non-interactive chip — no ring, no tap
  /// handling. Non-null renders the selectable variant; the ring shows
  /// only when this is `true`.
  final bool? selected;

  /// Required when [selected] is non-null (the selectable variant), since
  /// a selectable chip with no tap handler would be dead UI. Left null
  /// for the "just displayed" variant.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(theme.radiusXl);
    final ringWidth = theme.borderWidthHairline;
    final isSelectable = selected != null;

    final content = Stack(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacingMd,
            vertical: theme.spacingXs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              SizedBox(width: theme.spacingSm),
              Text(
                label,
                style: theme.textBody.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // The selection ring — an OVERLAY, not Padding, so it never
        // changes the chip's own size (see this widget's own doc
        // comment). Present in the tree only while selectable, so an
        // always-`selected: false` chip pays for exactly one Positioned
        // child, matching the non-selectable variant's own cost.
        if (isSelectable)
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
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorSurfaceSecondary,
        borderRadius: radius,
      ),
      child: content,
    );

    if (!isSelectable) return decorated;

    return AppPressFeedback(
      onTap: onTap,
      borderRadius: radius,
      child: decorated,
    );
  }
}
