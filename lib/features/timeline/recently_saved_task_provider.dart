import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What just happened to a task the user saved, so the Timeline can show
/// the change rather than having it appear fully-formed the instant the
/// modal closes. Requested directly: "after closing modal only then the
/// task fades in (with easing) or extends pill (change duration case) so
/// user can see it happening."
enum SavedTaskChange {
  /// A task that didn't exist before — fades in.
  created,

  /// An existing task whose duration changed — its pill grows/shrinks
  /// into the new height instead of snapping to it.
  durationChanged,
}

/// The task the create/edit modal most recently saved, and how it
/// changed. Set by the modal just before it pops; consumed (and cleared)
/// by the Timeline once it has played the corresponding animation.
class RecentlySavedTask {
  const RecentlySavedTask({
    required this.taskId,
    required this.change,
    this.previousDurationMinutes,
  });

  final String taskId;
  final SavedTaskChange change;

  /// The duration the task had BEFORE this save, for
  /// [SavedTaskChange.durationChanged] only. The Timeline renders the pill
  /// at this height until the modal has finished closing, then lets it
  /// animate to the real value — otherwise the resize happens behind the
  /// modal and there's nothing left to see.
  final int? previousDurationMinutes;
}

/// Screen-local UI state, not app-level — lives under features/timeline/
/// alongside `SelectedDate`, per the distinction drawn in
/// docs/DECISIONS.md (Phase 1). Deliberately hand-written rather than
/// `@riverpod`-generated: it holds transient presentation state with no
/// dependencies, and adding it to the codegen set would mean a
/// build_runner pass for what is a single nullable field.
class RecentlySavedTaskNotifier extends Notifier<RecentlySavedTask?> {
  @override
  RecentlySavedTask? build() => null;

  void record(
    String taskId,
    SavedTaskChange change, {
    int? previousDurationMinutes,
  }) {
    state = RecentlySavedTask(
      taskId: taskId,
      change: change,
      previousDurationMinutes: previousDurationMinutes,
    );
  }

  /// Called by the Timeline once it has consumed the value, so the same
  /// animation can't replay on an unrelated later rebuild.
  void clear() => state = null;
}

final recentlySavedTaskProvider =
    NotifierProvider<RecentlySavedTaskNotifier, RecentlySavedTask?>(
      RecentlySavedTaskNotifier.new,
    );
