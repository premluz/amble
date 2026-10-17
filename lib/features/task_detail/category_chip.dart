import 'package:flutter/material.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../shared/models/category.dart';
import 'category_visual.dart';

/// A label chip for picking a task's category: the label's own colour, its
/// glyph and name, with a hairline ring when selected. The one shared chip
/// for every category picker (the category modal, the name+category modal
/// and the task detail sheet's category row), which each used to carry an
/// identical private copy.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final Category category;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final visual = resolveCategoryVisual(theme: theme, category: category);
    // Compact, the value chips' size — requested directly: "labels still
    // see large." Its own colour is the fill, so selection is the ring,
    // not the glass tint.
    final height = ChipTokens.compactHeight(theme);
    final textStyle = theme.textCaption;
    final radius = BorderRadius.circular(ChipTokens.radius(theme));
    return AppPressFeedback(
      onTap: onSelected,
      borderRadius: radius,
      child: AnimatedContainer(
        duration: theme.motionFast,
        curve: theme.curveStandard,
        height: height,
        padding: EdgeInsets.symmetric(
          horizontal: ChipTokens.horizontalPadding(height),
        ),
        decoration: BoxDecoration(
          color: visual.pillColor,
          borderRadius: radius,
          border: Border.all(
            color: selected ? ChipTokens.ring(theme) : Colors.transparent,
            width: ChipTokens.ringWidth(theme),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryGlyph(
              category: category,
              color: glyphColorFor(visual),
              size: textStyle.fontSize! * ChipTokens.compactIconScale,
            ),
            SizedBox(width: theme.spacingSm),
            Text(
              category.name,
              style: textStyle.copyWith(
                color: glyphColorOn(visual.pillColor),
                fontWeight: selected
                    ? ChipTokens.selectedWeight
                    : ChipTokens.restWeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
