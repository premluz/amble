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
///
/// **Briefly flipped to ON on 2026-09-20**, then reverted back to OFF the
/// same day (confirmed directly — "should be disabled as default"). The
/// actual gap that prompted the earlier flip — an imported calendar
/// event's own start time never showing at all in Zone/List view — was a
/// real bug, but the fix for it was alignment, not this toggle: imported
/// events weren't sharing native tasks' own left-escaping
/// [ZoneRowTimeLabel] position at all (see that fix's own entry). This
/// toggle's default going back to OFF is unrelated to that fix and does
/// not reopen it.
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

/// Zone (list) view only — when on, hides every zone container that has
/// no member [Task] AND no matched [ExternalCalendarEvent], leaving only
/// zones that actually contain something. Requested directly: "add config
/// in dev to hide zones that have no items inside in zone view only."
///
/// A deliberate, scoped OVERRIDE of `ZoneContainmentResult.containments`'
/// own documented default ("regardless of whether it has any member
/// tasks, so an empty zone still renders its container per the confirmed
/// spec" — see `zone_containment.dart`) — that default is still correct
/// for the normal case; this is an opt-in dev toggle for comparing the
/// alternative, not a change to the underlying containment logic itself.
///
/// Task view and the Zone (grid) Authoring screen are unaffected — this
/// only touches [ZoneDayTimeline]'s own row list.
///
/// Defaults to true — empty zones are hidden in Zone view unless this
/// developer toggle is turned off.
@Riverpod(keepAlive: true)
class DevHideEmptyZones extends _$DevHideEmptyZones {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

/// Spatial Task View only — when on, restores each zone band's OLD
/// dynamic width: sized off the day's own deepest overlap-lane stack
/// (`_zoneBackgroundWidth`/`dayPillLanes` in `timeline_screen.dart`), so a
/// day with more overlapping tasks widened every zone band. Requested
/// directly, alongside moving the zone name label to render INSIDE the
/// band rather than beside it: "keep that behaviour as toggle in dev
/// mode... default to false and keep same size 100% of available
/// container til right edge."
///
/// **Defaults to false** — every zone band instead spans from
/// `hourGutterWidth` to `rightEdgeInset` (the SAME `left`/`right`, no
/// explicit `width`, mechanism every other full-width Timeline element
/// already uses to reach the true page edge), regardless of lane count.
/// See docs/DESIGN_SYSTEM.md's "Zone pane indicator" section for the full
/// reasoning and `timeline_screen.dart`'s own `_zoneBackgroundRight`
/// call site.
///
/// The Weekly Zone Authoring Grid is unaffected — its own blocks were
/// never lane-width-driven, so this toggle has nothing to do there.
@Riverpod(keepAlive: true)
class DevDynamicZoneWidth extends _$DevDynamicZoneWidth {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Zone view's member task rows ONLY — when on, each row shows just its
/// task's START time (e.g. "9:00 AM"), never the "start - end" range
/// [DevTimelineTaskTimeRangeVisible] shows. Requested directly: "we need
/// to add control show time Start time (zone view), this will add task
/// start time only (we have similar show start end time switch, but this
/// one only start time)."
///
/// A SEPARATE, independent toggle from [DevTimelineTaskTimeRangeVisible]
/// — confirmed via AskUserQuestion — rather than a third value replacing
/// that boolean. If a caller somehow has both on at once, start-time-only
/// WINS (confirmed via AskUserQuestion): it is the more specific request,
/// and [_ZoneTaskRow]'s own branch order enforces this.
///
/// The zone HEADER's own time range is unaffected (confirmed via
/// AskUserQuestion) — this only touches each member task's row, never
/// [ZoneContainerBlock]'s own title/time header.
///
/// **Defaults to true as of 2026-09-20** (requested directly: "keep dev
/// setting hour start as default") — reversing the original "off, adds a
/// display mode" default now that this row's own time text has been
/// aligned/restyled to match the spatial Task view's hour labels
/// (`ZoneRowTimeLabel`, see docs/DESIGN_SYSTEM.md), which was all done
/// under the assumption this is the mode Zone view actually ships with.
/// Still a real, independently toggleable dev setting — this only changes
/// its OUT-OF-THE-BOX state, not whether it can be turned off.
@Riverpod(keepAlive: true)
class DevZoneTaskStartTimeVisible extends _$DevZoneTaskStartTimeVisible {
  @override
  bool build() => true;

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

/// Whether the Tracked/Habits calendar cells show their weekday initials,
/// day numbers, and six-month month captions. Defaults off while the compact
/// cell treatment is being evaluated; the developer setting can restore all
/// labels live without changing the underlying completion grid.
@Riverpod(keepAlive: true)
class DevTrackedCalendarLabelsVisible
    extends _$DevTrackedCalendarLabelsVisible {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Whether Patterns should render synthetic completion history for visual
/// testing. The generated days never touch tasks or pattern data; they only
/// make the calendar treatments easy to inspect with a populated screen.
@Riverpod(keepAlive: true)
class DevTrackedPatternDemoData extends _$DevTrackedPatternDemoData {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Draws a soft circle under every finger, for screen recordings — the
/// app's take on iOS's "show touches", requested directly. Purely visual:
/// touches still reach the app. In-memory only, off by default.
@Riverpod(keepAlive: true)
class DevShowTouches extends _$DevShowTouches {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// How strongly the accent color is rendered on the Patterns screen in
/// debug builds — scoped there, not global (requested directly). In-memory
/// only; applied by `PatternAccentScope`, which pulls the accent toward the
/// theme's base surface.
@Riverpod(keepAlive: true)
class DevAccentStrength extends _$DevAccentStrength {
  static const min = 0.0;
  static const max = 1.0;
  static const defaultValue = max;

  @override
  double build() => defaultValue;

  void set(double value) => state = value.clamp(min, max).toDouble();
}

/// Whether Edit Mode's multi-task selection route is active — requested
/// directly as a "configurable" alternative to the single-task Edit Mode
/// that already ships (see `edit_mode_provider.dart`/CONSTITUTION.md's
/// "Edit Mode" section). With this on, tap becomes select/deselect (an
/// accent selection border becomes the SELECTION indicator instead of
/// the mode indicator — only selected blocks show it), and drag/resize/
/// delete on any selected block acts on the whole selection. With it
/// off, Edit Mode is byte-for-byte the existing single-task behavior
/// (every block shows the border, tap opens the detail sheet, drag/
/// resize/delete each act on one task).
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

/// Whether `main.dart`'s root gate routes a fresh install to the new
/// one-off [SplashScreen] (`features/splash/splash_screen.dart`) instead of
/// the legacy [SplashCarouselScreen]. Requested directly: "put onboarding
/// carousel and questionnaire behind dev toggles, as default we hide
/// them... splash is also under dev toggle" — this is the splash side of
/// that request.
///
/// **Default ON** — the new splash is the intended first-launch
/// experience going forward, unlike [DevLegacyOnboardingCarouselEnabled]/
/// [DevOnboardingQuizEnabled] below, which default OFF. All three are
/// independent switches read directly by `main.dart`'s gate, not ANDed
/// into a `FeatureFlags` entry — there is no compile-time flag for
/// onboarding presentation, only this runtime, debug-only choice.
@Riverpod(keepAlive: true)
class DevNewSplashEnabled extends _$DevNewSplashEnabled {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

/// Whether `main.dart`'s root gate can show the legacy 4-slide
/// [SplashCarouselScreen] at all. Requested directly, alongside
/// [DevOnboardingQuizEnabled] below: "let's put onboarding carousel and
/// questionnaire behind dev toggles, as default we hide them."
///
/// **Default OFF** — reverses this screen's previous unconditional
/// first-launch behavior. With this off, `main.dart` skips straight past
/// where the carousel used to gate, same as [HasSeenSplash] already being
/// true. Turning it on re-enables the original first-launch sequence for
/// that screen specifically, independent of [DevNewSplashEnabled].
@Riverpod(keepAlive: true)
class DevLegacyOnboardingCarouselEnabled
    extends _$DevLegacyOnboardingCarouselEnabled {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Whether `main.dart`'s root gate can show [OnboardingQuizScreen] (the
/// 3-question Profile-catalog quiz) at all — see
/// [DevLegacyOnboardingCarouselEnabled]'s own doc comment for the request
/// this is paired with.
///
/// **Default OFF**, same reasoning as the carousel toggle above. With this
/// off, `main.dart` treats onboarding as already complete regardless of
/// [HasCompletedOnboarding]'s actual stored value, so no Profile ever gets
/// materialized via the quiz path while this is off.
@Riverpod(keepAlive: true)
class DevOnboardingQuizEnabled extends _$DevOnboardingQuizEnabled {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// True only in a debug build — the single guard every read site above
/// must be wrapped in. A plain re-export of `kDebugMode` so call sites
/// import one file for both the flag and the gate.
const bool isDevConfigAvailable = kDebugMode;
