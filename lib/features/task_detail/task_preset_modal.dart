import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_sheet_header.dart';
import '../../shared/models/task_template.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/task_template_providers.dart';
import '../timeline/template_chip_strip.dart';

/// The quick-add preset picker. Presets are task templates, but this sheet
/// keeps their selection local and resolves the chosen template to the
/// caller; applying the preset remains the quick-add flow's responsibility.
class TaskPresetModal extends ConsumerStatefulWidget {
  const TaskPresetModal({super.key, this.selectedTemplateId});

  final String? selectedTemplateId;

  static Future<TaskTemplate?> show({
    required BuildContext context,
    String? selectedTemplateId,
  }) {
    return AppSheet.show<TaskTemplate>(
      context: context,
      size: AppSheetSize.half,
      builder: (context) =>
          TaskPresetModal(selectedTemplateId: selectedTemplateId),
    );
  }

  @override
  ConsumerState<TaskPresetModal> createState() => _TaskPresetModalState();
}

class _TaskPresetModalState extends ConsumerState<TaskPresetModal> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final templates = ref.watch(taskTemplateListProvider);
    final categories = ref.watch(categoryListProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSheetHeader(
          theme: theme,
          title: 'Preset',
          onClose: () => Navigator.of(context).pop(),
        ),
        SizedBox(height: theme.spacingMd),
        if (templates.isEmpty)
          Text(
            'No presets yet.',
            style: theme.textBody.copyWith(color: theme.colorTextSecondary),
          )
        else
          Wrap(
            spacing: theme.spacingSm,
            runSpacing: theme.spacingSm,
            children: [
              for (final template in templates)
                TemplateChip(
                  theme: theme,
                  template: template,
                  category: categories
                      .where((category) => category.id == template.categoryId)
                      .firstOrNull,
                  selected: template.id == widget.selectedTemplateId,
                  onTap: () => Navigator.of(context).pop(template),
                ),
            ],
          ),
      ],
    );
  }
}
