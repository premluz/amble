import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_press_feedback.dart';

/// A small pill-shaped tap target with a filled/unfilled selected state —
/// the shared shape behind both the Repeats day-of-week chips and the
/// Duration modal's preset chips (extracted so both consume the exact
/// same component per direct request: "should be same comp as (days in
/// repeat)"). No fixed width — callers that need a row of equal-width
/// chips wrap each one in `Expanded`; callers with variable-length labels
/// (duration presets like "15m", "1h") leave it intrinsic.
class AppSelectableChip extends StatelessWidget {
  const AppSelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return AppPressFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.radiusMd),
      // Selected chips are filled with the accent color, so the wash has
      // to switch with the state or it would vanish against it.
      rippleColor: selected
          ? theme.colorSurfacePrimary
          : theme.colorTextPrimary,
      child: Container(
        height: theme.spacingXl,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: theme.spacingSm),
        decoration: BoxDecoration(
          color: selected ? theme.colorAccent : theme.colorSurfaceTimeline,
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textCaption.copyWith(
            color: selected
                ? theme.colorSurfacePrimary
                : theme.colorTextSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
