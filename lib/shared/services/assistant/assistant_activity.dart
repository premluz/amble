import 'assistant_tool.dart';

/// One change an assistant made, for Settings › Claude's activity list.
class AssistantActivity {
  AssistantActivity({required this.at, required this.summary, this.undo});

  final DateTime at;
  final String summary;

  /// Puts the plan back as it was; null once used.
  Future<void> Function()? undo;
}

/// The assistant's recent changes, newest first, kept for this session only
/// (a persisted log is a later decision). Capped at
/// [AssistantLimits.activityCapacity].
class AssistantActivityLog {
  AssistantActivityLog(this._clock);

  final DateTime Function() _clock;
  final _entries = <AssistantActivity>[];
  final _listeners = <void Function(AssistantActivity)>[];

  List<AssistantActivity> get entries => List.unmodifiable(_entries);

  /// Called for every new entry, so the app can show an Undo toast.
  void addListener(void Function(AssistantActivity) listener) =>
      _listeners.add(listener);

  void removeListener(void Function(AssistantActivity) listener) =>
      _listeners.remove(listener);

  void record(String summary, {Future<void> Function()? undo}) {
    final entry = AssistantActivity(at: _clock(), summary: summary, undo: undo);
    _entries.insert(0, entry);
    if (_entries.length > AssistantLimits.activityCapacity) {
      _entries.removeLast();
    }
    for (final listener in List.of(_listeners)) {
      listener(entry);
    }
  }

  /// Reverses [entry] once. Throws if it has no undo or was already undone,
  /// so a double tap can't move a task twice.
  Future<void> undo(AssistantActivity entry) async {
    final action = entry.undo;
    if (action == null) {
      throw StateError('"${entry.summary}" cannot be undone again.');
    }
    entry.undo = null;
    await action();
  }
}
