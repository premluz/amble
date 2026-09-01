import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dev_config.g.dart';

/// Runtime-toggleable dev scratch config — for trying out layout variants
/// live (e.g. "2 layouts for the task capsule's text") without a rebuild.
///
/// `kDebugMode`-gated, not `FeatureFlags`/`bool.fromEnvironment`, same
/// reasoning as the Settings screen's "Developer" section (see
/// docs/DECISIONS.md): this is a developer convenience that must never
/// exist in a real build at all, not a product feature that's sometimes on
/// per build config. Every read site in production code is (or must be)
/// wrapped in `if (kDebugMode)`, so the whole subtree dead-code-eliminates
/// in release/profile builds regardless of these defaults.
///
/// Deliberately in-memory only (plain `Riverpod` state, not
/// `PreferencesRepository`/Hive) — this is scratch config for comparing
/// options while iterating, not a real user setting, so it resets on every
/// app restart and never touches `PreferenceKeys` (which is real,
/// persisted, user-facing state).
enum TimelineTaskTextLayout {
  /// Current default: title on its own line, time+duration on the line
  /// below it.
  stacked,

  /// Time+duration first, then the title, on one line.
  inline,
}

@Riverpod(keepAlive: true)
class DevTimelineTaskTextLayout extends _$DevTimelineTaskTextLayout {
  @override
  TimelineTaskTextLayout build() => TimelineTaskTextLayout.stacked;

  void set(TimelineTaskTextLayout value) => state = value;
}

/// The bell/repeat/moved/tracked-behavior icon row under a task's
/// time/duration line (see `_capsuleIcons` in task_capsule_block.dart).
@Riverpod(keepAlive: true)
class DevTimelineTaskIconsVisible extends _$DevTimelineTaskIconsVisible {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

/// The `(45m)`-style duration suffix on a task's time line.
@Riverpod(keepAlive: true)
class DevTimelineTaskDurationVisible extends _$DevTimelineTaskDurationVisible {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

/// True only in a debug build — the single guard every read site above
/// must be wrapped in. A plain re-export of `kDebugMode` so call sites
/// import one file for both the flag and the gate.
const bool isDevConfigAvailable = kDebugMode;
