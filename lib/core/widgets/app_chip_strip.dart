import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// A horizontally scrollable, single-line strip of chips — the shared
/// scroll/spacing/edge-inset mechanics behind
/// `template_chip_strip.dart`'s own `TemplateChipStrip`, extracted so a
/// second caller (the New Zone sheet's own tag-picker row) doesn't hand-roll
/// the identical `ListView.separated` shape a second time. Requested
/// directly: "we should make that scrolling same across usages, document
/// in design system so we reuse that class from add task (scrollable
/// badges/templates)."
///
/// Generic over the item type and knows nothing about [AppBadgeChip]
/// specifically — [itemBuilder] returns whatever chip widget the caller
/// wants (an [AppBadgeChip], or anything else). This strip owns only:
/// fixed [height], horizontal scrolling, the gap between items
/// ([itemSpacing]), and the [edgeInset] that keeps the first/last item
/// aligned with the padded content above/below it while still letting the
/// strip itself scroll edge-to-edge.
class AppChipStrip<T> extends StatelessWidget {
  const AppChipStrip({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.height,
    this.itemSpacing,
    this.edgeInset,
    this.keyOf,
  });

  final List<T> items;

  final Widget Function(BuildContext context, T item) itemBuilder;

  /// The strip's own fixed height — callers size this to their chip's own
  /// height, not necessarily the chip's badge/padding sum (see
  /// [TemplateChipStrip]'s own doc comment on deliberately trimming this
  /// shorter than that sum).
  final double height;

  /// Gap between consecutive chips. Defaults to `theme.spacingSm`,
  /// matching [TemplateChipStrip]'s own original spacing.
  final double? itemSpacing;

  /// Horizontal inset applied to the first/last chip so they line up with
  /// the padded fields around this strip, while the strip itself still
  /// scrolls full-bleed past both edges of its container. Defaults to 0 —
  /// a caller that already sits inside its own side margin (rather than
  /// rendering this strip full-bleed past its parent's own padding) never
  /// needs this; [TemplateChipStrip] is the caller that does, since it
  /// deliberately renders full-bleed to scroll under the sheet's edges.
  final double? edgeInset;

  /// Optional per-item key, for a list whose items carry their own stable
  /// identity (matches [ListView.separated]'s own reliance on a real
  /// `Key` for correct state preservation when items reorder). Omit for
  /// items with no natural id (e.g. plain strings) — the index-based
  /// default key Flutter falls back to is fine there.
  final Key Function(T item)? keyOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: edgeInset ?? 0),
        itemCount: items.length,
        separatorBuilder: (context, _) =>
            SizedBox(width: itemSpacing ?? theme.spacingSm),
        itemBuilder: (context, index) {
          final item = items[index];
          final child = itemBuilder(context, item);
          final key = keyOf?.call(item);
          return key == null ? child : KeyedSubtree(key: key, child: child);
        },
      ),
    );
  }
}
