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
  // Default changed to `inline` — requested directly.
  @override
  TimelineTaskTextLayout build() => TimelineTaskTextLayout.inline;

  void set(TimelineTaskTextLayout value) => state = value;
}

/// The bell/repeat/moved/tracked-behavior icon row under a task's
/// time/duration line (see `_capsuleIcons` in task_capsule_block.dart).
@Riverpod(keepAlive: true)
class DevTimelineTaskIconsVisible extends _$DevTimelineTaskIconsVisible {
  // Default changed to false (no status icon row) — requested directly.
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// The `(45m)`-style duration suffix on a task's time line.
@Riverpod(keepAlive: true)
class DevTimelineTaskDurationVisible extends _$DevTimelineTaskDurationVisible {
  // Default changed to false (no duration shown) — requested directly.
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Vertical timeline scale — pixels per minute — for the Spatial Task
/// View. Requested directly as a scratch config so the right value can be
/// dialed in live, separate from the Zone view's own scale below: at the
/// Task view's original fixed 1.5, a short (e.g. 30-minute) Zone-view
/// container barely fit its own header, let alone a task row, which is
/// what caused the reported "missing gap between adjacent zones" (the
/// container was forced to grow past its gap-shrunk floor on nearly every
/// zone, not just unusually packed ones).
@Riverpod(keepAlive: true)
class DevTaskViewPixelsPerMinute extends _$DevTaskViewPixelsPerMinute {
  @override
  double build() => 1.5;

  void set(double value) => state = value;
}

/// Same as [DevTaskViewPixelsPerMinute], for the Spatial Zone View —
/// independently adjustable, not derived from the Task view's own value.
///
/// Previously defaulted to double the Task view's (3.0) — a short (e.g.
/// 30-minute) Zone-view container barely fit its own header, let alone a
/// task row, at 1.5. Default changed to 1.5 anyway (matching the Task
/// view's own) per direct request; the two remain independently
/// adjustable at runtime if that constraint bites again.
@Riverpod(keepAlive: true)
class DevZoneViewPixelsPerMinute extends _$DevZoneViewPixelsPerMinute {
  @override
  double build() => 1.5;

  void set(double value) => state = value;
}

/// Whether `FreeWindowBlock` (the "1h 40m window, add a task" prompt
/// shown for large gaps between tasks on the Task view) renders at all.
/// Requested directly as a scratch on/off toggle.
@Riverpod(keepAlive: true)
class DevShowFreeWindowPrompt extends _$DevShowFreeWindowPrompt {
  // Default changed to false (no free-window prompt) — requested directly.
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Whether Zone view is reachable at all from the Timeline's own
/// view-cycle button.
///
/// **Default flipped back to OFF as of 2026-09-06** (confirmed directly,
/// same day as the ON flip below): after Zone move/resize/selection work
/// landed in the Spatial Task View too, Zone view was confirmed as frozen
/// going forward ("zone view as default disabled > no further updates to
/// this view") — it gets no further iteration, so it goes back to hidden
/// by default rather than staying reachable as an unmaintained surface.
///
/// (Briefly flipped ON earlier the same day, after a real report — "can't
/// move zones" — traced back to this toggle defaulting off at a point
/// when Zone view's move/resize genuinely was the ONLY place zone editing
/// existed. That's no longer true now that Task view has its own zone
/// move/resize/selection, so the original reason to default this on no
/// longer applies.)
///
/// ANDs into the existing `FeatureFlags.zoneEnabled` gate rather than
/// replacing it (see `day_strip.dart`), so it can only ever REMOVE Zone
/// view from the cycle, never force it on where the feature flag itself
/// says no. Turning it off while Zone view happens to be the active mode
/// also falls back to Task view, rather than stranding the user in a mode
/// the button can no longer cycle out of.
@Riverpod(keepAlive: true)
class DevZoneViewInCycle extends _$DevZoneViewInCycle {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Whether the "Tracked" bottom-nav tab is reachable at all. Mirrors
/// [DevZoneViewInCycle] exactly: default ON (matching
/// `FeatureFlags.trackedBehaviorEnabled`'s own new default), a debug-only
/// escape hatch to hide the tab again at runtime without a rebuild —
/// requested directly, alongside flipping the flag's default itself.
///
/// ANDs into the existing `FeatureFlags.trackedBehaviorEnabled` gate
/// rather than replacing it (see `main.dart`), so it can only ever REMOVE
/// the tab, never force it on where the flag itself says no. Turning it
/// off while the Tracked tab happens to be the selected one falls back to
/// a valid tab rather than stranding the user on an index that no longer
/// exists — see `_AmbleHomeState`'s own handling.
@Riverpod(keepAlive: true)
class DevTrackedTabInCycle extends _$DevTrackedTabInCycle {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

/// Whether Edit Mode's multi-task selection route is active — requested
/// directly as a "configurable" alternative to the single-task Edit Mode
/// that already ships (see `edit_mode_provider.dart`/CONSTITUTION.md's
/// "Edit Mode" section). With this on, tap becomes select/deselect
/// (wiggle becomes the SELECTION indicator instead of the mode indicator
/// — only selected blocks wiggle), and drag/resize/delete on any selected
/// block acts on the whole selection. With it off, Edit Mode is
/// byte-for-byte the existing single-task behavior (every block wiggles,
/// tap opens the detail sheet, drag/resize/delete each act on one task).
///
/// **Default flipped to ON as of 2026-09-06** (confirmed directly — "turn
/// on as default multi edit view"), reversing this provider's own
/// original default-off launch decision.
///
/// Deliberately debug-only for now, same reasoning as
/// [DevTimelineTaskTextLayout] above: this is a big, still-settling
/// interaction model, not yet a finished product feature — promoting it
/// to a real `PreferenceKeys` setting (or a `FeatureFlags` gate) is a
/// separate, later decision once the model has been used for a while.
/// Unlike [DevZoneViewInCycle]/[DevTrackedTabInCycle] (which AND into an
/// already-shipped `FeatureFlags` gate), there is no such gate here to AND
/// into — this provider IS the only on/off switch multi-task mode has.
@Riverpod(keepAlive: true)
class DevMultiTaskEditMode extends _$DevMultiTaskEditMode {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

/// True only in a debug build — the single guard every read site above
/// must be wrapped in. A plain re-export of `kDebugMode` so call sites
/// import one file for both the flag and the gate.
const bool isDevConfigAvailable = kDebugMode;
