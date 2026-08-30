/// Persistence interface for small app-level preferences, mirroring
/// [TaskRepository]/[TrackedBehaviorRepository]'s shape. UI and state never
/// call Hive directly — see CONSTITUTION.md's access-pattern rule.
///
/// Deliberately a **generic key-value store**, not a one-off "theme mode"
/// box: theme mode is simply the first preference to need persisting, and
/// every later one (default task duration, week start day, notification
/// lead time) should land here rather than each growing its own box,
/// adapter, and repository. Keys are plain strings owned by
/// [PreferenceKeys] so they're greppable and can't silently diverge between
/// a read and a write.
///
/// Values are stored as `dynamic` because Hive persists primitives and
/// registered adapter types alike. Callers are expected to use the typed
/// helpers on the concrete implementations (or their own provider-level
/// mapping) rather than passing arbitrary objects — anything stored must be
/// a primitive or have a registered adapter, or Hive throws on write.
abstract class PreferencesRepository {
  /// The stored value for [key], or null if it was never set.
  T? getValue<T>(String key);

  Future<void> setValue<T>(String key, T value);

  Future<void> removeValue(String key);

  /// Every key currently holding a value — mainly for debugging and tests;
  /// no production caller should need to enumerate preferences.
  List<String> keys();
}

/// The canonical preference keys. String constants rather than an enum so
/// the stored key never depends on declaration order, and so a key can be
/// retired without renumbering anything.
abstract final class PreferenceKeys {
  static const String themeMode = 'themeMode';

  /// Whether the first-launch splash/carousel has already been shown.
  /// Absent (null) on a fresh install — the splash shows once, then this
  /// is set true and every later launch skips straight to the app.
  static const String hasSeenSplash = 'hasSeenSplash';

  /// Whether creating/moving a task into a slot that overlaps an existing
  /// task should be rejected rather than allowed. Absent (null) defaults to
  /// true — see [PreventOverlappingTasksSetting].
  static const String preventOverlappingTasks = 'preventOverlappingTasks';

  /// Whether the day view's left-side hour gutter (grid ticks) is shown.
  /// Absent (null) defaults to true — see [ShowHourLabelsSetting].
  static const String showHourLabels = 'showHourLabels';
}
