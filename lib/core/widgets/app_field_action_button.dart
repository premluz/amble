import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_press_feedback.dart';

/// A borderless, background-less icon button that sits inside a form
/// field's right edge and opens an alternative way to enter that field's
/// value — a clock for a time, a stopwatch for a duration, a calendar for
/// a date.
///
/// Ghost styling on purpose: the field's own fill already defines the
/// control, so a second filled surface inside it would read as a nested
/// button. The icon carries the affordance alone.
///
/// The visible glyph is small, but the tap target is padded out to
/// [AmbleTheme.spacingMinTapTarget] — a control this size is exactly the
/// case WCAG 2.5.8 exists for, and the padding is invisible so it costs
/// the layout nothing.
class AppFieldActionButton extends StatelessWidget {
  const AppFieldActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onPressed;

  /// Spoken description of what the button opens — the glyph alone is not
  /// a label, and this button never carries visible text.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Semantics(
      button: true,
      label: semanticLabel,
      // Circular wash over the padded-out tap target, matching the round
      // splash the `InkResponse` this replaced produced on Material —
      // now identical on iOS too, where that splash never existed. See
      // AppPressFeedback's own doc comment.
      child: AppPressFeedback(
        onTap: onPressed,
        shape: BoxShape.circle,
        child: SizedBox(
          width: theme.spacingMinTapTarget,
          height: theme.spacingMinTapTarget,
          child: Icon(icon, color: theme.colorTextSecondary),
        ),
      ),
    );
  }
}
