import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_sheet_flow.dart';
import '../../shared/providers/category_providers.dart';
import 'add_category_modal.dart';
import 'category_chip.dart';

/// The compact "Category" modal — split out from the old combined
/// Name+Category modal once Name moved to the create flow's own stage 1
/// (requested directly: the schedule pane's "Category" row now opens this
/// on its own, via an "Add" link, rather than reopening the name field
/// alongside it).
///
/// A tap on a chip commits immediately and closes the modal — no separate
/// "Done" confirmation. Requested directly: "tapping on the tag is
/// already selecting, no need [to hit] done again." There's no local
/// selection state to mirror any more; [widget.categoryId] is only read
/// once, to mark the currently-selected chip.
///
/// Iterates live [visibleCategoryListProvider] data (General excluded —
/// see that provider's own doc comment) rather than the old fixed
/// `TaskCategory` enum. The header's + pushes [AddCategoryPage] as the
/// next page of this sheet ([AppSheetFlow]); the new label becomes this
/// sheet's selection, per the same "resolves to the chosen category"
/// `show()` contract.
class TaskCategoryModal extends ConsumerStatefulWidget {
  const TaskCategoryModal({super.key, required this.categoryId});

  final String? categoryId;

  /// Opens the modal as a sheet. Resolves to the chosen category's id, or
  /// null if dismissed without choosing one.
  static Future<String?> show({
    required BuildContext context,
    required String? categoryId,
  }) {
    return AppSheet.show<String>(
      context: context,
      builder: (context) => AppSheetFlow(
        theme: Theme.of(context).extension<AmbleTheme>()!,
        root: TaskCategoryModal(categoryId: categoryId),
      ),
    );
  }

  @override
  ConsumerState<TaskCategoryModal> createState() => _TaskCategoryModalState();
}

class _TaskCategoryModalState extends ConsumerState<TaskCategoryModal> {
  /// New label is the next page of this sheet, not a sheet on top; saving
  /// it picks it and closes.
  void _addNewCategory() => AppSheetFlow.of(context).push(
    AddCategoryPage(
      onSaved: (created) => Navigator.of(context).pop(created.id),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categories = ref.watch(visibleCategoryListProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetFlowHeader(
          theme: theme,
          title: 'Label',
          trailing: AppButton(
            icon: Icons.add_rounded,
            variant: AppButtonVariant.ghost,
            shape: AppButtonShape.circle,
            tooltip: 'Add new label',
            onPressed: _addNewCategory,
          ),
        ),
        SizedBox(height: theme.spacingMd),
        Wrap(
          spacing: theme.spacingSm,
          runSpacing: theme.spacingSm,
          children: [
            for (final option in categories)
              CategoryChip(
                category: option,
                selected: option.id == widget.categoryId,
                onSelected: () => Navigator.of(context).pop(option.id),
              ),
          ],
        ),
      ],
    );
  }
}
