import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/dev_config.dart';
import '../../core/feature_flags.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_switch.dart';
import '../../shared/providers/backup_providers.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/notification_providers.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import '../../shared/services/backup_service.dart';
import '../tracked_behavior/tracked_behavior_form.dart';
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
  }

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
      await ref.read(backupServiceProvider).exportTasks(tasks, categories);
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Exported ${tasks.length} task(s).';
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
      // Categories first — a task's categoryId should resolve against the
      // full restored category set by the time tasks are merged in,
      // though nothing in TaskList.importTasks actually depends on
      // ordering today (it stores the id, doesn't validate it resolves).
      final categoryResult = await ref
          .read(categoryListProvider.notifier)
          .importCategories(parsed.categories);
      final result = await ref
          .read(taskListProvider.notifier)
          .importTasks(parsed.tasks);
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Imported ${result.imported} task(s). '
            '${result.alreadyPresent} already present, '
            '${result.conflicts} conflict(s) skipped. '
            '${categoryResult.imported} categor${categoryResult.imported == 1 ? 'y' : 'ies'} imported.';
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
                      AppButton(
                        label: 'Track a behavior',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => showTrackedBehaviorForm(context),
                      ),
                    ],
                  ),
                ),
              ],

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
