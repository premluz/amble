import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../shared/providers/backup_providers.dart';
import '../../shared/providers/notification_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/services/backup_service.dart';

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
      await ref.read(backupServiceProvider).exportTasks(tasks);
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
      final tasks = await backupService.pickAndParseImportFile();
      if (tasks == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final result = await ref
          .read(taskListProvider.notifier)
          .importTasks(tasks);
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Imported ${result.imported} task(s). '
            '${result.alreadyPresent} already present, '
            '${result.conflicts} conflict(s) skipped.';
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
        borderRadius: BorderRadius.circular(theme.radiusCard),
      ),
      child: child,
    );
  }
}
