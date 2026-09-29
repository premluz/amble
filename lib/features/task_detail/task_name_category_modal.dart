import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_sheet_flow.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_value_chip.dart';
import '../../shared/providers/category_providers.dart';
import 'add_category_modal.dart';
import 'category_chip.dart';

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
/// Iterates live [visibleCategoryListProvider] data (General excluded —
/// see that provider's own doc comment) rather than the old fixed
/// `TaskCategory` enum. A "New label" chip after the labels pushes
/// [AddCategoryPage] as the next page of this sheet ([AppSheetFlow]); the
/// new label becomes this sheet's selection immediately, via
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
      builder: (context) => AppSheetFlow(
        theme: Theme.of(context).extension<AmbleTheme>()!,
        root: TaskNameCategoryModal(
          titleController: titleController,
          notesController: notesController,
          categoryId: categoryId,
          onCategoryChanged: onCategoryChanged,
        ),
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

  void _select(String categoryId) {
    setState(() => _categoryId = categoryId);
    widget.onCategoryChanged(categoryId);
  }

  /// New label is the next page of this sheet, not a sheet on top; saving
  /// selects it and comes back here, where Done still closes.
  void _addNewCategory() {
    final flow = AppSheetFlow.of(context);
    flow.push(
      AddCategoryPage(
        onSaved: (created) {
          _select(created.id);
          flow.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categories = ref.watch(visibleCategoryListProvider);

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
          // The sheet header row: title centred, Done (primary) right —
          // see DESIGN_SYSTEM.md "Sheets".
          AppSheetFlowHeader(
            theme: theme,
            title: 'Name and category',
            trailing: AppButton(
              label: 'Done',
              size: AppButtonSize.md,
              shape: AppButtonShape.pill,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SizedBox(height: theme.spacingMd),
          // Name and Description share one bare pane (no section header),
          // matching the schedule screen's own Time/Duration/Date grouping.
          AppPane(
            child: Column(
              children: [
                AppTextField(
                  controller: widget.titleController,
                  label: 'Add title',
                  // Bare — the shared style for every entity's name.
                  variant: AppTextFieldVariant.bare,
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
                  CategoryChip(
                    category: option,
                    selected: option.id == _categoryId,
                    onSelected: () => _select(option.id),
                  ),
                AppValueChip(
                  label: 'New label',
                  icon: Icons.add_rounded,
                  hasValue: false,
                  onTap: _addNewCategory,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
