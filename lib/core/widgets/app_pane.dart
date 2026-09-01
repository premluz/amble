import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// A level-1 surface (see [AmbleTheme.colorSurfacePrimary]) that groups
/// related controls, with its section [title] rendered ABOVE and OUTSIDE
/// the pane rather than as a heading inside it.
///
/// Keeping the title outside is what lets the pane itself stay a clean
/// uninterrupted card: the label belongs to the *group*, not to the
/// surface, so it sits on the page background alongside the pane's top
/// edge. Panes without a title (a preview card, a single-control row)
/// simply omit it and render as a bare card.
class AppPane extends StatelessWidget {
  const AppPane({super.key, required this.child, this.title, this.padding});

  /// Section heading shown above the pane. Omit for an unlabelled card.
  final String? title;

  final Widget child;

  /// Overrides the pane's internal padding. Only for a pane whose child
  /// draws to its own edges (a full-bleed list); ordinary content should
  /// take the default so panes stay consistent.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    final pane = Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(theme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorSurfacePrimary,
        borderRadius: BorderRadius.circular(theme.radiusXl),
        // No border. The pane is separated from the level-0 ground by a
        // subtle drop shadow instead — the two fills are only ~3%
        // lightness apart, so something has to carry that edge, and a
        // shadow says "raised" where a border only says "outlined".
        boxShadow: theme.shadowPane,
      ),
      child: child,
    );

    if (title == null) return pane;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: theme.spacingSm,
            bottom: theme.spacingSm,
          ),
          child: Text(
            title!,
            // One rung up from textLabel: these titles sit OUTSIDE the
            // pane on the page background, where they act as section
            // headings rather than field captions, so they carry the body
            // size at bold weight.
            style: theme.textBody.copyWith(
              color: theme.colorTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        pane,
      ],
    );
  }
}
