import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_pane.dart';
import '../../core/widgets/app_sheet.dart';
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
/// `TaskCategory` enum, and adds a right-aligned "+ Add new" link on the
/// title row that opens [showAddCategoryModal] — the newly created category
/// becomes this sheet's own selection, per the same "resolves to the
/// chosen category" `show()` contract.
class TaskCategoryModal extends ConsumerWidget {
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
      size: AppSheetSize.half,
      builder: (context) => TaskCategoryModal(categoryId: categoryId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final categories = ref.watch(visibleCategoryListProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AppSheet's own outer padding no longer provides a top inset
        // (2026-09-23 — "top padding should be in header").
        SizedBox(height: theme.spacingLg),
        Row(
          children: [
            // Left-aligned, not centered — corrected directly: a centered
            // title with a fixed-width balancing spacer left too little
            // room for "+ Add new" and wrapped it onto two lines. A plain
            // Expanded title plus a trailing, intrinsically-sized button
            // (no artificial symmetry) gives the link all the width it
            // needs.
            Expanded(
              child: Text(
                'Label',
                style: theme.textTitle.copyWith(
                  color: theme.colorTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final created = await showAddCategoryModal(context);
                if (created != null && context.mounted) {
                  Navigator.of(context).pop(created.id);
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
        AppPane(
          child: Wrap(
            spacing: theme.spacingSm,
            runSpacing: theme.spacingSm,
            children: [
              for (final option in categories)
                CategoryChip(
                  category: option,
                  selected: option.id == categoryId,
                  onSelected: () => Navigator.of(context).pop(option.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

