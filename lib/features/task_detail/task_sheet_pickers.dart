import 'package:flutter/material.dart';

import 'task_behavior_modal.dart';
import 'task_category_modal.dart';
import 'task_description_modal.dart';
import 'task_duration_modal.dart';
import 'task_preset_modal.dart';
import 'task_repeat_modal.dart';
import 'task_sheet_form.dart';
import 'task_start_time_modal.dart';

/// What each chip of the task sheet opens — one focused picker sheet per
/// chip (DESIGN_SYSTEM.md "Sheets"), writing its answer into the form.
extension TaskSheetPickers on TaskSheetForm {
  Future<void> pickPreset(BuildContext context) async {
    final template = await TaskPresetModal.show(
      context: context,
      selectedTemplateId: templateId,
    );
    if (template != null) applyTemplate(template);
  }

  Future<void> pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) date = picked;
  }

  Future<void> pickTime(BuildContext context) async {
    final start = time ?? const TimeOfDay(hour: 12, minute: 0);
    final result = await TaskStartTimeModal.show(
      context: context,
      initialHour: start.hour,
      initialMinute: start.minute,
    );
    if (result != null) time = TimeOfDay(hour: result.$1, minute: result.$2);
  }

  Future<void> pickDuration(BuildContext context) async {
    final result = await TaskDurationModal.show(
      context: context,
      initialMinutes: durationMinutes ?? presetMinutes.first,
    );
    if (result != null) durationMinutes = result;
  }

  Future<void> pickRepeat(BuildContext context) async {
    final result = await TaskRepeatModal.show(
      context: context,
      enabled: repeats,
      selectedDays: selectedDays,
    );
    if (result != null) {
      setRepeat(enabled: result.enabled, days: result.selectedDays);
    }
  }

  Future<void> pickBehavior(BuildContext context) async {
    final result = await TaskBehaviorModal.show(
      context: context,
      behaviorId: behaviorId,
    );
    if (result != null) behaviorId = result.behaviorId;
  }

  Future<void> pickLabel(BuildContext context) async {
    final result = await TaskCategoryModal.show(
      context: context,
      categoryId: categoryId,
    );
    if (result != null) categoryId = result;
  }

  Future<void> editNote(BuildContext context) =>
      TaskDescriptionModal.show(context: context, controller: description);
}
