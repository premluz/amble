import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_sheet_header.dart';
import '../../core/widgets/app_text_field.dart';

/// The task sheet's Note chip: edits the task's description
/// ([controller], the form's own — so there is nothing to hand back; Done
/// just closes).
class TaskDescriptionModal extends StatelessWidget {
  const TaskDescriptionModal({super.key, required this.controller});

  final TextEditingController controller;

  static Future<void> show({
    required BuildContext context,
    required TextEditingController controller,
  }) => AppSheet.show<void>(
    context: context,
    autofocusesKeyboard: true,
    builder: (context) => TaskDescriptionModal(controller: controller),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(
          theme: theme,
          title: 'Note',
          onClose: () => Navigator.of(context).pop(),
          trailing: AppButton(
            label: 'Done',
            size: AppButtonSize.md,
            shape: AppButtonShape.pill,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        SizedBox(height: theme.spacingMd),
        AppTextField(
          controller: controller,
          label: 'Add a note',
          maxLines: 4,
          autofocus: true,
        ),
      ],
    );
  }
}
