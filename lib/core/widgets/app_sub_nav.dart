import 'package:flutter/material.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';
import 'app_top_nav.dart';

/// A page's own navigation under the main nav — e.g. the Inbox's sections.
/// Built from the main nav's own [AppNavLabel]s, in their sub-nav variant
/// (the page-heading type, like the Day date), with the main nav's gap,
/// and set in the PAGE-HEADING SLOT: its first label sits
/// exactly where the Day date and the Habits period heading sit (screen
/// padding in, flush with the page's top), and it leaves the same room
/// below. So moving between those pages, that line of text doesn't budge.
class AppSubNav extends StatelessWidget {
  const AppSubNav({super.key, required this.children, this.trailing});

  /// The tabs, left to right — usually [AppSubNavLabel]s.
  final List<Widget> children;

  /// An optional action at the far end (e.g. "new section").
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final extra = trailing;
    return Padding(
      // Same slot as the Day/Habits headings: no top padding, screen
      // padding at the sides, `spacingSm` below…
      padding: EdgeInsets.fromLTRB(
        theme.spacingScreenPadding,
        0,
        theme.spacingScreenPadding,
        theme.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The shared page-heading line: fixed height, text centred, so it
          // matches the Day date and the Habits period exactly.
          SizedBox(
            height: PageHeadingTokens.rowHeight(theme),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    // Room for a tab's highlight wash to show past its text.
                    clipBehavior: Clip.none,
                    child: Row(
                      children: [
                        for (var i = 0; i < children.length; i++) ...[
                          if (i > 0) SizedBox(width: theme.spacingLg),
                          children[i],
                        ],
                      ],
                    ),
                  ),
                ),
                if (extra != null) ...[SizedBox(width: theme.spacingSm), extra],
              ],
            ),
          ),
          // …and the collapsed Day accordion's footprint under it (its
          // `spacingXs` gap plus 4px grip), as the Habits heading also
          // keeps, so the content below starts at the same place too.
          SizedBox(height: theme.spacingXs * 2),
        ],
      ),
    );
  }
}

/// One tab of an [AppSubNav]: an [AppNavLabel] at its text height. Its
/// active surface ([AppNavWash]) shows while pressed, and while
/// [highlighted] (e.g. a dragged row hovering it, "drop here"); it extends
/// past the text without taking any layout, so the label never moves.
class AppSubNavLabel extends StatelessWidget {
  const AppSubNavLabel({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => AppNavLabel(
    theme: Theme.of(context).extension<AmbleTheme>()!,
    label: label,
    selected: selected,
    onTap: onTap,
    variant: AppNavLabelVariant.sub,
    // Hovered by a drag: the same active surface a press shows.
    highlighted: highlighted,
  );
}
