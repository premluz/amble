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

  /// Whether the onboarding Profile quiz (separate from, and shown after,
  /// the splash/carousel above) has been completed OR explicitly skipped —
  /// both count as "done" per docs/SCOPE.md's "onboarding is skippable,
  /// never blocking" rule. Absent (null) on a fresh install — the quiz
  /// shows once, then this is set true regardless of whether the user
  /// chose a profile or skipped, and every later launch goes straight to
  /// the app. See [HasCompletedOnboarding].
  static const String hasCompletedOnboarding = 'hasCompletedOnboarding';

  /// Whether creating/moving a task into a slot that overlaps an existing
  /// task should be rejected rather than allowed. Absent (null) defaults to
  /// true — see [PreventOverlappingTasksSetting].
  static const String preventOverlappingTasks = 'preventOverlappingTasks';

  /// Whether the day view's left-side hour gutter (grid ticks) is shown.
  /// Absent (null) defaults to true — see [ShowHourLabelsSetting].
  static const String showHourLabels = 'showHourLabels';

  /// Whether 2–3 mutually-overlapping tasks render as individual capsules
  /// (naive spatial overlap) instead of one aggregate
  /// `OverlapClusterBlock`. Absent (null) defaults to false — clustering is
  /// ON by default. See [DisableOverlapClusteringSetting].
  static const String disableOverlapClustering = 'disableOverlapClustering';

  /// Whether the app's dual-font system (DM Sans for general text,
  /// JetBrains Mono for numeric/temporal labels and zone names — see
  /// `TypePrimitives`) is active. When off, every mono-bound token resolves
  /// to DM Sans instead, so the whole app reads as one font. Absent (null)
  /// defaults to true — dual-font is ON by default. See [DualFontSetting].
  static const String dualFontEnabled = 'dualFontEnabled';

  /// Whether the 5 built-in [Category] rows have been seeded into the
  /// `categories` Hive box and every existing [Task]'s deprecated
  /// `category` enum value has been backfilled onto its new `categoryId`.
  /// Absent (null) defaults to false — a fresh install or an existing
  /// install upgrading to this version both run the one-time seed/backfill
  /// exactly once, gated by this flag (see `main.dart`).
  static const String categoriesSeeded = 'categoriesSeeded';

  /// Whether the Timeline renders in Zone view (Zones as real layout
  /// containers) instead of the default Task view. Absent (null) defaults
  /// to false — see [ZoneViewEnabledSetting]. Only ever surfaced in
  /// Settings when `FeatureFlags.zoneEnabled` is also true.
  static const String zoneViewEnabled = 'zoneViewEnabled';

  /// Whether the "What Matters" lens is on — hides every [Task] with
  /// `isImportant == false` entirely, in both Timeline display modes.
  /// Absent (null) defaults to false. See [WhatMattersEnabledSetting].
  static const String whatMattersEnabled = 'whatMattersEnabled';

  /// Whether the gray thread connecting consecutive tasks renders on the
  /// Spatial Task View. Absent (null) defaults to true — see
  /// [ShowTimelineConnectorsSetting]. Task view only (Zone view has no
  /// equivalent connector); already gated by `showHourLabels`, this
  /// toggle is a further opt-out within that mode.
  static const String showTimelineConnectors = 'showTimelineConnectors';

  /// Whether a task's trailing completion checkbox renders at all. Absent
  /// (null) defaults to true — see [ShowCompletionCheckboxSetting].
  /// Requested directly as a single setting spanning ALL THREE views (Task,
  /// List, Zone), unlike [showTimelineConnectors] above, which is Task-view
  /// only.
  static const String showCompletionCheckbox = 'showCompletionCheckbox';

  /// Which rung of the task-PILL-size scale (badge/icon diameter only,
  /// see `TaskSize`) the Timeline renders at — Task, List, and Zone view
  /// alike. Absent (null) defaults to `TaskSize.md` — see
  /// [TaskSizeSetting].
  ///
  /// **Split from font size** — requested directly ("separately font
  /// size and separately pill size, let's split this"). Before the split,
  /// this same key/setting ALSO drove the task-title font rung; an
  /// existing value here is now migrated ONCE into [taskFontSize] (see
  /// that key's own doc comment) rather than silently losing the font
  /// half of what a user had already chosen.
  static const String taskSize = 'taskSize';

  /// Which rung of the task-TITLE-FONT scale the Timeline renders at —
  /// Task, List, and Zone view alike, independent of [taskSize]'s own
  /// badge/pill diameter. Absent (null) triggers a ONE-TIME migration
  /// (confirmed via AskUserQuestion): seeded from whatever [taskSize]
  /// currently resolves to (by NAME — `TaskSize.sm` seeds
  /// `TaskFontSize.sm`, etc., mirroring the pairing `_resolveTaskSize` in
  /// main.dart used before this split), so an existing user's font size
  /// doesn't silently change on the upgrade that introduces this as a
  /// separate control. See [TaskFontSizeSetting].
  static const String taskFontSize = 'taskFontSize';

  /// Which corner-rounding a task/zone/Inbox pill badge renders at (see
  /// `PillShape`). One global setting, spanning every pill-shaped surface
  /// in the app. Absent (null) defaults to `PillShape.small` — see
  /// [PillShapeSetting].
  static const String pillShape = 'pillShape';

  /// Whether a Tag's color fills the WHOLE pill or just the small badge
  /// behind its icon (see `TagColorStyle`). One global setting, spanning
  /// every pill-shaped surface in the app. Absent (null) defaults to
  /// `TagColorStyle.pill` (today's existing, unchanged look) — see
  /// [TagColorStyleSetting].
  static const String tagColorStyle = 'tagColorStyle';

  /// How the "Tracked" screen's cards render a behavior's completion
  /// history — see `TrackedBehaviorViewMode`. One global setting for the
  /// whole screen, cycled by a single switcher button, mirroring
  /// `ShowHourLabelsSetting`/`ZoneViewEnabledSetting`'s own role in the
  /// Timeline's view-cycle button. Absent (null) defaults to
  /// `TrackedBehaviorViewMode.weekly` — see
  /// [TrackedBehaviorViewModeSetting].
  static const String trackedBehaviorViewMode = 'trackedBehaviorViewMode';

  /// The user-pasted Slack Incoming Webhook URL for the automatic morning
  /// summary. Absent (null) means no webhook is configured — see
  /// [SlackWebhookUrlSetting]. A plain user-managed webhook URL, not an
  /// Amble-side OAuth/Slack-app connection.
  static const String slackWebhookUrl = 'slackWebhookUrl';

  /// Whether the automatic morning summary is enabled. Absent (null)
  /// defaults to false — a webhook URL alone does not turn the feature on;
  /// the user must explicitly enable it. See [SlackSummaryEnabledSetting].
  static const String slackSummaryEnabled = 'slackSummaryEnabled';

  /// Optional display-name override for the summary message (Slack's
  /// `username` payload field). Absent/blank omits the field entirely from
  /// the payload — see `buildSlackPayload`'s own doc comment for why this
  /// is not defaulted to some fallback name.
  static const String slackDisplayName = 'slackDisplayName';

  /// Optional icon-emoji override (Slack's `icon_emoji` payload field,
  /// e.g. ":sunrise:"). Same absent/blank-omits-the-field behavior as
  /// [slackDisplayName].
  static const String slackIconEmoji = 'slackIconEmoji';

  /// Device calendar ids whose events display (read-only) on the Timeline
  /// — Feature 1 of CONSTITUTION.md's "Calendar" section. Absent (null)
  /// defaults to an empty list — no calendars selected, so nothing is
  /// fetched or shown, matching a fresh install's previous (calendar-free)
  /// Timeline exactly. Stored as `List<String>`, distinct from
  /// [calendarSyncTargetId] below — display (source) and sync (destination)
  /// are deliberately separate settings, never inferred from one another.
  static const String calendarDisplayIds = 'calendarDisplayIds';

  /// The single device calendar Amble tasks are pushed to via manual
  /// "Sync to Calendar" — Feature 2. Absent (null) means no target is
  /// chosen yet; the sync button is disabled until one is set (see
  /// `SettingsScreen`).
  static const String calendarSyncTargetId = 'calendarSyncTargetId';

  /// The Timeline's own vertical time scale — pixels per minute — shared
  /// by BOTH the spatial Task view and the Zone Grid/Edit screen (one
  /// zoom level, not two independent ones; requested directly). Absent
  /// (null) defaults to 1.5 — see [TimelinePixelsPerMinuteSetting].
  /// Supersedes the two previous `kDebugMode`-only, in-memory-only dev
  /// providers (`DevTaskViewPixelsPerMinute`/`DevZoneViewPixelsPerMinute`
  /// in `dev_config.dart`) and the Zone Grid's own previously-hardcoded
  /// `44.0/60` constant, now that pinch-to-zoom makes this a real,
  /// persisted user-facing setting rather than a debug scratch value.
  static const String timelinePixelsPerMinute = 'timelinePixelsPerMinute';

  /// Whether every pre-existing [Task]'s `createdAt` has been backfilled.
  /// Absent (null) defaults to false — a fresh install has nothing to
  /// backfill (every task it ever creates already stamps a real value),
  /// but an existing install upgrading to this version has old rows whose
  /// `createdAt` would otherwise silently read as "now" on every single
  /// launch (the constructor's own `?? DateTime.now()` fallback for
  /// missing on-disk data) — jumping to the top of the newest-first Inbox
  /// sort again and again. Gated exactly like [categoriesSeeded] so the
  /// backfill write happens once, not on every launch. See
  /// `TaskList.backfillCreatedAtIfNeeded` (`main.dart`).
  static const String taskCreatedAtBackfilled = 'taskCreatedAtBackfilled';
}
