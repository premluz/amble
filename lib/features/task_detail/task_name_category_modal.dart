import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_text_field.dart';
import '../../shared/models/category.dart';
import '../../shared/providers/category_providers.dart';
import 'add_category_modal.dart';
import 'category_visual.dart';

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
///
/// Iterates live [categoryListProvider] data rather than the old fixed
/// `TaskCategory` enum, and adds a right-aligned "+ Add new" link on the
/// title row that opens [showAddCategoryModal] — the newly created category
/// becomes this sheet's own selection immediately, via
/// [onCategoryChanged], same as tapping an existing chip.
class TaskNameCategoryModal extends ConsumerStatefulWidget {
  const TaskNameCategoryModal({
    super.key,
    required this.titleController,
    required this.notesController,
    required this.categoryId,
    required this.onCategoryChanged,
  });

  final TextEditingController titleController;
  final TextEditingController notesController;
  final String? categoryId;
  final ValueChanged<String> onCategoryChanged;

  /// Opens the modal as a sheet. Returns once dismissed — there is no
  /// value to resolve, since edits land directly on the passed-in
  /// controllers as they happen.
  static Future<void> show({
    required BuildContext context,
    required TextEditingController titleController,
    required TextEditingController notesController,
    required String? categoryId,
    required ValueChanged<String> onCategoryChanged,
  }) {
    return AppSheet.show<void>(
      context: context,
      builder: (context) => TaskNameCategoryModal(
        titleController: titleController,
        notesController: notesController,
        categoryId: categoryId,
        onCategoryChanged: onCategoryChanged,
      ),
    );
  }

  @override
  ConsumerState<TaskNameCategoryModal> createState() =>
      _TaskNameCategoryModalState();
}

class _TaskNameCategoryModalState extends ConsumerState<TaskNameCategoryModal> {
  // The sheet needs its OWN copy of the selected category id to redraw
  // chip selection locally, but writes through to the caller on every
  // tap via onCategoryChanged — same "edit the source directly" contract
  // the text controllers already have, just mirrored in local state
  // because a plain String id isn't itself a Listenable.
  late String? _categoryId;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categoryId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categories = ref.watch(categoryListProvider);

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
          Row(
            children: [
              // Left-aligned, not centered — corrected directly (same fix
              // as task_category_modal.dart): a centered title with a
              // fixed-width balancing spacer left too little room for "+
              // Add new" and wrapped it onto two lines, worse here since
              // this title ("Name and category") is longer.
              Expanded(
                child: Text(
                  'Name and category',
                  style: theme.textTitle.copyWith(
                    color: theme.colorTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final created = await showAddCategoryModal(context);
                  if (created != null && mounted) {
                    setState(() => _categoryId = created.id);
                    widget.onCategoryChanged(created.id);
                  }
                },
                child: Text(
                  '+ Add new',
                  style: theme.textBody.copyWith(
                    color: theme.colorAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
                for (final option in categories)
                  _CategoryChip(
                    category: option,
                    selected: option.id == _categoryId,
                    onSelected: () {
                      setState(() => _categoryId = option.id);
                      widget.onCategoryChanged(option.id);
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

/// Swatch-filled category pill — identical styling to the old step 1's
/// `_CategoryTag`, now reading its color/emoji from a live [Category] row
/// via [resolveCategoryVisual] instead of the old fixed enum.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
          color: visual.pillColor,
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
