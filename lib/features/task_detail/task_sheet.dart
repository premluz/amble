import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_sheet.dart';
import '../../shared/models/task.dart';
import 'task_editor.dart';
import 'task_inspector.dart';

/// Opens the task editor for a task opened from anywhere: edit [task]
/// (Save, and a trash button), duplicate [duplicateFrom] or create — the
/// same fields and save as the Timeline's in-place sheet. [templateId]
/// records the preset a duplicate came from. An unscheduled Things item gets
/// current-time and 15-minute defaults so it can be saved immediately.
///
/// In the wide layout (a [TaskInspectorPanel] on screen) it opens in that
/// right-hand panel; otherwise as a bottom sheet. Every caller gets the
/// right one without knowing which layout is showing.
Future<void> showTaskSheet(
  BuildContext context, {
  Task? task,
  Task? duplicateFrom,
  String? templateId,
  DateTime? initialScheduledAt,
  TimeOfDay? initialTimeOfDay,
}) {
  final inspector = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(taskInspectorProvider.notifier);
  if (inspector.hasHost) {
    return inspector.open(
      task: task,
      duplicateFrom: duplicateFrom,
      templateId: templateId,
      initialScheduledAt: initialScheduledAt,
      initialTimeOfDay: initialTimeOfDay,
    );
  }
  final creating = task == null && duplicateFrom == null;
  return AppSheet.show<void>(
    context: context,
    autofocusesKeyboard: creating,
    builder: (sheetContext) => TaskEditor(
      // The caller's context: the delete's undo toast anchors there, since
      // this sheet is gone by then.
      rootContext: context,
      onFinished: () => Navigator.of(sheetContext).pop(),
      guardsRoutePop: true,
      task: task,
      duplicateFrom: duplicateFrom,
      templateId: templateId,
      initialScheduledAt: initialScheduledAt,
      initialTimeOfDay: initialTimeOfDay,
    ),
  );
}
