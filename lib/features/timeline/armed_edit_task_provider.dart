import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'armed_edit_task_provider.g.dart';

/// The single task id currently "armed" for editing via a long-press —
/// requested directly: "long press on task should enable its edit mode
/// (duration) wiggle, tapping outside closes that mode, keep single tap to
/// open edit sheet."
///
/// Deliberately separate from [EditModeEnabled] (`edit_mode_provider.dart`)
/// rather than reusing it — that provider is a single GLOBAL switch which,
/// once on, wiggles every task on the Timeline at once via its own toolbar
/// button. This is the opposite shape: exactly one task (or none) is armed
/// at a time, entered by long-pressing that one task specifically, and the
/// rest of the Timeline stays in its ordinary single-tap-opens-sheet state
/// throughout — confirmed via AskUserQuestion as new, per-task behavior,
/// not a second way to trigger the existing global toggle.
///
/// Screen-local, ephemeral UI state — same reasoning and shape as
/// [EditModeEnabled]/[EditSelection]: plain `autoDispose`, never persisted,
/// so a returning user always lands on the ordinary Timeline rather than
/// reopening with a task still armed.
@riverpod
class ArmedEditTask extends _$ArmedEditTask {
  @override
  String? build() => null;

  void arm(String taskId) => state = taskId;

  void clear() {
    if (state == null) return;
    state = null;
  }
}
