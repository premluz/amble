import 'package:flutter/material.dart' show ThemeMode;
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/app_theme_mode.dart';
import '../models/task_size.dart';
import '../models/tracked_behavior_view_mode.dart';
import '../repositories/hive_preferences_repository.dart';
import '../repositories/preferences_repository.dart';

part 'preferences_providers.g.dart';

const preferencesBoxName = 'preferences';

@Riverpod(keepAlive: true)
PreferencesRepository preferencesRepository(Ref ref) {
  final box = Hive.box<dynamic>(preferencesBoxName);
  return HivePreferencesRepository(box);
}

/// The app's theme mode, persisted across launches.
///
/// `keepAlive: true` per the Phase 1 decision in docs/DECISIONS.md — this
/// is session-scoped app state read by the root `MaterialApp`, and
/// `autoDispose` caused a real bug where a notifier's own write could be
/// torn down mid-flight. Same reasoning applies here, and more strongly:
/// the root widget is the only listener, so a screen-scoped provider would
/// be wrong by construction.
///
/// Defaults to [AppThemeMode.system] when nothing is stored — a fresh
/// install follows the OS rather than picking a side.
@Riverpod(keepAlive: true)
class ThemeModeSetting extends _$ThemeModeSetting {
  @override
  AppThemeMode build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<AppThemeMode>(PreferenceKeys.themeMode) ??
        AppThemeMode.system;
  }

  Future<void> set(AppThemeMode mode) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.themeMode, mode);
    state = mode;
  }
}

/// Whether the first-launch splash/carousel has already been shown.
///
/// `keepAlive: true` for the same reason as [ThemeModeSetting] — this is
/// read once by the root `MaterialApp` to decide its `home:`, not
/// screen-scoped state. Defaults to `false` (unseen) when nothing is
/// stored, i.e. every fresh install.
@Riverpod(keepAlive: true)
class HasSeenSplash extends _$HasSeenSplash {
  @override
  bool build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<bool>(PreferenceKeys.hasSeenSplash) ??
        false;
  }

  Future<void> markSeen() async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.hasSeenSplash, true);
    state = true;
  }

  /// Debug-only reset so the splash can be re-triggered for screenshots or
  /// manual testing without reinstalling the app or clearing app data.
  /// Never exposed outside a `kDebugMode` gate — see the Settings screen's
  /// "Developer" section.
  Future<void> reset() async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.hasSeenSplash, false);
    state = false;
  }
}

/// Whether creating/moving a task into a slot that overlaps an existing task
/// is blocked (reject-and-snap-back) rather than allowed side by side.
///
/// `keepAlive: true` for the same reason as [ThemeModeSetting]/
/// [HasSeenSplash] — read by the interactive create/edit/drag flows, not
/// screen-scoped state. Unlike those two, this **defaults to true** when
/// nothing is stored: this is a deliberate, confirmed reversal of the
/// previous "overlaps always allowed" default (see docs/DECISIONS.md, post-
/// Phase 9 "Drag shows live start/end times" entry, and the opt-out toggle
/// added after it) — a fresh install should get the stricter behavior
/// unless the user turns it off.
@Riverpod(keepAlive: true)
class PreventOverlappingTasksSetting extends _$PreventOverlappingTasksSetting {
  @override
  bool build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<bool>(PreferenceKeys.preventOverlappingTasks) ??
        true;
  }

  Future<void> set(bool value) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.preventOverlappingTasks, value);
    state = value;
  }
}

/// Whether the day view's left-side hour gutter (the grid of clock-hour
/// ticks) is shown.
///
/// `keepAlive: true` for the same reason as the other settings above — read
/// by the Timeline screen, not screen-scoped state. Defaults to **true**
/// when nothing is stored, so a fresh install keeps the existing gutter
/// rather than silently hiding it.
@Riverpod(keepAlive: true)
class ShowHourLabelsSetting extends _$ShowHourLabelsSetting {
  @override
  bool build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<bool>(PreferenceKeys.showHourLabels) ??
        true;
  }

  Future<void> set(bool value) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.showHourLabels, value);
    state = value;
  }
}

/// Whether the gray thread connecting consecutive tasks
/// (`_TimelineConnectors`) renders on the Spatial Task View. Requested
/// directly — configurable show/hide, Task view only (Zone view has no
/// equivalent connector concept, its containers own child layout
/// directly). Defaults to **true**, matching the connector's existing
/// unconditional-when-`showHourLabels` behavior, so a fresh install is
/// visually unchanged.
@Riverpod(keepAlive: true)
class ShowTimelineConnectorsSetting extends _$ShowTimelineConnectorsSetting {
  @override
  bool build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<bool>(PreferenceKeys.showTimelineConnectors) ??
        true;
  }

  Future<void> set(bool value) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.showTimelineConnectors, value);
    state = value;
  }
}

/// Whether a task's trailing completion checkbox renders at all.
/// Requested directly, and deliberately spanning **all three views** (Task,
/// List, and Zone) from one toggle — unlike
/// [ShowTimelineConnectorsSetting] above, which is Task-view only, since a
/// checkbox that disappeared in one view and not another would read as a
/// bug rather than a setting. Defaults to **true**, matching the
/// checkbox's existing unconditional rendering, so a fresh install is
/// visually unchanged.
///
/// Note: this checkbox is currently the ONLY way to complete a SCHEDULED
/// task — the task detail sheet has no completion control, and the Inbox's
/// own checkbox only covers unscheduled tasks. Turning this off therefore
/// removes the capability, not just the affordance. Shipped as requested,
/// with the Settings copy saying so plainly rather than implying a
/// fallback that doesn't exist.
@Riverpod(keepAlive: true)
class ShowCompletionCheckboxSetting extends _$ShowCompletionCheckboxSetting {
  @override
  bool build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<bool>(PreferenceKeys.showCompletionCheckbox) ??
        true;
  }

  Future<void> set(bool value) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.showCompletionCheckbox, value);
    state = value;
  }
}

/// Which rung of the task-size scale (`TaskSize.sm`/`md`/`lg`) the Timeline
/// renders at — one global setting spanning Task view, List view, and Zone
/// view alike, requested directly ("it's not per view, it's a setting,
/// that when set affects all"). `main.dart` reads this to `copyWith` the
/// right `sizeTaskBadge*`/`textTaskTitle*` pair onto the active
/// `AmbleTheme` before it reaches `MaterialApp`, so every existing call
/// site (`TaskCapsuleBlock`, `ZoneContainerBlock`, `OverlapClusterBlock`)
/// picks it up automatically without itself knowing this setting exists.
/// Defaults to `TaskSize.md` — Task view's own prior fixed size, unchanged
/// for a fresh install.
@Riverpod(keepAlive: true)
class TaskSizeSetting extends _$TaskSizeSetting {
  @override
  TaskSize build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<TaskSize>(PreferenceKeys.taskSize) ??
        TaskSize.md;
  }

  Future<void> set(TaskSize value) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.taskSize, value);
    state = value;
  }
}

/// How the "Tracked" screen's cards render a behavior's completion
/// history (weekly row / monthly grid / six-month heatmap) — one global
/// setting for the whole screen, cycled by a single switcher button in
/// its own bottom bar, mirroring the Timeline's `TimelineViewMode` cycle
/// button exactly. Defaults to `TrackedBehaviorViewMode.weekly`.
@Riverpod(keepAlive: true)
class TrackedBehaviorViewModeSetting extends _$TrackedBehaviorViewModeSetting {
  @override
  TrackedBehaviorViewMode build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<TrackedBehaviorViewMode>(
              PreferenceKeys.trackedBehaviorViewMode,
            ) ??
        TrackedBehaviorViewMode.weekly;
  }

  Future<void> set(TrackedBehaviorViewMode value) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.trackedBehaviorViewMode, value);
    state = value;
  }
}

/// Whether the Timeline renders in Zone view — Zones as real layout
/// containers owning their child tasks' positions (see
/// `ZoneContainerBlock`) — instead of the default Task view (where Zones
/// are purely decorative background, see `ZoneBackgroundBlock`).
///
/// `keepAlive: true` for the same reason as the other settings above.
/// Defaults to **false** when nothing is stored, so a fresh install (or an
/// existing one) keeps today's Task view unless the user opts in. Only
/// ever surfaced as a Settings toggle when `FeatureFlags.zoneEnabled` is
/// also true — the setting itself has no opinion on the flag; the
/// Settings screen decides visibility.
@Riverpod(keepAlive: true)
class ZoneViewEnabledSetting extends _$ZoneViewEnabledSetting {
  @override
  bool build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<bool>(PreferenceKeys.zoneViewEnabled) ??
        false;
  }

  Future<void> set(bool value) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.zoneViewEnabled, value);
    state = value;
  }
}

/// Whether 2–3 mutually-overlapping tasks stay individual capsule blocks
/// (naive spatial overlap) instead of being replaced by one aggregate
/// `OverlapClusterBlock`.
///
/// `keepAlive: true` for the same reason as the other settings above — read
/// by the Timeline screen, not screen-scoped state. Defaults to **false**
/// when nothing is stored, i.e. clustering is ON for a fresh install —
/// matches how [PreventOverlappingTasksSetting] defaults to the newer,
/// more-structured behavior rather than requiring an opt-in.
@Riverpod(keepAlive: true)
class DisableOverlapClusteringSetting
    extends _$DisableOverlapClusteringSetting {
  @override
  bool build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<bool>(PreferenceKeys.disableOverlapClustering) ??
        false;
  }

  Future<void> set(bool value) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.disableOverlapClustering, value);
    state = value;
  }
}

/// Which device calendars' events display (read-only) on the Timeline —
/// Feature 1 of CONSTITUTION.md's "Calendar" section, a multi-select
/// SOURCE list distinct from [CalendarSyncTargetIdSetting]'s single
/// DESTINATION calendar.
///
/// `keepAlive: true` for the same reason as the other settings above —
/// read by the Timeline screen, not screen-scoped state. Defaults to an
/// empty list when nothing is stored, so a fresh install (or one where the
/// user has never opened Settings' Calendar section) shows no external
/// events, matching the Timeline's previous calendar-free behavior.
@Riverpod(keepAlive: true)
class CalendarDisplayIdsSetting extends _$CalendarDisplayIdsSetting {
  @override
  List<String> build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<List<String>>(PreferenceKeys.calendarDisplayIds) ??
        const [];
  }

  Future<void> set(List<String> calendarIds) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.calendarDisplayIds, calendarIds);
    state = calendarIds;
  }
}

/// The single device calendar Amble tasks sync OUT to — Feature 2, a
/// single-select DESTINATION distinct from [CalendarDisplayIdsSetting]'s
/// multi-select SOURCE list above. Null means no target chosen yet.
@Riverpod(keepAlive: true)
class CalendarSyncTargetIdSetting extends _$CalendarSyncTargetIdSetting {
  @override
  String? build() {
    return ref
        .read(preferencesRepositoryProvider)
        .getValue<String>(PreferenceKeys.calendarSyncTargetId);
  }

  Future<void> set(String? calendarId) async {
    if (calendarId == null) {
      await ref
          .read(preferencesRepositoryProvider)
          .removeValue(PreferenceKeys.calendarSyncTargetId);
    } else {
      await ref
          .read(preferencesRepositoryProvider)
          .setValue(PreferenceKeys.calendarSyncTargetId, calendarId);
    }
    state = calendarId;
  }
}

/// The user-configured Slack Incoming Webhook URL for the automatic
/// morning summary — a plain, user-managed webhook, not an Amble-side
/// Slack app/OAuth connection. Absent (null) means the feature has nothing
/// to send to yet, independent of whether [SlackSummaryEnabledSetting] is
/// on — the two are deliberately separate flags (see that provider's own
/// doc comment) rather than one setting inferred from "URL is non-empty."
@Riverpod(keepAlive: true)
class SlackWebhookUrlSetting extends _$SlackWebhookUrlSetting {
  @override
  String? build() {
    return ref
        .read(preferencesRepositoryProvider)
        .getValue<String>(PreferenceKeys.slackWebhookUrl);
  }

  Future<void> set(String? value) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await ref
          .read(preferencesRepositoryProvider)
          .removeValue(PreferenceKeys.slackWebhookUrl);
      state = null;
      return;
    }
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.slackWebhookUrl, trimmed);
    state = trimmed;
  }
}

/// Whether the automatic morning summary is enabled. Defaults to **false**
/// — requested directly: pasting a webhook URL alone must not silently
/// turn on background sending; the user opts in explicitly. Read by the
/// background task registration in `core/background/background_tasks.dart`
/// to decide whether to (de)register the periodic task, and by the manual
/// "Send test message" button's own availability (a test send still needs
/// a URL, but doesn't require this toggle to be on — see the Settings
/// screen).
@Riverpod(keepAlive: true)
class SlackSummaryEnabledSetting extends _$SlackSummaryEnabledSetting {
  @override
  bool build() {
    return ref
            .read(preferencesRepositoryProvider)
            .getValue<bool>(PreferenceKeys.slackSummaryEnabled) ??
        false;
  }

  Future<void> set(bool value) async {
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.slackSummaryEnabled, value);
    state = value;
  }
}

/// Optional display-name override (Slack's `username` payload field).
/// Absent/blank omits the field entirely — see
/// `buildSlackPayload`'s own doc comment.
@Riverpod(keepAlive: true)
class SlackDisplayNameSetting extends _$SlackDisplayNameSetting {
  @override
  String? build() {
    return ref
        .read(preferencesRepositoryProvider)
        .getValue<String>(PreferenceKeys.slackDisplayName);
  }

  Future<void> set(String? value) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await ref
          .read(preferencesRepositoryProvider)
          .removeValue(PreferenceKeys.slackDisplayName);
      state = null;
      return;
    }
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.slackDisplayName, trimmed);
    state = trimmed;
  }
}

/// Optional icon-emoji override (Slack's `icon_emoji` payload field).
/// Same absent/blank-omits-the-field behavior as
/// [SlackDisplayNameSetting].
@Riverpod(keepAlive: true)
class SlackIconEmojiSetting extends _$SlackIconEmojiSetting {
  @override
  String? build() {
    return ref
        .read(preferencesRepositoryProvider)
        .getValue<String>(PreferenceKeys.slackIconEmoji);
  }

  Future<void> set(String? value) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await ref
          .read(preferencesRepositoryProvider)
          .removeValue(PreferenceKeys.slackIconEmoji);
      state = null;
      return;
    }
    await ref
        .read(preferencesRepositoryProvider)
        .setValue(PreferenceKeys.slackIconEmoji, trimmed);
    state = trimmed;
  }
}

/// Maps the persisted [AppThemeMode] onto Flutter's own [ThemeMode].
///
/// Kept as the single translation point between our stored enum and the
/// framework's, so the storage format stays independent of Flutter's
/// declaration order (see [AppThemeMode]'s doc comment).
ThemeMode toFlutterThemeMode(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
};
