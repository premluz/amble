import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/task.dart';
import '../timeline/pending_task_draft_provider.dart' show PendingTaskDraft;

/// One "open this in the editor" request for the wide layout's right-hand
/// panel — the same arguments `showTaskSheet` takes. [serial] makes every
/// request a fresh editor, even when the same task is opened twice.
class TaskInspectorRequest {
  const TaskInspectorRequest({
    required this.serial,
    this.task,
    this.duplicateFrom,
    this.templateId,
    this.initialScheduledAt,
    this.initialTimeOfDay,
    this.draft,
  });

  final int serial;
  final Task? task;
  final Task? duplicateFrom;
  final String? templateId;
  final DateTime? initialScheduledAt;
  final TimeOfDay? initialTimeOfDay;

  /// A Timeline quick-create draft, edited in place of the phone's
  /// quick-create sheet; its pill stays on the Timeline, linked.
  final PendingTaskDraft? draft;
}

/// What the wide layout's right-hand panel is editing — null when it's
/// closed. Requested directly, against a desktop-calendar reference: "on
/// the right, if the user clicks an item, this is how they would create
/// it... if they click an existing one, this is how they would edit it."
class TaskInspectorNotifier extends Notifier<TaskInspectorRequest?> {
  @override
  TaskInspectorRequest? build() => null;

  int _hosts = 0;
  int _serial = 0;
  Future<bool> Function()? _leaveGuard;

  /// Whether a `TaskInspectorPanel` is on screen. `showTaskSheet` opens the
  /// panel only then, and a bottom sheet otherwise.
  bool get hasHost => _hosts > 0;

  void attachHost() => _hosts++;
  void detachHost() => _hosts--;

  /// The open editor's "may I go?" check — see [open].
  void setLeaveGuard(Future<bool> Function() guard) => _leaveGuard = guard;

  /// Only clears [guard] if it's still the current one: the next editor
  /// registers before the replaced one is disposed.
  void clearLeaveGuard(Future<bool> Function() guard) {
    if (identical(_leaveGuard, guard)) _leaveGuard = null;
  }

  /// Shows a request in the panel. If the current editor has unsaved
  /// edits, it asks first (save / discard / cancel), the same question
  /// closing it asks; on cancel nothing changes and this returns false.
  Future<bool> open({
    Task? task,
    Task? duplicateFrom,
    String? templateId,
    DateTime? initialScheduledAt,
    TimeOfDay? initialTimeOfDay,
    PendingTaskDraft? draft,
  }) async {
    final guard = _leaveGuard;
    if (guard != null && !await guard()) return false;
    state = TaskInspectorRequest(
      serial: ++_serial,
      task: task,
      duplicateFrom: duplicateFrom,
      templateId: templateId,
      initialScheduledAt: initialScheduledAt,
      initialTimeOfDay: initialTimeOfDay,
      draft: draft,
    );
    return true;
  }

  void close() => state = null;
}

final taskInspectorProvider =
    NotifierProvider<TaskInspectorNotifier, TaskInspectorRequest?>(
      TaskInspectorNotifier.new,
    );
