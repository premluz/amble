import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_field_row.dart';
import '../../core/widgets/app_switch.dart';
import '../../shared/models/category.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import 'task_sheet_form.dart';
import 'task_sheet_pickers.dart';

/// The side panel's lines after the schedule: label, tracked behavior, the
/// two on/off settings, and the note. Names come from the live lists, so a
/// renamed label shows its new name here.
class TaskPanelDetailRows extends ConsumerWidget {
  const TaskPanelDetailRows({super.key, required this.form});

  final TaskSheetForm form;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = form.categoryId == BuiltInCategoryIds.general
        ? null
        : ref
              .watch(categoryListProvider)
              .where((c) => c.id == form.categoryId)
              .firstOrNull;
    final behavior = ref
        .watch(trackedBehaviorListProvider)
        .where((b) => b.id == form.behaviorId)
        .firstOrNull;
    final note = form.description.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppFieldRow.single(
          icon: Icons.tag_rounded,
          label: label?.name ?? 'Label',
          hasValue: label != null,
          onTap: form.pickLabel,
        ),
        AppFieldRow.single(
          icon: Icons.fingerprint_rounded,
          label: behavior?.title ?? 'Track',
          hasValue: behavior != null,
          onTap: form.pickBehavior,
        ),
        _switch(
          form.isImportant ? Icons.star_rounded : Icons.star_border_rounded,
          'Important',
          form.isImportant,
          (value) => form.isImportant = value,
        ),
        _switch(
          form.notificationsEnabled
              ? Icons.notifications_rounded
              : Icons.notifications_off_rounded,
          'Notify at start',
          form.notificationsEnabled,
          (value) => form.notificationsEnabled = value,
        ),
        AppFieldRow.single(
          icon: Icons.notes_rounded,
          label: note.isEmpty ? 'Note' : note.split('\n').first,
          hasValue: note.isNotEmpty,
          onTap: form.editNote,
        ),
      ],
    );
  }

  /// An on/off setting: the switch, or a tap on its name, flips it.
  Widget _switch(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) => AppFieldRow.single(
    icon: icon,
    label: label,
    hasValue: value,
    onTap: (_) => onChanged(!value),
    trailing: AppSwitch(value: value, onChanged: onChanged),
  );
}
