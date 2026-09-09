import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../shared/models/scheduled_block.dart';

const _uuid = Uuid();

/// The duration a quick-add draft starts at — 15 minutes, specified
/// directly ("make it default to 15 minute"). Replaces the earlier reuse
/// of `presetMinutes.first` (5), which produced a pill so short it floored
/// to badge height the moment it appeared.
///
/// Lives here, beside the draft it describes, rather than in the deleted
/// `quick_add_time_labels.dart` where it originally landed.
const quickAddDefaultMinutes = 15;

/// An in-progress, not-yet-persisted task created by tapping empty Timeline
/// space — requested directly: a tap drops a "wiggly gray default task"
/// and opens a small sheet, both of which must agree on one position/
/// duration as the user drags the pill or edits the form's own Date/Time/
/// Duration fields once expanded. [id] is a real client-generated UUID
/// from the start (matching `Task.create`'s own scheme) so the eventual
/// `Task.create` call can reuse it rather than generating a second one,
/// keeping the placeholder and the task it becomes the same identity.
/// Implements [ScheduledBlock] so the placeholder flows through the SAME
/// `layoutOverlappingTasks`/`detectOverlapClusters` pipeline real tasks
/// and imported events do — **2026-09-08**, reversing the original
/// "positioned absolutely over everything, invisible to the layout"
/// design after it was questioned directly. That earlier design conflated
/// two separate things: deferring the live CASCADE preview (a real,
/// confirmed scope decision) and opting out of overlap LAYOUT entirely
/// (never actually decided). The result was a draft that painted on top
/// of tasks it collided with, in a position the Schedule button would
/// then refuse to save — the user got no signal until they pressed it.
///
/// Same precedent, and the same reason, as [ExternalCalendarEvent]
/// implementing this on 2026-09-07: a block that positions itself
/// independently can never agree with the shared layout about who is
/// colliding with whom. Cascade stays save-time only, as originally
/// confirmed — sharing a lane is layout, not cascade.
class PendingTaskDraft implements ScheduledBlock {
  PendingTaskDraft({
    required this.id,
    required this.scheduledAt,
    required this.durationMinutes,
  });

  @override
  final String id;

  final DateTime scheduledAt;
  final int durationMinutes;

  @override
  DateTime get scheduledStart => scheduledAt;

  @override
  DateTime get scheduledEnd =>
      scheduledAt.add(Duration(minutes: durationMinutes));

  PendingTaskDraft copyWith({DateTime? scheduledAt, int? durationMinutes}) =>
      PendingTaskDraft(
        id: id,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        durationMinutes: durationMinutes ?? this.durationMinutes,
      );
}

/// Screen-local UI state, not app-level — same shape and reasoning as
/// `ViewedTimeNotifier`/`RecentlySavedTaskNotifier` (hand-written, not
/// `@riverpod`-generated, for a single transient field). This is the only
/// thing that can carry the draft's position/duration across the
/// `Navigator.push` boundary between Timeline and the pushed task-detail
/// route — `State` can't cross that boundary directly, since the two are
/// separate widget subtrees in the navigation stack. The draft's title is
/// NOT stored here; the sheet's own `_titleController` owns that and only
/// needs to exist within the sheet's own route.
class PendingTaskDraftNotifier extends Notifier<PendingTaskDraft?> {
  @override
  PendingTaskDraft? build() => null;

  void start({required DateTime scheduledAt, required int durationMinutes}) {
    state = PendingTaskDraft(
      id: _uuid.v4(),
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
    );
  }

  void updatePosition(DateTime scheduledAt) {
    final draft = state;
    if (draft == null) return;
    state = draft.copyWith(scheduledAt: scheduledAt);
  }

  void updateDuration(int durationMinutes) {
    final draft = state;
    if (draft == null) return;
    state = draft.copyWith(durationMinutes: durationMinutes);
  }

  void clear() => state = null;
}

final pendingTaskDraftProvider =
    NotifierProvider<PendingTaskDraftNotifier, PendingTaskDraft?>(
      PendingTaskDraftNotifier.new,
    );
