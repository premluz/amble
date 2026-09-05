import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_sheet.dart';
import '../../shared/models/task_template.dart';
import '../../shared/providers/task_template_providers.dart';
import '../task_detail/task_remove.dart';
import 'task_template_form.dart';

/// The action menu for one [TaskTemplate] row — Edit and Delete, presented
/// via [AppSheet] and built from the same [ActionRow] an ordinary task's
/// own action sheet uses (`task_detail/task_action_sheet.dart`), rather
/// than inventing a second convention for this list.
Future<void> showTaskTemplateActionSheet(
  BuildContext context,
  TaskTemplate template,
) {
  return AppSheet.show<void>(
    context: context,
    builder: (context) => _TaskTemplateActionSheetContent(template: template),
  );
}

class _TaskTemplateActionSheetContent extends ConsumerWidget {
  const _TaskTemplateActionSheetContent({required this.template});

  final TaskTemplate template;

  Future<void> _edit(BuildContext context) async {
    Navigator.of(context).pop();
    await showTaskTemplateForm(context, template: template);
  }

  /// Deletes immediately, with no extra confirmation — mirroring ordinary
  /// task deletion, which also removes a plain (non-recurring) task on the
  /// spot (see `removeTask`; its only prompt exists for the recurring
  /// this-one-vs-the-series question, which a template has no equivalent
  /// of). Nothing references a template once it has spawned a task, so
  /// there is no cascade to warn about.
  ///
  /// `notifier` is resolved BEFORE the pop, for the same reason
  /// [removeTask]'s own doc comment gives: this sheet's element unmounts
  /// the instant it closes, and reading `ref` after that throws.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final notifier = ref.read(taskTemplateListProvider.notifier);
    navigator.pop();
    await notifier.deleteTemplate(template.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionRow(
          theme: theme,
          icon: Icons.edit_outlined,
          label: 'Edit template',
          onTap: () => _edit(context),
        ),
        ActionRow(
          theme: theme,
          icon: Icons.delete_outline_rounded,
          label: 'Delete template',
          // The existing destructive token, same as the task action
          // sheet's own Remove row — no new colour token for this.
          color: theme.colorTaskAlert,
          onTap: () => _delete(context, ref),
        ),
      ],
    );
  }
}
