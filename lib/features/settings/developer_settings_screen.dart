import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dev_config.dart';
import '../../core/feature_flags.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_alert_dialog.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_switch.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import '../../shared/providers/zone_providers.dart';
import 'settings_detail_scaffold.dart';
import 'settings_panel.dart';

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

Future<void> showDeveloperSettingsScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (context) => const DeveloperSettingsScreen()),
  );
}

/// Debug-build-only tools plus the settings folded in here per direct
/// request: Scheduling ("Prevent overlapping tasks"), Timeline (hour
/// labels, connectors, completion checkbox, overlap clustering), and Zone
/// view — moved out of their previous always-visible top-level sections
/// and out of the "Manage" panel respectively.
class DeveloperSettingsScreen extends ConsumerStatefulWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  ConsumerState<DeveloperSettingsScreen> createState() =>
      _DeveloperSettingsScreenState();
}

class _DeveloperSettingsScreenState
    extends ConsumerState<DeveloperSettingsScreen> {
  // Dev-only data-clearing tools — see _clearAllTasks/_clearBadStateTasks/
  // _clearAllZones/_clearEverything below.
  String? _devClearStatusMessage;
  bool _devClearBusy = false;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return SettingsDetailScaffold(
      title: 'Developer',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tracked behaviors — gated. With the flag off this subtree is
          // const-eliminated, so Developer looks exactly as it did.
          if (FeatureFlags.trackedBehaviorEnabled) ...[
            Text('Tracked behaviors', style: theme.textTitle),
            SizedBox(height: theme.spacingSm),
            SettingsPanel(
              theme: theme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _behaviorSummary(ref.watch(trackedBehaviorListProvider)),
                    style: theme.textBody.copyWith(
                      color: theme.colorTextSecondary,
                    ),
                  ),
                  SizedBox(height: theme.spacingMd),
                  // Points at the "Tracked" nav tab rather than opening
                  // the create form inline: with a real top-level
                  // destination for this entity, a second creation entry
                  // point here would be two places to learn instead of
                  // one. The summary line stays, so this page still
                  // reports what exists.
                  Text(
                    'Manage tracked behaviors from the Tracked tab.',
                    style: theme.textBody.copyWith(
                      color: theme.colorTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: theme.spacingLg),
          ],
          SettingsPanel(
            theme: theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Debug build only. Re-shows the first-launch splash and '
                  'carousel immediately.',
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

          SizedBox(height: theme.spacingLg),
          Text('Scheduling', style: theme.textTitle),
          SizedBox(height: theme.spacingSm),
          SettingsPanel(
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
                        'When on, scheduling or moving a task into a time '
                        'slot that overlaps another task is blocked '
                        'instead of shown side by side.',
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
          SettingsPanel(
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
                        'tasks stack one after another, sized by how long '
                        'they are. Drag-to-reschedule needs the hour '
                        'scale, so it is only available when this is on.',
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
          SettingsPanel(
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
                        'When off, the gray thread connecting consecutive '
                        'tasks is hidden. Task view only.',
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
          SettingsPanel(
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
          SettingsPanel(
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
                        'When on, 2-3 tasks that overlap in time are shown '
                        'as individual, spatially-overlapping capsules '
                        'instead of one combined block.',
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
                      .read(disableOverlapClusteringSettingProvider.notifier)
                      .set(value),
                ),
              ],
            ),
          ),

          // Zone view — a Timeline DISPLAY preference, moved out of the
          // old "Manage" panel into Developer per direct request.
          if (FeatureFlags.zoneEnabled) ...[
            SizedBox(height: theme.spacingSm),
            SettingsPanel(
              theme: theme,
              child: Row(
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
                          'When on, the Timeline shows zones as containers '
                          'that hold their own tasks, instead of the '
                          'default view where zones are just a background '
                          'behind the timeline.',
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
            ),
            SizedBox(height: theme.spacingSm),
            SettingsPanel(
              theme: theme,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zone card: flat style',
                          style: theme.textBody.copyWith(
                            color: theme.colorTextPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: theme.spacingXs),
                        Text(
                          'When on, a zone\'s card in Zone view has no '
                          'background or padding — just its title/duration '
                          'header directly above its member tasks.',
                          style: theme.textBody.copyWith(
                            color: theme.colorTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: theme.spacingMd),
                  AppSwitch(
                    value: ref.watch(devZoneCardFlatProvider),
                    onChanged: (value) =>
                        ref.read(devZoneCardFlatProvider.notifier).set(value),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: theme.spacingLg),
          // Runtime-toggleable, in-memory only (see core/dev_config.dart)
          // — for comparing timeline task layouts live without a rebuild.
          // Resets every app restart; never persisted via
          // PreferencesRepository, since this isn't a real user setting.
          SettingsPanel(
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
                    for (final layout in TimelineTaskTextLayout.values) ...[
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
                            .read(devTimelineTaskTextLayoutProvider.notifier)
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
                      value: ref.watch(devTimelineTaskIconsVisibleProvider),
                      onChanged: (value) => ref
                          .read(devTimelineTaskIconsVisibleProvider.notifier)
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
                      value: ref.watch(devTimelineTaskDurationVisibleProvider),
                      onChanged: (value) => ref
                          .read(devTimelineTaskDurationVisibleProvider.notifier)
                          .set(value),
                    ),
                  ],
                ),
                SizedBox(height: theme.spacingMd),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Show time (from-to)',
                        style: theme.textBody.copyWith(
                          color: theme.colorTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: theme.spacingMd),
                    AppSwitch(
                      value: ref.watch(devTimelineTaskTimeRangeVisibleProvider),
                      onChanged: (value) => ref
                          .read(
                            devTimelineTaskTimeRangeVisibleProvider.notifier,
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
                        'Hide imported tasks (List + Zone view)',
                        style: theme.textBody.copyWith(
                          color: theme.colorTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: theme.spacingMd),
                    AppSwitch(
                      value: ref.watch(devHideImportedTasksProvider),
                      onChanged: (value) => ref
                          .read(devHideImportedTasksProvider.notifier)
                          .set(value),
                    ),
                  ],
                ),
                SizedBox(height: theme.spacingMd),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Only important (List view)',
                        style: theme.textBody.copyWith(
                          color: theme.colorTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: theme.spacingMd),
                    AppSwitch(
                      value: ref.watch(devTimelineListOnlyImportantProvider),
                      onChanged: (value) => ref
                          .read(devTimelineListOnlyImportantProvider.notifier)
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
                            'List view',
                            style: theme.textBody.copyWith(
                              color: theme.colorTextPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: theme.spacingXs),
                          Text(
                            'When off (default), the Timeline\'s view '
                            'button cycles Zone and Task view only. Zone '
                            'and Task view are always in the cycle.',
                            style: theme.textBody.copyWith(
                              color: theme.colorTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: theme.spacingMd),
                    AppSwitch(
                      value: ref.watch(devListViewInCycleProvider),
                      onChanged: (value) => ref
                          .read(devListViewInCycleProvider.notifier)
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
                            'When off, the bottom nav\'s "Tracked" tab is '
                            'hidden. Debug builds only — '
                            'FeatureFlags.trackedBehaviorEnabled stays the '
                            'real on/off switch.',
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
                            'When on (default), tapping a task in Edit '
                            'Mode selects it (wiggle becomes the '
                            'selection indicator) instead of opening its '
                            'detail sheet — drag/resize/delete then act '
                            'on every selected task together. Turn off '
                            'for the original single-task Edit Mode.',
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
          // Vertical timeline scale — independently configurable per view,
          // requested directly. The Zone view starts at double the Task
          // view's own 1.5, since a short zone container barely fit its
          // header at the shared old scale (see
          // DevZoneViewPixelsPerMinute's own doc comment).
          SettingsPanel(
            theme: theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timeline scale (debug build only, resets on restart)',
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
          // Destructive bulk-delete tools — requested directly, as a way
          // to clear real local data (or repair the recurring-series "bad
          // state" orphan bug — see TaskList.clearBadStateTasks' own doc
          // comment) without a fresh install. Every button confirms first
          // (_confirmAndClear -> AppAlertDialog); debug-build-only, same
          // as every other control on this page.
          SettingsPanel(
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

/// A selectable chip for the Developer page's dev-config pickers — same
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
