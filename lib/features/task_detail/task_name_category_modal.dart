import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_text_field.dart';
import '../../shared/models/task_category.dart';
import '../timeline/task_category_token_mapping.dart';

/// The compact "Name and category" modal — one of three per-field modals
/// the single-screen create/edit flow opens from its preview card's
/// pencil, replacing the old full-screen step 1. Per the mockup: name,
/// description, and category live together in one small bottom sheet
/// rather than their own wizard step.
///
/// Edits the passed-in controllers/category DIRECTLY and live — the
/// caller's preview card updates as the user types, same as it did when
/// this was a full step, because [titleController]/[notesController] are
/// the SAME controllers the caller's own preview reads from. Confirming
/// with "Done" just closes the sheet; there is nothing further to commit.
class TaskNameCategoryModal extends StatefulWidget {
  const TaskNameCategoryModal({
    super.key,
    required this.titleController,
    required this.notesController,
    required this.category,
    required this.onCategoryChanged,
  });

  final TextEditingController titleController;
  final TextEditingController notesController;
  final TaskCategory category;
  final ValueChanged<TaskCategory> onCategoryChanged;

  /// Opens the modal as a sheet. Returns once dismissed — there is no
  /// value to resolve, since edits land directly on the passed-in
  /// controllers as they happen.
  static Future<void> show({
    required BuildContext context,
    required TextEditingController titleController,
    required TextEditingController notesController,
    required TaskCategory category,
    required ValueChanged<TaskCategory> onCategoryChanged,
  }) {
    return AppSheet.show<void>(
      context: context,
      builder: (context) => TaskNameCategoryModal(
        titleController: titleController,
        notesController: notesController,
        category: category,
        onCategoryChanged: onCategoryChanged,
      ),
    );
  }

  @override
  State<TaskNameCategoryModal> createState() => _TaskNameCategoryModalState();
}

class _TaskNameCategoryModalState extends State<TaskNameCategoryModal> {
  // The sheet needs its OWN copy of the selected category to redraw
  // chip selection locally, but writes through to the caller on every
  // tap via onCategoryChanged — same "edit the source directly" contract
  // the text controllers already have, just mirrored in local state
  // because TaskCategory (unlike a controller) isn't itself a Listenable.
  late TaskCategory _category;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    // Scrollable rather than a bare Column: the on-screen keyboard (this
    // field autofocuses) can shrink the available height enough that
    // Name + Description + the Category pane + Done no longer all fit —
    // caught directly as a RenderFlex overflow with the keyboard open.
    // AppSheet's own inset already accounts for the keyboard via
    // MediaQuery; this only needs to let its OWN content scroll within
    // whatever room that leaves.
    return SingleChildScrollView(
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Name and category',
          textAlign: TextAlign.center,
          style: theme.textTitle.copyWith(
            color: theme.colorTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacingLg),
        // Name and Description share one bare pane (no section header),
        // matching the schedule screen's own Time/Duration/Date grouping.
        AppPane(
          child: Column(
            children: [
              AppTextField(
                controller: widget.titleController,
                label: 'Task name',
                autofocus: true,
              ),
              SizedBox(height: theme.spacingSm),
              AppTextField(
                controller: widget.notesController,
                label: 'Description',
                maxLines: 3,
              ),
            ],
          ),
        ),
        SizedBox(height: theme.spacingLg),
        // Category's header removed too — no AppPane `title` here either,
        // matching Name/Description's now-headerless pane above it.
        AppPane(
          child: Wrap(
            spacing: theme.spacingSm,
            runSpacing: theme.spacingSm,
            children: [
              for (final option in TaskCategoryPickerOrder.orderedForPicker)
                _CategoryChip(
                  category: option,
                  selected: option == _category,
                  onSelected: () {
                    setState(() => _category = option);
                    widget.onCategoryChanged(option);
                  },
                ),
            ],
          ),
        ),
        SizedBox(height: theme.spacingLg),
        AppButton(
          label: 'Done',
          size: AppButtonSize.large,
          shape: AppButtonShape.pill,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      ),
    );
  }
}

/// Tint-filled category pill — identical styling to the old step 1's
/// `_CategoryTag`, moved here since this modal is now the only place a
/// category is chosen.
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
