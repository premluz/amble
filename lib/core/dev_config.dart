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

/// List view only — a standalone `1h`-style duration label per row (see
/// [DevTimelineTaskTimeRangeVisible] for the separate from-to time
/// setting). The two are independent: either, both, or neither can be on.
///
/// Task view's own split-layout duration column
/// (`TaskCapsuleTextRow.durationVisible`'s non-`compactInlineLayout`
/// branch) is untouched by this provider — confirmed directly: "these
/// should affect list view only and should not affect task spatial view
/// (on this view we'd never show this)." Previously this same provider
/// fed BOTH a List-view duration suffix appended onto the time string AND
/// Task view's split-layout column, conflating two different views'
/// concerns in one flag; the List-view half of that is what this
/// doc comment (and `TaskCapsuleTextRow`'s own `compactInlineLayout`
/// branch) now describes — the Task-view half is unchanged.
@Riverpod(keepAlive: true)
class DevTimelineTaskDurationVisible extends _$DevTimelineTaskDurationVisible {
  // Default changed to false (no duration shown) — requested directly.
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// List view only — the `04:20 - 05:20`-style time range per row.
/// Independent of [DevTimelineTaskDurationVisible] — see that provider's
/// own doc comment. Requested directly: "we should add setting show time
/// from to (should then show time)... these should affect list view only
/// and should not affect task spatial view."
///
/// **Default flipped to OFF as of 2026-09-10** (confirmed directly —
/// "show time off as default"), reversing its original launch default
/// (which matched List view's previous always-shown time range before
/// this toggle existed).
@Riverpod(keepAlive: true)
class DevTimelineTaskTimeRangeVisible
    extends _$DevTimelineTaskTimeRangeVisible {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// List view AND Zone view — when on, hides every imported calendar event
/// (`ExternalCalendarEvent`) from both, showing only native Amble [Task]s.
/// Originally "Only Amble tasks", List-view-only — **replaced 2026-09-10**
/// (requested directly: "add hide imported tasks control in dev mode and
/// that'd be affecting zone and list view and replace switch (amble tasks
/// only)"): renamed to describe what it actually does (hides imports,
/// rather than a positive "only these") and widened to also apply to Zone
/// view. Task view is still unaffected — it keeps mixing imported events
/// into its own layout exactly as today.
///
/// Defaults to false (current shipped behavior: both views already mix
/// imported events in, same as Task view) — this toggle only ever REMOVES
/// events, never adds a display mode that didn't exist.
@Riverpod(keepAlive: true)
class DevHideImportedTasks extends _$DevHideImportedTasks {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Zone (grid) view only — when on, strips [ZoneContainerBlock]'s own
/// background fill/border AND its padding, leaving just the bare title +
/// duration header directly above its flat list of member task/event
/// rows, with no card chrome around either. Requested directly: "add a
/// control in admin that affects the grid zone view and removes the
/// background from zones and[,] uh, padding as well[;] so what's left is
/// a title[,] and underneath the tasks related inside this zone[,] and
/// duration[,] of course, also stays."
///
/// Task view's `ZoneBackgroundBlock` (the purely decorative fill on the
/// Spatial Task View) is unaffected — this only touches the Zone view's
/// own real layout container, which is the one actually described as a
/// "card" with a background/padding to remove.
///
/// Defaults to false (current shipped behavior: the card fill/padding
/// stays) — this toggle only ever REMOVES chrome, never adds a display
/// mode that didn't exist.
@Riverpod(keepAlive: true)
class DevZoneCardFlat extends _$DevZoneCardFlat {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// List view only — when on, hides every [Task] with `isImportant == false`
/// from the row list. Requested directly as "config (only important)",
/// alongside [DevHideImportedTasks] above. Task view and Zone view
/// are unaffected — both show every task regardless of this toggle.
///
/// Imported calendar events have no `isImportant` concept at all, so this
/// toggle never touches them either way — it only filters [Task] rows.
/// Independent of [DevHideImportedTasks]: both, either, or neither
/// can be on, same "independent toggles" shape as the duration/time-range
/// pair above.
///
/// Defaults to false (current shipped behavior: List view shows every
/// task, important or not).
@Riverpod(keepAlive: true)
class DevTimelineListOnlyImportant extends _$DevTimelineListOnlyImportant {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Vertical timeline scale — pixels per minute — for the Spatial Task
/// View. Requested directly as a scratch config so the right value can be
/// dialed in live, separate from the Zone view's own scale below: at the
/// Task view's original fixed 1.5, a short (e.g. 30-minute) Zone-view
/// container barely fit itsS own header, let alone a task row, which is
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

/// Whether List view is reachable at all from the Timeline's own
/// view-cycle button — **replaces the old `DevZoneViewInCycle`**
/// (2026-09-10, requested directly: "we have setting zone view off in dev
/// switching timeline cycles, but actually that'd be list view off now,
/// zone view and task view are on always, and list view as default off").
/// Zone view no longer has a debug-only way to be hidden from the cycle
/// at all — its reachability now depends purely on
/// `FeatureFlags.zoneEnabled`, same as a release build. Task view is
/// never skippable either (see `day_strip.dart`'s own `next()`). List
/// view is the only mode this toggle can remove, and it defaults to
/// OFF — the opposite of Zone view's own old on-by-default-then-off
/// history, since List view is the one being newly excluded by default
/// here, not Zone view being newly frozen.
///
/// Turning it off while List view happens to be the active mode falls
/// back to Task view, rather than stranding the user in a mode the
/// button can no longer cycle out of — same "don't strand the user"
/// contract the old Zone toggle had.
@Riverpod(keepAlive: true)
class DevListViewInCycle extends _$DevListViewInCycle {
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
