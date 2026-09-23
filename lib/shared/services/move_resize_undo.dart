import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_undo_toast.dart';
import '../models/task.dart';
import '../models/zone.dart';
import '../providers/task_providers.dart';
import '../providers/zone_providers.dart';

/// Snapshot-then-restore undo for every task/zone MOVE and RESIZE commit —
/// requested directly: "let's wire the current undo build for resize and
/// move actions." Same mechanism `removeTask`'s own undo already
/// established for delete (`features/task_detail/task_remove.dart`):
/// every affected row is captured via its own `toJson()` BEFORE the real
/// write runs, and `onUndo` restores each one via `fromJson` + a plain
/// keyed re-save (`TaskList.restoreTasksInBatch`/`ZoneList
/// .restoreZonesInBatch`) — the same round-trip export/import already
/// proves correct, not a separate undo stack or history. Restore uses
/// the BATCH re-save methods, not a loop of single-item `updateTask`/
/// `updateZone` calls, so a multi-row Undo reappears in one shared
/// frame rather than one row at a time — reported directly, "when they
/// reappear also not at once" (2026-09-22).
///
/// **Every commit shows a toast, including a plain single-task move with
/// no cascade** (confirmed via AskUserQuestion, over the alternative of
/// only toasting a multi-task cascade/group commit) — matches delete's
/// own "every write gets a toast" consistency rather than being
/// selective about which commits are "big enough" to warrant one.
///
/// A cascade/group commit can touch tasks the user never directly
/// dragged (a pushed neighbour, every other selected task) — the
/// snapshot always covers every id the commit is ABOUT to touch, taken
/// immediately before the real write, so Undo restores the whole
/// operation atomically in one toast, not just the one task that was
/// actually under the finger.

/// Snapshots [taskIds] (via [Task.toJson]) from the CURRENT
/// `taskListProvider` state, then runs [commit] (the real,
/// already-existing write — `rescheduleTask`/`rescheduleTaskWithCascade`/
/// `resizeTasksInBatch`/`resizeTasksFromTopInBatch`, unchanged), then
/// shows an undo toast whose `onUndo` restores every snapshotted task.
///
/// [context] must be a genuine descendant of the app's root Overlay (see
/// docs/DESIGN_SYSTEM.md's `AppUndoToast` "Never" line) — every call site
/// here is a still-mounted screen's own context, never a
/// `navigatorKey.currentContext`, so this never needs a separate
/// `rootContext` param the way a sheet that pops itself does.
Future<void> commitTaskChangeWithUndo(
  BuildContext context,
  WidgetRef ref, {
  required Iterable<String> taskIds,
  required String message,
  required Future<void> Function() commit,
}) async {
  final notifier = ref.read(taskListProvider.notifier);
  final byId = {for (final t in ref.read(taskListProvider)) t.id: t};
  final snapshots = [
    for (final id in taskIds)
      if (byId[id] case final task?) task.toJson(),
  ];

  await commit();

  if (!context.mounted) return;
  AppUndoToast.show(
    context: context,
    message: message,
    onUndo: () => notifier.restoreTasksInBatch(snapshots.map(Task.fromJson)),
  );
}

/// Zone counterpart of [commitTaskChangeWithUndo] — via [Zone.toJson]/
/// [Zone.fromJson] and [ZoneList.updateZone] instead of [Task]'s. Also
/// accepts [taskIds] because a zone cascade can shift assigned tasks
/// along with it (`ZoneList.commitZoneCascade`'s own
/// `shiftTasksByMinutes` call) — both snapshots are taken before the ONE
/// combined write, and Undo restores zones and tasks together in the
/// same single toast, matching how the commit itself is one atomic
/// operation from the user's own perspective.
Future<void> commitZoneChangeWithUndo(
  BuildContext context,
  WidgetRef ref, {
  required Iterable<String> zoneIds,
  Iterable<String> taskIds = const [],
  required String message,
  required Future<void> Function() commit,
}) async {
  final zoneNotifier = ref.read(zoneListProvider.notifier);
  final taskNotifier = ref.read(taskListProvider.notifier);
  final zonesById = {for (final z in ref.read(zoneListProvider)) z.id: z};
  final tasksById = {for (final t in ref.read(taskListProvider)) t.id: t};
  final zoneSnapshots = [
    for (final id in zoneIds)
      if (zonesById[id] case final zone?) zone.toJson(),
  ];
  final taskSnapshots = [
    for (final id in taskIds)
      if (tasksById[id] case final task?) task.toJson(),
  ];

  await commit();

  if (!context.mounted) return;
  AppUndoToast.show(
    context: context,
    message: message,
    onUndo: () async {
      await zoneNotifier.restoreZonesInBatch(zoneSnapshots.map(Zone.fromJson));
      await taskNotifier.restoreTasksInBatch(taskSnapshots.map(Task.fromJson));
    },
  );
}
