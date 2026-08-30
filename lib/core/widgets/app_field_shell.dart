import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// The shared chrome every form field wears: a filled, rounded container
/// whose fill deepens on focus, with an inline label that shrinks and
/// slides up out of the way once the field is in use.
///
/// This widget owns the *appearance and label motion only* — it takes no
/// controller and holds no text. The actual input sits in [child], so a
/// text field, a segmented time field, and a read-only tappable row can
/// all present identically without duplicating the fill/label logic.
/// Consumers should reach for [AppTextField] or [AppSegmentedTimeField]
/// first; this is the seam for building a new field type that neither
/// covers (per docs/CONSTITUTION.md design principle 4, screens never
/// assemble field chrome themselves).
///
/// Label behaviour follows the platform convention: the label rests
/// centred at full size while the field is empty and unfocused, and floats
/// to a smaller size at the top as soon as the field is focused OR holds a
/// value. It only returns once the field is both empty and unfocused, so a
/// filled field never hides what it is.
class AppFieldShell extends StatelessWidget {
  const AppFieldShell({
    super.key,
    required this.label,
    required this.isFocused,
    required this.isFloating,
    required this.child,
    this.onTap,
    this.trailing,
  });

  /// The inline label — floats up when [isFloating]. Never rendered as a
  /// separate caption below the field; it lives inside the fill.
  final String label;

  /// Drives the fill's active tone. Kept separate from [isFloating]
  /// because the two genuinely differ: a filled-but-blurred field floats
  /// its label without taking the focused fill.
  final bool isFocused;

  /// Whether the label sits in its raised position. Callers pass
  /// `isFocused || hasValue` — computed by the caller rather than derived
  /// here, since only the caller knows what "has a value" means for its
  /// own input (non-empty text, a selected date, a parsed duration).
  final bool isFloating;

  /// The input itself, laid out in the space under the floated label.
  final Widget child;

  /// Makes the whole shell — fill, label and all — one tap target. Used by
  /// fields with no keyboard of their own (the date row opens a picker),
  /// where tapping the label or the padding should behave like tapping the
  /// value.
  final VoidCallback? onTap;

  /// Optional right-hand adornment (a chevron, a unit suffix). Laid out
  /// beside the input, inside the fill.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    // The collapsed label occupies the same box as the floated one, so the
    // field's height never changes as the label moves — the row would
    // otherwise jump by a few pixels the moment it takes focus.
    final labelStyle = isFloating
        ? theme.textCaption.copyWith(color: theme.colorTextSecondary)
        : theme.textBody.copyWith(color: theme.colorTextSecondary);

    final content = AnimatedContainer(
      duration: theme.motionFast,
      curve: theme.curveStandard,
      width: double.infinity,
      // A floor, not a fixed height: a multi-line field still grows past
      // it. Without this the box collapses to text-plus-padding, which
      // reads cramped in a column and shrinks the tap target.
      constraints: BoxConstraints(minHeight: theme.sizeMinFieldHeight),
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacingMd,
        vertical: theme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: isFocused
            ? theme.colorSurfaceFieldActive
            : theme.colorSurfaceField,
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              // Centred within the min-height box: while the label rests
              // alone (input collapsed to zero height) it should sit in
              // the middle of the field, not pinned to the top.
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedDefaultTextStyle(
                  duration: theme.motionFast,
                  curve: theme.curveStandard,
                  style: labelStyle,
                  child: Text(label),
                ),
                // The input is always in the tree — never swapped out when
                // the label is down. Building it conditionally would mean
                // an empty field contains no `TextField` at all, which
                // breaks autofocus, keyboard focus, and anything that
                // looks the field up. Only its HEIGHT animates: it
                // collapses to zero while the label rests over it, so the
                // resting label still reads as the placeholder.
                ClipRect(
                  child: AnimatedAlign(
                    duration: theme.motionFast,
                    curve: theme.curveStandard,
                    alignment: Alignment.topLeft,
                    heightFactor: isFloating ? 1.0 : 0.0,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      // Without this the padding inside the fill isn't hit-testable, so
      // taps landing next to the text would fall through to the pane.
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}
