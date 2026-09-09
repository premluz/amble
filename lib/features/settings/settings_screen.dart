import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/background/background_tasks.dart';
import '../../core/dev_config.dart';
import '../../core/feature_flags.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_alert_dialog.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../core/widgets/app_switch.dart';
import '../../core/widgets/app_text_field.dart';
import '../../shared/providers/backup_providers.dart';
import '../../shared/providers/calendar_providers.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/notification_providers.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/models/category.dart';
import '../../shared/models/task_size.dart';
import '../../shared/models/task_template.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/models/zone.dart';
import '../../shared/providers/task_template_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import '../../shared/providers/zone_providers.dart';
import '../../shared/services/backup_service.dart';
import '../../shared/services/slack_summary_service.dart';
import '../inbox/template_list_screen.dart';
import '../task_detail/category_list_screen.dart';
import '../zones/zone_list_screen.dart';
import 'theme_mode_selector.dart';

/// The real home for export/import and notification preferences — the
/// permanent replacement for Phase 7's temporary "Backup" bottom-nav tab.
/// Per docs/SCOPE.md's Inbox/Timeline/Settings nav structure, this is
/// itself the third persistent tab, not a screen reached another way.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    this.debugAutoTriggerExport = false,
    this.debugAutoTriggerImport = false,
  });

  /// Scaffold-only: calls the real export handler once the screen has
  /// settled, exercising the actual `_export` path (not a
  /// re-implementation of it) so a dev entry point can screenshot the
  /// share sheet without a tap-injection tool (unavailable on iOS
  /// Simulator — see docs/ERROR_LOG.md). Never set outside `*_main.dart`
  /// scaffolding.
  @visibleForTesting
  final bool debugAutoTriggerExport;

  /// Same as [debugAutoTriggerExport], for the import handler.
  @visibleForTesting
  final bool debugAutoTriggerImport;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _statusMessage;
  bool _statusIsError = false;
  bool _busy = false;

  bool? _notificationsGranted;
  String? _appVersion;

  // Slack morning-summary fields — plain TextEditingControllers (like every
  // other AppTextField user in the app) rather than reading the provider
  // value on every keystroke, so typing doesn't fight a rebuild. Committed
  // to PreferencesRepository on blur/submit, not per-keystroke — same
  // reasoning as every other free-text field in Settings/task-detail.
  late final TextEditingController _slackWebhookController;
  late final TextEditingController _slackDisplayNameController;
  late final TextEditingController _slackIconEmojiController;
  String? _slackStatusMessage;
  bool _slackStatusIsError = false;
  bool _slackTestBusy = false;

  // Dev-only data-clearing tools — see _clearAllTasks/_clearBadStateTasks/
  // _clearAllZones/_clearEverything below.
  String? _devClearStatusMessage;
  bool _devClearBusy = false;

  // Calendar sync-out (Feature 2) — see _syncToCalendar below. Same
  // busy/status shape as the Slack test-send fields above.
  String? _calendarSyncStatusMessage;
  bool _calendarSyncIsError = false;
  bool _calendarSyncBusy = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
    _loadAppVersion();
    if (widget.debugAutoTriggerExport) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _export());
    }
    if (widget.debugAutoTriggerImport) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _import());
    }
    _slackWebhookController = TextEditingController(
      text: ref.read(slackWebhookUrlSettingProvider) ?? '',
    );
    _slackDisplayNameController = TextEditingController(
      text: ref.read(slackDisplayNameSettingProvider) ?? '',
    );
    _slackIconEmojiController = TextEditingController(
      text: ref.read(slackIconEmojiSettingProvider) ?? '',
    );
  }

  @override
  void dispose() {
    _slackWebhookController.dispose();
    _slackDisplayNameController.dispose();
    _slackIconEmojiController.dispose();
    super.dispose();
  }

  Future<void> _saveSlackWebhookUrl() async {
    await ref
        .read(slackWebhookUrlSettingProvider.notifier)
        .set(_slackWebhookController.text);
  }

  Future<void> _saveSlackDisplayName() async {
    await ref
        .read(slackDisplayNameSettingProvider.notifier)
        .set(_slackDisplayNameController.text);
  }

  Future<void> _saveSlackIconEmoji() async {
    await ref
        .read(slackIconEmojiSettingProvider.notifier)
        .set(_slackIconEmojiController.text);
  }

  /// "Send test message now" — the important manual trigger the work order
  /// calls out explicitly, since it lets the feature be verified without
  /// depending on unreliable background timing, and gives immediate
  /// feedback on a bad webhook URL. Sends today's REAL summary (not a
  /// placeholder "hello world"), through the exact same
  /// `buildMorningSummaryText`/`buildSlackPayload`/`postToSlackWebhook`
  /// path the background task uses — so a successful test send is a
  /// genuine end-to-end proof the automatic one would also work, not a
  /// separate code path that could silently drift from it.
  Future<void> _sendSlackTestMessage() async {
    setState(() {
      _slackTestBusy = true;
      _slackStatusMessage = null;
    });
    try {
      final webhookUrl = _slackWebhookController.text;
      final today = DateTime.now();
      final todaysTasks = ref.read(taskListProvider).where((task) {
        final scheduledAt = task.scheduledAt;
        if (scheduledAt == null) return false;
        return scheduledAt.year == today.year &&
            scheduledAt.month == today.month &&
            scheduledAt.day == today.day;
      }).toList();
      final text = buildMorningSummaryText(todaysTasks);
      final payload = buildSlackPayload(
        text: text,
        displayName: _slackDisplayNameController.text,
        iconEmoji: _slackIconEmojiController.text,
      );
      await postToSlackWebhook(webhookUrl: webhookUrl, payload: payload);
      if (!mounted) return;
      setState(() {
        _slackStatusMessage = 'Test message sent — check Slack.';
        _slackStatusIsError = false;
      });
    } on SlackWebhookException catch (e) {
      if (!mounted) return;
      setState(() {
        _slackStatusMessage = e.message;
        _slackStatusIsError = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _slackStatusMessage = 'Could not send test message: $e';
        _slackStatusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _slackTestBusy = false);
    }
  }

  /// Manual, one-directional sync of every scheduled task OUT to the
  /// chosen target calendar — Feature 2 of CONSTITUTION.md's "Calendar"
  /// section. No automatic/background trigger exists; this button is the
  /// only entry point, per the explicit non-goal.
  Future<void> _syncToCalendar() async {
    final targetId = ref.read(calendarSyncTargetIdSettingProvider);
    if (targetId == null) return; // Button is disabled with no target chosen.

    setState(() {
      _calendarSyncBusy = true;
      _calendarSyncStatusMessage = null;
    });
    try {
      final result = await ref
          .read(calendarSyncServiceProvider)
          .sync(targetCalendarId: targetId);
      if (!mounted) return;
      setState(() {
        _calendarSyncStatusMessage =
            '${result.created} synced, ${result.updated} updated, '
            '${result.removed} removed';
        _calendarSyncIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _calendarSyncStatusMessage = 'Could not sync to calendar: $e';
        _calendarSyncIsError = true;
      });
    } finally {
      if (mounted) setState(() => _calendarSyncBusy = false);
    }
  }

  /// Confirms via [AppAlertDialog] before running [action] — every dev
  /// clear button goes through this, since these are irreversible bulk
  /// deletes and a mis-tap on a debug-only screen shouldn't be able to
  /// silently wipe real dev data. [action] returns the status text to
  /// show on success.
  Future<void> _confirmAndClear({
    required String title,
    required String message,
    required Future<String> Function() action,
  }) async {
    final confirmed = await AppAlertDialog.show(
      context: context,
      title: title,
      message: message,
      primaryAction: const AppAlertDialogAction(
        label: 'Clear',
        isDestructive: true,
      ),
      secondaryAction: const AppAlertDialogAction(label: 'Cancel'),
    );
    if (confirmed != true) return;

    setState(() {
      _devClearBusy = true;
      _devClearStatusMessage = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      setState(() => _devClearStatusMessage = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _devClearStatusMessage = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _devClearBusy = false);
    }
  }

  Future<void> _clearAllTasks() => _confirmAndClear(
    title: 'Clear all tasks?',
    message: 'Deletes every task, including the Inbox. This cannot be undone.',
    action: () async {
      final before = ref.read(taskListProvider).length;
      await ref.read(taskListProvider.notifier).clearAllTasks();
      return 'Cleared $before task(s).';
    },
  );

  /// The recurring-series "bad state" bug: deleting a series' template as
  /// a single occurrence could orphan every other instance (no row left
  /// carrying the rule), which then throws `Bad state: No element` on
  /// open — see `TaskList.deleteTask`'s own doc comment for the fix that
  /// now prevents this going forward, and `findOrphanedRecurringTaskIds`
  /// for what this button actually targets. Pre-existing data from before
  /// that fix can still have rows in this state, permanently unopenable
  /// until removed — this is the repair tool for that, requested directly.
  Future<void> _clearBadStateTasks() => _confirmAndClear(
    title: 'Clear bad-state tasks?',
    message:
        'Deletes recurring tasks whose series lost its template row — '
        'the ones that throw "Bad state: No element" when opened. '
        'Unaffected tasks are left untouched.',
    action: () async {
      final count = await ref
          .read(taskListProvider.notifier)
          .clearBadStateTasks();
      return 'Cleared $count bad-state task(s).';
    },
  );

  Future<void> _clearAllZones() => _confirmAndClear(
    title: 'Clear all zones?',
    message: 'Deletes every zone. This cannot be undone.',
    action: () async {
      final before = ref.read(zoneListProvider).length;
      await ref.read(zoneListProvider.notifier).clearAllZones();
      return 'Cleared $before zone(s).';
    },
  );

  Future<void> _clearEverything() => _confirmAndClear(
    title: 'Clear everything?',
    message: 'Deletes every task and every zone. This cannot be undone.',
    action: () async {
      final taskCount = ref.read(taskListProvider).length;
      final zoneCount = ref.read(zoneListProvider).length;
      await ref.read(taskListProvider.notifier).clearAllTasks();
      await ref.read(zoneListProvider.notifier).clearAllZones();
      return 'Cleared $taskCount task(s) and $zoneCount zone(s).';
    },
  );

  Future<void> _loadNotificationStatus() async {
    final granted = await ref.read(notificationServiceProvider).hasPermission();
    if (mounted) setState(() => _notificationsGranted = granted);
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = '${info.version} (${info.buildNumber})');
    }
  }

  Future<void> _openNotificationSettings() async {
    await ref.read(notificationServiceProvider).openNotificationSettings();
    // The user may grant/deny while system settings are open; refresh once
    // they're back so the displayed status doesn't go stale.
    await _loadNotificationStatus();
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final tasks = ref.read(taskListProvider);
      final categories = ref.read(categoryListProvider);
      final zones = ref.read(zoneListProvider);
      await ref
          .read(backupServiceProvider)
          .exportTasks(tasks, categories, zones);
      if (!mounted) return;
      setState(() {
        // Reports every entity actually written to the file — previously
        // only reported the task count even though categories/zones were
        // silently included too, reported directly as misleading ("says
        // exported 2 tasks, zones also exporting?").
        _statusMessage =
            'Exported ${tasks.length} task(s), '
            '${categories.length} categor${categories.length == 1 ? 'y' : 'ies'}, '
            '${zones.length} zone(s).';
        _statusIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Export failed: $error';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final backupService = ref.read(backupServiceProvider);
      final parsed = await backupService.pickAndParseImportFile();
      if (parsed == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      // Categories and zones first — a task's categoryId/zoneId should
      // resolve against the full restored sets by the time tasks are
      // merged in, though nothing in TaskList.importTasks actually
      // depends on ordering today (it stores the id, doesn't validate it
      // resolves).
      final categoryResult = await ref
          .read(categoryListProvider.notifier)
          .importCategories(parsed.categories);
      final zoneResult = await ref
          .read(zoneListProvider.notifier)
          .importZones(parsed.zones);
      final result = await ref
          .read(taskListProvider.notifier)
          .importTasks(parsed.tasks);
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Imported ${result.imported} task(s). '
            '${result.alreadyPresent} already present, '
            '${result.conflicts} conflict(s) skipped. '
            '${categoryResult.imported} categor${categoryResult.imported == 1 ? 'y' : 'ies'} imported. '
            '${zoneResult.imported} zone(s) imported, '
            '${zoneResult.alreadyPresent} already present, '
            '${zoneResult.conflicts} conflict(s) skipped.';
        _statusIsError = false;
      });
    } on BackupImportException catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = error.message;
        _statusIsError = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Import failed: $error';
        _statusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final taskCount = ref.watch(taskListProvider).length;

    return Container(
      color: theme.colorSurfacePrimary,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(theme.spacingScreenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: theme.textHeadline),
              SizedBox(height: theme.spacingLg),

              Text('Notifications', style: theme.textTitle),
              SizedBox(height: theme.spacingSm),
              _SettingsPanel(
                theme: theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _notificationsGranted == null
                          ? 'Checking permission…'
                          : _notificationsGranted!
                          ? 'Notifications are enabled.'
                          : 'Notifications are turned off. Amble can\'t '
                                'alert you at a task\'s start time until '
                                'this is enabled in system settings.',
                      style: theme.textBody.copyWith(
                        color: theme.colorTextPrimary,
                      ),
                    ),
                    SizedBox(height: theme.spacingMd),
                    AppButton(
                      label: 'Open notification settings',
                      variant: AppButtonVariant.secondary,
                      onPressed: _openNotificationSettings,
                    ),
                  ],
                ),
              ),

              SizedBox(height: theme.spacingLg),
              Text('Appearance', style: theme.textTitle),
              SizedBox(height: theme.spacingSm),
              _SettingsPanel(
                theme: theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System follows your device\'s light/dark setting.',
                      style: theme.textBody.copyWith(
                        color: theme.colorTextSecondary,
                      ),
                    ),
                    SizedBox(height: theme.spacingMd),
                    const ThemeModeSelector(),
                  ],
                ),
              ),

              SizedBox(height: theme.spacingLg),
              Text('Scheduling', style: theme.textTitle),
              SizedBox(height: theme.spacingSm),
              _SettingsPanel(
                theme: theme,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prevent overlapping tasks',
                            style: theme.textBody.copyWith(
                              color: theme.colorTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: theme.spacingXs),
                          Text(
                            'When on, scheduling or moving a task into a '
                            'time slot that overlaps another task is '
                            'blocked instead of shown side by side.',
                            style: theme.textBody.copyWith(
                              color: theme.colorTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: theme.spacingMd),
                    AppSwitch(
                      value: ref.watch(preventOverlappingTasksSettingProvider),
                      onChanged: (value) => ref
                          .read(preventOverlappingTasksSettingProvider.notifier)
                          .set(value),
                    ),
                  ],
                ),
              ),

              SizedBox(height: theme.spacingLg),
              Text('Timeline', style: theme.textTitle),
              SizedBox(height: theme.spacingSm),
              _SettingsPanel(
                theme: theme,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Show hour labels',
                            style: theme.textBody.copyWith(
                              color: theme.colorTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: theme.spacingXs),
                          Text(
                            'When off, the clock-hour column is hidden and '
                            'tasks stack one after another, sized by how '
                            'long they are. Drag-to-reschedule needs the '
                            'hour scale, so it is only available when this '
                            'is on.',
                            style: theme.textBody.copyWith(
                              color: theme.colorTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: theme.spacingMd),
                    AppSwitch(
                      value: ref.watch(showHourLabelsSettingProvider),
                      onChanged: (value) => ref
                          .read(showHourLabelsSettingProvider.notifier)
                          .set(value),
                    ),
                  ],
                ),
              ),

              SizedBox(height: theme.spacingSm),
              _SettingsPanel(
                theme: theme,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Show timeline connectors',
                            style: theme.textBody.copyWith(
                              color: theme.colorTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: theme.spacingXs),
                          Text(
                            'When off, the gray thread connecting '
                            'consecutive tasks is hidden. Task view only.',
                            style: theme.textBody.copyWith(
                              color: theme.colorTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: theme.spacingMd),
                    AppSwitch(
                      value: ref.watch(showTimelineConnectorsSettingProvider),
                      onChanged: (value) => ref
                          .read(showTimelineConnectorsSettingProvider.notifier)
                          .set(value),
                    ),
                  ],
                ),
              ),

              SizedBox(height: theme.spacingSm),
              _SettingsPanel(
                theme: theme,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Show completion checkbox',
                            style: theme.textBody.copyWith(
                              color: theme.colorTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: theme.spacingXs),
                          Text(
                            'When off, the circular checkbox on each task is '
                            'hidden across all three views — scheduled tasks '
                            'then have no way to be marked complete.',
                            style: theme.textBody.copyWith(
                              color: theme.colorTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: theme.spacingMd),
                    AppSwitch(
                      value: ref.watch(showCompletionCheckboxSettingProvider),
                      onChanged: (value) => ref
                          .read(showCompletionCheckboxSettingProvider.notifier)
                          .set(value),
                    ),
                  ],
                ),
              ),

              SizedBox(height: theme.spacingSm),
              _SettingsPanel(
                theme: theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Task size',
                      style: theme.textBody.copyWith(
                        color: theme.colorTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: theme.spacingXs),
                    Text(
                      'The size of a task\'s badge/icon and its name/time '
                      'text — applies everywhere: Task view, List view, '
                      'and Zone view.',
                      style: theme.textBody.copyWith(
                        color: theme.colorTextSecondary,
                      ),
                    ),
                    SizedBox(height: theme.spacingSm),
                    Row(
                      children: [
                        for (final size in TaskSize.values) ...[
                          if (size != TaskSize.values.first)
                            SizedBox(width: theme.spacingSm),
                          AppSelectableChip(
                            label: switch (size) {
                              TaskSize.sm => 'Small',
                              TaskSize.md => 'Medium',
                              TaskSize.lg => 'Large',
                            },
                            selected:
                                ref.watch(taskSizeSettingProvider) == size,
                            onTap: () => ref
                                .read(taskSizeSettingProvider.notifier)
                                .set(size),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: theme.spacingSm),
              _SettingsPanel(
                theme: theme,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Disable overlap clustering',
                            style: theme.textBody.copyWith(
                              color: theme.colorTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: theme.spacingXs),
                          Text(
                            'When on, 2-3 tasks that overlap in time are '
                            'shown as individual, spatially-overlapping '
                            'capsules instead of one combined block.',
                            style: theme.textBody.copyWith(
                              color: theme.colorTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: theme.spacingMd),
                    AppSwitch(
                      value: ref.watch(disableOverlapClusteringSettingProvider),
                      onChanged: (value) => ref
                          .read(
                            disableOverlapClusteringSettingProvider.notifier,
                          )
                          .set(value),
                    ),
                  ],
                ),
              ),

              // Tracked behaviors — gated. With the flag off this subtree is
              // const-eliminated, so Settings looks exactly as it did.
              if (FeatureFlags.trackedBehaviorEnabled) ...[
                SizedBox(height: theme.spacingLg),
                Text('Tracked behaviors', style: theme.textTitle),
                SizedBox(height: theme.spacingSm),
                _SettingsPanel(
                  theme: theme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _behaviorSummary(
                          ref.watch(trackedBehaviorListProvider),
                        ),
                        style: theme.textBody.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                      ),
                      SizedBox(height: theme.spacingMd),
                      // Points at the new "Tracked" nav tab rather than
                      // opening the create form inline: with a real
                      // top-level destination for this entity, a second
                      // creation entry point here would be two places to
                      // learn instead of one. The summary line stays, so
                      // Settings still reports what exists.
                      Text(
                        'Manage tracked behaviors from the Tracked tab.',
                        style: theme.textBody.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Manage — Zones (gated), Templates, and Categories
              // consolidated into ONE section with three link rows,
              // replacing the previously separate "Zones" and "Categories"
              // sections. Requested directly: "what we have in Manage in
              // main menu let's create also in settings in a single
              // section Manage... currently mange zones" — mirrors the
              // existing "Manage zones"/"Manage categories" push-a-list-
              // screen pattern exactly, just gathered under one heading
              // with a third row (Templates, which previously had no
              // Settings entry point at all) added alongside it. Each row
              // still pushes its own full page (back button + "+" to add),
              // unchanged from how "Manage zones"/"Manage categories"
              // already worked — no new list UI, just one shared heading.
              SizedBox(height: theme.spacingLg),
              Text('Manage', style: theme.textTitle),
              SizedBox(height: theme.spacingSm),
              _SettingsPanel(
                theme: theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Zones stays gated — with the flag off, this single
                    // row is the only part of the Manage panel affected;
                    // Templates/Categories are core, not opt-in.
                    if (FeatureFlags.zoneEnabled) ...[
                      _ManageLinkRow(
                        theme: theme,
                        label: 'Zones',
                        summary: _zoneSummary(ref.watch(zoneListProvider)),
                        onTap: () => showZoneListScreen(context),
                      ),
                      SizedBox(height: theme.spacingMd),
                    ],
                    _ManageLinkRow(
                      theme: theme,
                      label: 'Templates',
                      summary: _templateSummary(
                        ref.watch(taskTemplateListProvider),
                      ),
                      onTap: () => showTemplateListScreen(context),
                    ),
                    SizedBox(height: theme.spacingMd),
                    _ManageLinkRow(
                      theme: theme,
                      label: 'Categories',
                      summary: _categorySummary(
                        ref.watch(categoryListProvider),
                      ),
                      onTap: () => showCategoryListScreen(context),
                    ),
                    // Zone view — a Timeline DISPLAY preference, not zone
                    // list management, so it stays out of the three link
                    // rows above but keeps living in this same Manage
                    // panel (confirmed directly) rather than gaining its
                    // own section.
                    if (FeatureFlags.zoneEnabled) ...[
                      SizedBox(height: theme.spacingLg),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Zone view',
                                  style: theme.textBody.copyWith(
                                    color: theme.colorTextPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: theme.spacingXs),
                                Text(
                                  'When on, the Timeline shows zones as '
                                  'containers that hold their own tasks, '
                                  'instead of the default view where zones '
                                  'are just a background behind the '
                                  'timeline.',
                                  style: theme.textBody.copyWith(
                                    color: theme.colorTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: theme.spacingMd),
                          AppSwitch(
                            value: ref.watch(zoneViewEnabledSettingProvider),
                            onChanged: (value) => ref
                                .read(zoneViewEnabledSettingProvider.notifier)
                                .set(value),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: theme.spacingLg),
              Text('Backup', style: theme.textTitle),
              SizedBox(height: theme.spacingSm),
              _SettingsPanel(
                theme: theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$taskCount task(s) stored locally. Export creates a '
                      'JSON backup you can share or save; import merges a '
                      'backup back in without overwriting anything already '
                      'here.',
                      style: theme.textBody.copyWith(
                        color: theme.colorTextSecondary,
                      ),
                    ),
                    SizedBox(height: theme.spacingMd),
                    AppButton(
                      label: 'Export backup',
                      onPressed: _busy ? null : _export,
                    ),
                    SizedBox(height: theme.spacingSm),
                    AppButton(
                      label: 'Import backup',
                      variant: AppButtonVariant.secondary,
                      onPressed: _busy ? null : _import,
                    ),
                    if (_statusMessage != null) ...[
                      SizedBox(height: theme.spacingMd),
                      Text(
                        _statusMessage!,
                        style: theme.textBody.copyWith(
                          color: _statusIsError
                              ? theme.colorTaskAlert
                              : theme.colorTextPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: theme.spacingLg),
              Text('Morning summary (Slack)', style: theme.textTitle),
              SizedBox(height: theme.spacingSm),
              _SettingsPanel(
                theme: theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sends a plain-text summary of today\'s tasks to a '
                      'Slack channel every morning. This is a Slack '
                      'Incoming Webhook URL — create one in Slack '
                      '(Slack app settings → Incoming Webhooks) and paste '
                      'it below. It is not an Amble-managed Slack '
                      'connection; Amble never sees anything beyond the '
                      'URL you paste here, and the message is sent '
                      'directly from this device to that URL.',
                      style: theme.textBody.copyWith(
                        color: theme.colorTextSecondary,
                      ),
                    ),
                    SizedBox(height: theme.spacingMd),
                    AppTextField(
                      controller: _slackWebhookController,
                      label: 'Slack webhook URL',
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveSlackWebhookUrl(),
                      onFocusChanged: (focused) {
                        if (!focused) _saveSlackWebhookUrl();
                      },
                    ),
                    SizedBox(height: theme.spacingMd),
                    AppTextField(
                      controller: _slackDisplayNameController,
                      label: 'Display name (optional)',
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveSlackDisplayName(),
                      onFocusChanged: (focused) {
                        if (!focused) _saveSlackDisplayName();
                      },
                    ),
                    SizedBox(height: theme.spacingSm),
                    AppTextField(
                      controller: _slackIconEmojiController,
                      label: 'Icon emoji (optional, e.g. :sunrise:)',
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveSlackIconEmoji(),
                      onFocusChanged: (focused) {
                        if (!focused) _saveSlackIconEmoji();
                      },
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: theme.spacingXs),
                      child: Text(
                        'Left blank, Slack uses the webhook\'s own default '
                        'name/icon.',
                        style: theme.textCaption.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                      ),
                    ),
                    SizedBox(height: theme.spacingMd),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Send automatically each morning',
                                style: theme.textBody.copyWith(
                                  color: theme.colorTextPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: theme.spacingXs),
                              Text(
                                'Targets around ${morningSummaryTargetHour}am '
                                'local time. Delivery time isn\'t '
                                'guaranteed, especially on iOS — the '
                                'operating system decides exactly when '
                                'background tasks actually run, and may '
                                'delay or skip a day entirely. Use "Send '
                                'test message now" below any time you want '
                                'it right away.',
                                style: theme.textBody.copyWith(
                                  color: theme.colorTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: theme.spacingMd),
                        AppSwitch(
                          value: ref.watch(slackSummaryEnabledSettingProvider),
                          onChanged: (value) async {
                            await ref
                                .read(
                                  slackSummaryEnabledSettingProvider.notifier,
                                )
                                .set(value);
                            await registerMorningSummaryTask(enabled: value);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: theme.spacingMd),
                    AppButton(
                      label: 'Send test message now',
                      variant: AppButtonVariant.secondary,
                      isLoading: _slackTestBusy,
                      onPressed: _slackTestBusy ? null : _sendSlackTestMessage,
                    ),
                    if (_slackStatusMessage != null) ...[
                      SizedBox(height: theme.spacingMd),
                      Text(
                        _slackStatusMessage!,
                        style: theme.textBody.copyWith(
                          color: _slackStatusIsError
                              ? theme.colorTaskAlert
                              : theme.colorTextPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: theme.spacingLg),
              Text('Calendar', style: theme.textTitle),
              SizedBox(height: theme.spacingSm),
              _CalendarSettingsPanel(
                theme: theme,
                syncStatusMessage: _calendarSyncStatusMessage,
                syncStatusIsError: _calendarSyncIsError,
                syncBusy: _calendarSyncBusy,
                onSync: _syncToCalendar,
              ),

              SizedBox(height: theme.spacingLg),
              Text('About', style: theme.textTitle),
              SizedBox(height: theme.spacingSm),
              _SettingsPanel(
                theme: theme,
                child: Text(
                  _appVersion == null ? 'Amble' : 'Amble $_appVersion',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                ),
              ),

              // kDebugMode, not FeatureFlags: this isn't a product feature
              // to gate per-build, it's a developer convenience that must
              // never exist in a real build at all — kDebugMode is
              // compile-time false in every release/profile build, so this
              // whole subtree (including the button and its handler)
              // dead-code-eliminates the same way a FeatureFlags-gated
              // subtree does. See docs/DECISIONS.md.
              if (kDebugMode) ...[
                SizedBox(height: theme.spacingLg),
                Text('Developer', style: theme.textTitle),
                SizedBox(height: theme.spacingSm),
                _SettingsPanel(
                  theme: theme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debug build only. Re-shows the first-launch '
                        'splash and carousel immediately.',
                        style: theme.textBody.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                      ),
                      SizedBox(height: theme.spacingMd),
                      AppButton(
                        label: 'Reset splash screen',
                        variant: AppButtonVariant.secondary,
                        onPressed: () =>
                            ref.read(hasSeenSplashProvider.notifier).reset(),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: theme.spacingSm),
                // Runtime-toggleable, in-memory only (see
                // core/dev_config.dart) — for comparing timeline task
                // layouts live without a rebuild. Resets every app
                // restart; never persisted via PreferencesRepository,
                // since this isn't a real user setting.
                _SettingsPanel(
                  theme: theme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Timeline task layout (debug build only, resets on '
                        'restart)',
                        style: theme.textBody.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                      ),
                      SizedBox(height: theme.spacingMd),
                      Text(
                        'Text layout',
                        style: theme.textBody.copyWith(
                          color: theme.colorTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: theme.spacingSm),
                      Row(
                        children: [
                          for (final layout
                              in TimelineTaskTextLayout.values) ...[
                            _DevChip(
                              theme: theme,
                              label: switch (layout) {
                                TimelineTaskTextLayout.stacked => 'Stacked',
                                TimelineTaskTextLayout.inline => 'Inline',
                              },
                              selected:
                                  layout ==
                                  ref.watch(devTimelineTaskTextLayoutProvider),
                              onTap: () => ref
                                  .read(
                                    devTimelineTaskTextLayoutProvider.notifier,
                                  )
                                  .set(layout),
                            ),
                            if (layout != TimelineTaskTextLayout.values.last)
                              SizedBox(width: theme.spacingSm),
                          ],
                        ],
                      ),
                      SizedBox(height: theme.spacingMd),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Show status icons (bell/repeat/etc.)',
                              style: theme.textBody.copyWith(
                                color: theme.colorTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: theme.spacingMd),
                          AppSwitch(
                            value: ref.watch(
                              devTimelineTaskIconsVisibleProvider,
                            ),
                            onChanged: (value) => ref
                                .read(
                                  devTimelineTaskIconsVisibleProvider.notifier,
                                )
                                .set(value),
                          ),
                        ],
                      ),
                      SizedBox(height: theme.spacingMd),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Show duration',
                              style: theme.textBody.copyWith(
                                color: theme.colorTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: theme.spacingMd),
                          AppSwitch(
                            value: ref.watch(
                              devTimelineTaskDurationVisibleProvider,
                            ),
                            onChanged: (value) => ref
                                .read(
                                  devTimelineTaskDurationVisibleProvider
                                      .notifier,
                                )
                                .set(value),
                          ),
                        ],
                      ),
                      SizedBox(height: theme.spacingMd),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Show free-window prompt',
                              style: theme.textBody.copyWith(
                                color: theme.colorTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: theme.spacingMd),
                          AppSwitch(
                            value: ref.watch(devShowFreeWindowPromptProvider),
                            onChanged: (value) => ref
                                .read(devShowFreeWindowPromptProvider.notifier)
                                .set(value),
                          ),
                        ],
                      ),
                      SizedBox(height: theme.spacingMd),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Zone view',
                                  style: theme.textBody.copyWith(
                                    color: theme.colorTextPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: theme.spacingXs),
                                Text(
                                  'When off, the Timeline\'s view button '
                                  'cycles Task and List view only.',
                                  style: theme.textBody.copyWith(
                                    color: theme.colorTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: theme.spacingMd),
                          AppSwitch(
                            value: ref.watch(devZoneViewInCycleProvider),
                            onChanged: (value) => ref
                                .read(devZoneViewInCycleProvider.notifier)
                                .set(value),
                          ),
                        ],
                      ),
                      SizedBox(height: theme.spacingMd),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tracked tab',
                                  style: theme.textBody.copyWith(
                                    color: theme.colorTextPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: theme.spacingXs),
                                Text(
                                  'When off, the bottom nav\'s "Tracked" '
                                  'tab is hidden. Debug builds only — '
                                  'FeatureFlags.trackedBehaviorEnabled '
                                  'stays the real on/off switch.',
                                  style: theme.textBody.copyWith(
                                    color: theme.colorTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: theme.spacingMd),
                          AppSwitch(
                            value: ref.watch(devTrackedTabInCycleProvider),
                            onChanged: (value) => ref
                                .read(devTrackedTabInCycleProvider.notifier)
                                .set(value),
                          ),
                        ],
                      ),
                      SizedBox(height: theme.spacingMd),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Multi-task Edit Mode',
                                  style: theme.textBody.copyWith(
                                    color: theme.colorTextPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: theme.spacingXs),
                                Text(
                                  'When on (default), tapping a task in '
                                  'Edit Mode selects it (wiggle becomes '
                                  'the selection indicator) instead of '
                                  'opening its detail sheet — drag/'
                                  'resize/delete then act on every '
                                  'selected task together. Turn off for '
                                  'the original single-task Edit Mode.',
                                  style: theme.textBody.copyWith(
                                    color: theme.colorTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: theme.spacingMd),
                          AppSwitch(
                            value: ref.watch(devMultiTaskEditModeProvider),
                            onChanged: (value) => ref
                                .read(devMultiTaskEditModeProvider.notifier)
                                .set(value),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: theme.spacingSm),
                // Vertical timeline scale — independently configurable per
                // view, requested directly. The Zone view starts at double
                // the Task view's own 1.5, since a short zone container
                // barely fit its header at the shared old scale (see
                // DevZoneViewPixelsPerMinute's own doc comment).
                _SettingsPanel(
                  theme: theme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Timeline scale (debug build only, resets on '
                        'restart)',
                        style: theme.textBody.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                      ),
                      SizedBox(height: theme.spacingMd),
                      Text(
                        'Task view (pixels/minute)',
                        style: theme.textBody.copyWith(
                          color: theme.colorTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: theme.spacingSm),
                      _PixelsPerMinuteChipRow(
                        theme: theme,
                        value: ref.watch(devTaskViewPixelsPerMinuteProvider),
                        onChanged: (value) => ref
                            .read(devTaskViewPixelsPerMinuteProvider.notifier)
                            .set(value),
                      ),
                      SizedBox(height: theme.spacingMd),
                      Text(
                        'Zone view (pixels/minute)',
                        style: theme.textBody.copyWith(
                          color: theme.colorTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: theme.spacingSm),
                      _PixelsPerMinuteChipRow(
                        theme: theme,
                        value: ref.watch(devZoneViewPixelsPerMinuteProvider),
                        onChanged: (value) => ref
                            .read(devZoneViewPixelsPerMinuteProvider.notifier)
                            .set(value),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: theme.spacingSm),
                // Destructive bulk-delete tools — requested directly, as a
                // way to clear real local data (or repair the recurring-
                // series "bad state" orphan bug — see
                // TaskList.clearBadStateTasks' own doc comment) without a
                // fresh install. Every button confirms first
                // (_confirmAndClear -> AppAlertDialog); debug-build-only,
                // same as every other control in this section.
                _SettingsPanel(
                  theme: theme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clear data (debug build only, irreversible)',
                        style: theme.textBody.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                      ),
                      SizedBox(height: theme.spacingMd),
                      AppButton(
                        label: 'Clear all tasks',
                        variant: AppButtonVariant.secondary,
                        onPressed: _devClearBusy ? null : _clearAllTasks,
                      ),
                      SizedBox(height: theme.spacingSm),
                      AppButton(
                        label: 'Clear bad-state tasks',
                        variant: AppButtonVariant.secondary,
                        onPressed: _devClearBusy ? null : _clearBadStateTasks,
                      ),
                      SizedBox(height: theme.spacingSm),
                      AppButton(
                        label: 'Clear all zones',
                        variant: AppButtonVariant.secondary,
                        onPressed: _devClearBusy ? null : _clearAllZones,
                      ),
                      SizedBox(height: theme.spacingSm),
                      AppButton(
                        label: 'Clear everything',
                        onPressed: _devClearBusy ? null : _clearEverything,
                        isLoading: _devClearBusy,
                      ),
                      if (_devClearStatusMessage != null) ...[
                        SizedBox(height: theme.spacingMd),
                        Text(
                          _devClearStatusMessage!,
                          style: theme.textBody.copyWith(
                            color: theme.colorTextPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Preset chip row for a pixels-per-minute dev value — no numeric text
/// entry exists elsewhere in this Settings screen, so a fixed set of
/// presets (matching the shipped 1.5 plus round multiples) keeps this
/// consistent with `TimelineTaskTextLayout`'s own chip-picker shape rather
/// than introducing a new text-field/stepper pattern for one scratch
/// value.
class _PixelsPerMinuteChipRow extends StatelessWidget {
  const _PixelsPerMinuteChipRow({
    required this.theme,
    required this.value,
    required this.onChanged,
  });

  final AmbleTheme theme;
  final double value;
  final ValueChanged<double> onChanged;

  static const _presets = [1.0, 1.5, 2.0, 3.0, 4.0];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: theme.spacingSm,
      runSpacing: theme.spacingSm,
      children: [
        for (final preset in _presets)
          _DevChip(
            theme: theme,
            label: preset == preset.roundToDouble()
                ? preset.toStringAsFixed(0)
                : preset.toStringAsFixed(1),
            selected: preset == value,
            onTap: () => onChanged(preset),
          ),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.theme, required this.child});

  final AmbleTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorSurfaceSecondary,
        borderRadius: BorderRadius.circular(theme.radiusXl),
      ),
      child: child,
    );
  }
}

/// A selectable chip for the Developer section's dev-config pickers — same
/// visual shape as `ThemeModeSelector`'s own `_ModeChip`, duplicated
/// rather than shared since that one is private to its own file and this
/// is the only other place a segmented chip choice is needed.
class _DevChip extends StatelessWidget {
  const _DevChip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AmbleTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacingMd,
          vertical: theme.spacingSm,
        ),
        decoration: BoxDecoration(
          color: selected ? theme.colorAccent : theme.colorSurfaceTimeline,
          borderRadius: BorderRadius.circular(theme.radiusTaskPill),
        ),
        child: Text(
          label,
          style: theme.textBody.copyWith(
            color: selected
                ? theme.colorSurfacePrimary
                : theme.colorTextSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Settings' "Calendar" section — houses both Calendar features side by
/// side but keeps them visually distinct, per the work order's explicit
/// instruction: a multi-select list of DISPLAY calendars (Feature 1,
/// `AppSwitch` per row — "any number of these can be on") above a
/// single-select SYNC TARGET (Feature 2, `AppSelectableChip` row — "pick
/// exactly one," the same chip shape already used for single-choice
/// pickers elsewhere in Settings/task-detail) plus its own "Sync to
/// Calendar" button. Both read from [availableDeviceCalendarsProvider] —
/// one shared device-calendar list, two independent selections over it.
class _CalendarSettingsPanel extends ConsumerWidget {
  const _CalendarSettingsPanel({
    required this.theme,
    required this.syncStatusMessage,
    required this.syncStatusIsError,
    required this.syncBusy,
    required this.onSync,
  });

  final AmbleTheme theme;
  final String? syncStatusMessage;
  final bool syncStatusIsError;
  final bool syncBusy;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarsAsync = ref.watch(availableDeviceCalendarsProvider);

    return _SettingsPanel(
      theme: theme,
      child: calendarsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(
          'Could not load device calendars: $error',
          style: theme.textBody.copyWith(color: theme.colorTaskAlert),
        ),
        data: (calendars) {
          if (calendars.isEmpty) {
            return Text(
              'No calendars found on this device, or calendar permission '
              'was denied. Neither Calendar feature can activate without '
              'at least one device calendar.',
              style: theme.textBody.copyWith(color: theme.colorTextSecondary),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Show on Timeline',
                style: theme.textBody.copyWith(
                  color: theme.colorTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: theme.spacingXs),
              Text(
                'Events from these calendars display read-only on the '
                'Timeline. Amble never edits or removes anything on these '
                'calendars.',
                style: theme.textBody.copyWith(color: theme.colorTextSecondary),
              ),
              SizedBox(height: theme.spacingSm),
              Consumer(
                builder: (context, ref, _) {
                  final displayIds = ref.watch(
                    calendarDisplayIdsSettingProvider,
                  );
                  return Column(
                    children: [
                      for (final calendar in calendars)
                        if (calendar.id != null)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: theme.spacingXs,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    calendar.name ?? calendar.id!,
                                    style: theme.textBody.copyWith(
                                      color: theme.colorTextPrimary,
                                    ),
                                  ),
                                ),
                                AppSwitch(
                                  value: displayIds.contains(calendar.id),
                                  onChanged: (value) {
                                    final updated = [...displayIds];
                                    if (value) {
                                      updated.add(calendar.id!);
                                    } else {
                                      updated.remove(calendar.id);
                                    }
                                    ref
                                        .read(
                                          calendarDisplayIdsSettingProvider
                                              .notifier,
                                        )
                                        .set(updated);
                                  },
                                ),
                              ],
                            ),
                          ),
                    ],
                  );
                },
              ),
              SizedBox(height: theme.spacingLg),
              Divider(color: theme.colorZoneBackground),
              SizedBox(height: theme.spacingMd),
              Text(
                'Sync to calendar',
                style: theme.textBody.copyWith(
                  color: theme.colorTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: theme.spacingXs),
              Text(
                'Pushes every scheduled task to the chosen calendar. '
                'One-directional — calendar-side edits are overwritten on '
                'the next sync. Manual only; nothing syncs automatically.',
                style: theme.textBody.copyWith(color: theme.colorTextSecondary),
              ),
              SizedBox(height: theme.spacingSm),
              Consumer(
                builder: (context, ref, _) {
                  final targetId = ref.watch(
                    calendarSyncTargetIdSettingProvider,
                  );
                  return Wrap(
                    spacing: theme.spacingSm,
                    runSpacing: theme.spacingSm,
                    children: [
                      for (final calendar in calendars)
                        if (calendar.id != null)
                          AppSelectableChip(
                            label: calendar.name ?? calendar.id!,
                            selected: targetId == calendar.id,
                            onTap: () => ref
                                .read(
                                  calendarSyncTargetIdSettingProvider.notifier,
                                )
                                .set(calendar.id),
                          ),
                    ],
                  );
                },
              ),
              SizedBox(height: theme.spacingMd),
              Consumer(
                builder: (context, ref, _) {
                  final targetId = ref.watch(
                    calendarSyncTargetIdSettingProvider,
                  );
                  return AppButton(
                    label: 'Sync to Calendar',
                    isLoading: syncBusy,
                    onPressed: (syncBusy || targetId == null) ? null : onSync,
                  );
                },
              ),
              if (syncStatusMessage != null) ...[
                SizedBox(height: theme.spacingMd),
                Text(
                  syncStatusMessage!,
                  style: theme.textBody.copyWith(
                    color: syncStatusIsError
                        ? theme.colorTaskAlert
                        : theme.colorTextPrimary,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One-line summary of how many behaviors exist, so the panel says
/// something useful before any have been created.
String _behaviorSummary(List<TrackedBehavior> behaviors) {
  if (behaviors.isEmpty) {
    return 'Nothing tracked yet. A tracked behavior is an intention with a '
        'target that tasks can be linked to.';
  }
  final names = behaviors.map((behavior) => behavior.title).join(', ');
  return '${behaviors.length} tracked: $names';
}

/// One-line summary of how many zones exist, mirroring [_behaviorSummary].
///
/// Counts one row per SERIES, not per materialized instance — same filter
/// as `zone_list_screen.dart`'s own list (`!isRecurring ||
/// isRecurrenceTemplate`): a recurring zone now generates up to ~56 real
/// rows (8-week rolling window), and a raw `zones.length` here would
/// report that count instead of how many zones the user actually created.
String _zoneSummary(List<Zone> zones) {
  final series = zones
      .where((zone) => !zone.isRecurring || zone.isRecurrenceTemplate)
      .toList();
  if (series.isEmpty) {
    return 'No zones yet. A zone is a named time window tasks can be '
        'assigned into.';
  }
  return '${series.length} zone${series.length == 1 ? '' : 's'}: '
      '${series.map((zone) => zone.title).join(', ')}';
}

/// One-line summary of how many categories exist, mirroring [_zoneSummary].
/// Never actually empty in practice (5 built-ins are seeded at launch —
/// see [CategoryList.seedBuiltInsAndBackfillIfNeeded]), but handled anyway
/// rather than assuming that invariant holds for every possible caller.
String _categorySummary(List<Category> categories) {
  if (categories.isEmpty) {
    return 'No categories yet.';
  }
  return '${categories.length} categor${categories.length == 1 ? 'y' : 'ies'}: '
      '${categories.map((category) => category.name).join(', ')}';
}

/// One-line summary of how many templates exist, mirroring [_zoneSummary].
String _templateSummary(List<TaskTemplate> templates) {
  if (templates.isEmpty) {
    return 'No templates yet. A template is a reusable task blueprint.';
  }
  return '${templates.length} template${templates.length == 1 ? '' : 's'}: '
      '${templates.map((template) => template.title).join(', ')}';
}

/// One row inside the "Manage" panel — a label, a one-line summary
/// underneath, and a chevron, tapping through to that entity's own list
/// screen (Zones/Templates/Categories each already have one, pushed via
/// `showZoneListScreen`/`showTemplateListScreen`/`showCategoryListScreen`).
/// Mirrors `zone_list_screen.dart`'s own `_ZoneRow` layout, adapted from a
/// card-per-item list row to a plain settings-panel row (no card
/// background/shadow of its own — the panel already provides that).
class _ManageLinkRow extends StatelessWidget {
  const _ManageLinkRow({
    required this.theme,
    required this.label,
    required this.summary,
    required this.onTap,
  });

  final AmbleTheme theme;
  final String label;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textBody.copyWith(
                    color: theme.colorTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: theme.spacingXs),
                Text(
                  summary,
                  style: theme.textBody.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: theme.spacingMd),
          Icon(Icons.chevron_right_rounded, color: theme.colorTextSecondary),
        ],
      ),
    );
  }
}
