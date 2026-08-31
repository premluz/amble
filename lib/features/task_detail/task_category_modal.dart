import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_sheet.dart';
import '../../shared/models/task_category.dart';
import '../timeline/task_category_token_mapping.dart';

/// The compact "Category" modal — split out from the old combined
/// Name+Category modal once Name moved to the create flow's own stage 1
/// (requested directly: the schedule pane's "Category" row now opens this
/// on its own, via an "Add" link, rather than reopening the name field
/// alongside it).
///
/// A tap on a chip commits immediately and closes the modal — no separate
/// "Done" confirmation. Requested directly: "tapping on the tag is
/// already selecting, no need [to hit] done again." There's no local
/// selection state to mirror any more; [widget.category] is only read
/// once, to mark the currently-selected chip.
class TaskCategoryModal extends StatelessWidget {
  const TaskCategoryModal({super.key, required this.category});

  final TaskCategory category;

  /// Opens the modal as a sheet. Resolves to the chosen category, or null
  /// if dismissed without choosing one.
  static Future<TaskCategory?> show({
    required BuildContext context,
    required TaskCategory category,
  }) {
    return AppSheet.show<TaskCategory>(
      context: context,
      builder: (context) => TaskCategoryModal(category: category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Category',
          textAlign: TextAlign.center,
          style: theme.textTitle.copyWith(
            color: theme.colorTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacingLg),
        AppPane(
          child: Wrap(
            spacing: theme.spacingSm,
            runSpacing: theme.spacingSm,
            children: [
              for (final option in TaskCategoryPickerOrder.orderedForPicker)
                _CategoryChip(
                  category: option,
                  selected: option == category,
                  onSelected: () => Navigator.of(context).pop(option),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tint-filled category pill — same styling the old combined modal used.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final TaskCategory category;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categoryColor = theme.categoryColors[category.token]!;

    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: theme.motionFast,
        curve: theme.curveStandard,
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacingMd,
          vertical: theme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: categoryColor,
          borderRadius: BorderRadius.circular(theme.radiusMd),
          border: Border.all(
            color: selected ? theme.colorTextPrimary : Colors.transparent,
            width: theme.borderWidthHairline * 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.emoji, style: theme.textBody),
            SizedBox(width: theme.spacingSm),
            Text(
              category.label,
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
