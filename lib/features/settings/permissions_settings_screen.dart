import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../shared/providers/notification_providers.dart';
import 'settings_detail_scaffold.dart';
import 'settings_panel.dart';

Future<void> showPermissionsSettingsScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (context) => const PermissionsSettingsScreen()),
  );
}

/// Device-level permission links — notifications today (calendar access is
/// requested inline by the OS the first time a device calendar is picked
/// in Calendars, so there is no separate standing "open calendar
/// permission settings" link to surface here).
class PermissionsSettingsScreen extends ConsumerStatefulWidget {
  const PermissionsSettingsScreen({super.key});

  @override
  ConsumerState<PermissionsSettingsScreen> createState() =>
      _PermissionsSettingsScreenState();
}

class _PermissionsSettingsScreenState
    extends ConsumerState<PermissionsSettingsScreen> {
  bool? _notificationsGranted;

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
  }

  Future<void> _loadNotificationStatus() async {
    final granted = await ref.read(notificationServiceProvider).hasPermission();
    if (mounted) setState(() => _notificationsGranted = granted);
  }

  Future<void> _openNotificationSettings() async {
    await ref.read(notificationServiceProvider).openNotificationSettings();
    // The user may grant/deny while system settings are open; refresh once
    // they're back so the displayed status doesn't go stale.
    await _loadNotificationStatus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return SettingsDetailScaffold(
      title: 'Permissions',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notifications', style: theme.textTitle),
          SizedBox(height: theme.spacingSm),
          SettingsPanel(
            theme: theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _notificationsGranted == null
                      ? 'Checking permission…'
                      : _notificationsGranted!
                      ? 'Notifications are enabled.'
                      : 'Notifications are turned off. Amble can\'t alert '
                            'you at a task\'s start time until this is '
                            'enabled in system settings.',
                  style: theme.textBody.copyWith(color: theme.colorTextPrimary),
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
        ],
      ),
    );
  }
}
