import 'package:flutter/material.dart';

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
    final radius = BorderRadius.circular(theme.radiusMd);
    return AppPressFeedback(
      onTap: onSelected,
      borderRadius: radius,
      child: AnimatedContainer(
        duration: theme.motionFast,
        curve: theme.curveStandard,
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacingMd,
          vertical: theme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: visual.pillColor,
          borderRadius: radius,
          border: Border.all(
            color: selected ? theme.colorTextPrimary : Colors.transparent,
            width: theme.borderWidthHairline * 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryGlyph(
              category: category,
              color: glyphColorOn(visual.pillColor),
              size: theme.textBody.fontSize!,
            ),
            SizedBox(width: theme.spacingSm),
            Text(
              category.name,
              style: theme.textBody.copyWith(
                color: theme.colorTextPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
