import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../../hive_registrar.g.dart';
import '../../shared/models/task.dart';
import '../../shared/repositories/hive_preferences_repository.dart';
import '../../shared/repositories/hive_task_repository.dart';
import '../../shared/repositories/preferences_repository.dart';
import '../../shared/providers/preferences_providers.dart'
    show preferencesBoxName;
import '../../shared/providers/task_providers.dart' show taskBoxName;
import '../../shared/services/slack_summary_service.dart';

/// Unique name for the periodic morning-summary work request — passed to
/// both `Workmanager().registerPeriodicTask` and `cancelByUniqueName`, and
/// (on iOS) doubles as the BGTaskScheduler identifier, which must appear
/// verbatim in `Info.plist`'s `BGTaskSchedulerPermittedIdentifiers`. Scoped
/// under the app's own bundle-id-style prefix per Apple's convention for
/// BGTaskScheduler identifiers (though this project's actual bundle id is
/// still the placeholder `com.example.amble` — see docs/DECISIONS.md,
/// Phase 9 — this identifier just needs to be unique and registered, not
/// derived from the real bundle id).
const morningSummaryTaskName = 'com.amble.morningSummary';

/// The target local hour for the automatic morning summary. Named per the
/// work order rather than an inline literal — "roughly morning," not a
/// promise of exact delivery (see the reliability notes on both
/// `registerMorningSummaryTask` and the Settings copy).
const morningSummaryTargetHour = 7;

/// Registers (or, if [enabled] is false, cancels) the periodic background
/// task that sends the automatic morning summary. Called from `main.dart`
/// at every launch, mirroring how `TaskList.refreshScheduledNotifications`
/// re-syncs the notification-alarm state on every cold start rather than
/// assuming a stale registration is still correct — same reasoning here:
/// the user may have flipped the Settings toggle since the last launch, or
/// this may be the very first launch since enabling it.
///
/// **Timing is best-effort on both platforms, more so on iOS — this is a
/// known, accepted platform constraint, not a bug.** Android's WorkManager
/// honors [morningSummaryTargetHour] reasonably closely via a computed
/// [Workmanager.registerPeriodicTask]'s `initialDelay` (until the next
/// occurrence of that hour) plus a 24h `frequency`, subject to Doze/battery
/// optimization. **iOS gives no delivery-time guarantee whatsoever**:
/// `BGTaskScheduler` only accepts an `earliestBeginDate` hint (via
/// `initialDelay`) and the OS decides the actual fire time based on usage
/// patterns, battery, and charging state — it may fire hours late, or not
/// fire on a given day at all if the app is never brought to the
/// foreground. See docs/DECISIONS.md for what was actually observed on a
/// real device during this feature's own verification.
Future<void> registerMorningSummaryTask({required bool enabled}) async {
  final workmanager = Workmanager();
  if (!enabled) {
    await workmanager.cancelByUniqueName(morningSummaryTaskName);
    return;
  }

  await workmanager.registerPeriodicTask(
    morningSummaryTaskName,
    morningSummaryTaskName,
    frequency: const Duration(hours: 24),
    initialDelay: _durationUntilNextTargetHour(DateTime.now()),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}

/// How long from [now] until the next occurrence of
/// [morningSummaryTargetHour]:00 local time — today's occurrence if it
/// hasn't passed yet, otherwise tomorrow's. Pure and separately testable
/// from the actual `Workmanager` call, which needs a real platform channel.
@visibleForTesting
Duration durationUntilNextTargetHourForTest(DateTime now) =>
    _durationUntilNextTargetHour(now);

Duration _durationUntilNextTargetHour(DateTime now) {
  var target = DateTime(now.year, now.month, now.day, morningSummaryTargetHour);
  if (!target.isAfter(now)) {
    target = target.add(const Duration(days: 1));
  }
  return target.difference(now);
}

/// The top-level callback `Workmanager` invokes for every background task
/// dispatch, on both platforms — Android's own separate isolate, and iOS's
/// background execution context. `@pragma('vm:entry-point')` is required so
/// AOT compilation doesn't tree-shake this function away, since nothing in
/// the normal app-startup call graph ever calls it directly; the native
/// side invokes it by name.
///
/// **Real gotcha, handled explicitly, not assumed**: this callback runs in
/// a context that has NOT gone through `main()` — no `Hive.initFlutter()`,
/// no adapters registered, no boxes open, none of the Riverpod
/// `ProviderContainer` state `main.dart` builds. Every one of those has to
/// be redone here, from scratch, exactly like `main.dart`'s own init
/// sequence but for only the two boxes this task actually needs
/// (`tasks`, `preferences` — not `trackedBehaviors`/`categories`/`zones`,
/// which this task never reads). Reading `Hive.box<Task>(taskBoxName)`
/// without this re-init throws `HiveError: Box not found` — confirmed by
/// deliberately triggering it once during development (see
/// docs/DECISIONS.md) rather than assumed to be a risk only in theory.
@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != morningSummaryTaskName) return true;
    try {
      await _sendMorningSummary();
      return true;
    } catch (e) {
      // Logged, never rethrown, per the work order's explicit split:
      // background-task failures are silently skipped (no crash, no
      // disruptive UI — there's no UI to disrupt here), unlike the manual
      // "Send test message" path, which surfaces SlackWebhookException
      // directly to the user. debugPrint rather than swallowed entirely,
      // matching the "fail loud" rule at the log level even though nothing
      // user-facing can react to it from a background isolate.
      debugPrint('Morning summary background task failed: $e');
      return false;
    }
  });
}

/// The actual work: re-initialize Hive in THIS isolate, read today's
/// tasks and the Slack settings through the repository layer (never raw
/// Hive reads — same rule as every other feature, see CONSTITUTION.md),
/// build the summary, and POST it.
Future<void> _sendMorningSummary() async {
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapters();
  }
  final taskBox = await Hive.openBox<Task>(taskBoxName);
  final preferencesBox = await Hive.openBox<dynamic>(preferencesBoxName);

  final PreferencesRepository preferences = HivePreferencesRepository(
    preferencesBox,
  );
  final enabled =
      preferences.getValue<bool>(PreferenceKeys.slackSummaryEnabled) ?? false;
  if (!enabled) return;
  final webhookUrl = preferences.getValue<String>(
    PreferenceKeys.slackWebhookUrl,
  );
  if (webhookUrl == null || webhookUrl.trim().isEmpty) return;

  final taskRepository = HiveTaskRepository(taskBox);
  final now = DateTime.now();
  final todaysTasks = taskRepository.getTasks().where((task) {
    final scheduledAt = task.scheduledAt;
    if (scheduledAt == null) return false;
    return scheduledAt.year == now.year &&
        scheduledAt.month == now.month &&
        scheduledAt.day == now.day;
  }).toList();

  final text = buildMorningSummaryText(todaysTasks);
  final payload = buildSlackPayload(
    text: text,
    displayName: preferences.getValue<String>(PreferenceKeys.slackDisplayName),
    iconEmoji: preferences.getValue<String>(PreferenceKeys.slackIconEmoji),
  );
  await postToSlackWebhook(webhookUrl: webhookUrl, payload: payload);
}
