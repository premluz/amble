import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../core/widgets/app_switch.dart';
import '../../shared/providers/calendar_providers.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/services/calendar_permission_service.dart';
import 'settings_detail_scaffold.dart';
import 'settings_panel.dart';

Future<void> showCalendarsSettingsScreen(BuildContext context) {
  return pushSettingsDetailRoute<void>(
    context,
    (context) => const CalendarsSettingsScreen(),
  );
}

class CalendarsSettingsScreen extends ConsumerStatefulWidget {
  const CalendarsSettingsScreen({super.key});

  @override
  ConsumerState<CalendarsSettingsScreen> createState() =>
      _CalendarsSettingsScreenState();
}

class _CalendarsSettingsScreenState
    extends ConsumerState<CalendarsSettingsScreen>
    with WidgetsBindingObserver {
  /// Set when the system settings page could not be opened, so the user is
  /// told where to go instead.
  bool _settingsUnavailable = false;

  /// Shown under "Refresh events" after a press, so it visibly did something.
  bool _refreshed = false;

  void _refreshEvents() {
    ref.read(externalCalendarRefreshProvider.notifier).refresh();
    ref.invalidate(availableDeviceCalendarsProvider);
    setState(() => _refreshed = true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from system settings is when a permission may have just
  /// been granted, so look again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(availableDeviceCalendarsProvider);
    }
  }

  Future<void> _openSettings() async {
    final opened = await ref
        .read(systemSettingsServiceProvider)
        .openCalendarSettings();
    if (mounted) setState(() => _settingsUnavailable = !opened);
  }

  // Calendar sync-out (Feature 2) — see _syncToCalendar below. Same
  // busy/status shape as Slack's own test-send fields.
  String? _syncStatusMessage;
  bool _syncStatusIsError = false;
  bool _syncBusy = false;

  /// Manual, one-directional sync of every scheduled task OUT to the
  /// chosen target calendar — Feature 2 of CONSTITUTION.md's "Calendar"
  /// section. No automatic/background trigger exists; this button is the
  /// only entry point, per the explicit non-goal.
  Future<void> _syncToCalendar() async {
    final targetId = ref.read(calendarSyncTargetIdSettingProvider);
    if (targetId == null) return; // Button is disabled with no target chosen.

    setState(() {
      _syncBusy = true;
      _syncStatusMessage = null;
    });
    try {
      final result = await ref
          .read(calendarSyncServiceProvider)
          .sync(targetCalendarId: targetId);
      if (!mounted) return;
      setState(() {
        _syncStatusMessage =
            '${result.created} synced, ${result.updated} updated, '
            '${result.removed} removed';
        _syncStatusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncStatusMessage = 'Could not sync to calendar: $e';
        _syncStatusIsError = true;
      });
    } finally {
      if (mounted) setState(() => _syncBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final calendarsAsync = ref.watch(availableDeviceCalendarsProvider);

    return SettingsDetailScaffold(
      title: 'Calendars',
      body: SettingsPanel(
        theme: theme,
        child: calendarsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text(
            'Could not load device calendars: $error',
            style: theme.textBody.copyWith(color: theme.colorTaskAlert),
          ),
          data: (state) {
            final calendars = state.calendars;
            if (state.access == CalendarAccess.denied) {
              return _AccessOff(
                theme: theme,
                settingsUnavailable: _settingsUnavailable,
                onEnable: _openSettings,
              );
            }
            if (calendars.isEmpty) {
              return Text(
                'No calendar detected on this device. Neither Calendar '
                'feature can activate without at least one device calendar.',
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: theme.spacingXs),
                Text(
                  'Events from these calendars display read-only on the '
                  'Timeline. Amble never edits or removes anything on '
                  'these calendars.',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                ),
                SizedBox(height: theme.spacingSm),
                Row(
                  children: [
                    AppButton(
                      label: 'Refresh events',
                      variant: AppButtonVariant.secondary,
                      onPressed: _refreshEvents,
                    ),
                    if (_refreshed) ...[
                      SizedBox(width: theme.spacingSm),
                      Text(
                        'Events re-read from your calendars.',
                        style: theme.textCaption.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                      ),
                    ],
                  ],
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: theme.spacingXs),
                Text(
                  'Pushes every scheduled task to the chosen calendar. '
                  'One-directional — calendar-side edits are overwritten '
                  'on the next sync. Manual only; nothing syncs '
                  'automatically.',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextSecondary,
                  ),
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
                                    calendarSyncTargetIdSettingProvider
                                        .notifier,
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
                      // Secondary, not primary — app-wide button
                      // unification pass, requested directly ("in
                      // settings should not be primary").
                      variant: AppButtonVariant.secondary,
                      isLoading: _syncBusy,
                      onPressed: (_syncBusy || targetId == null)
                          ? null
                          : _syncToCalendar,
                    );
                  },
                ),
                if (_syncStatusMessage != null) ...[
                  SizedBox(height: theme.spacingMd),
                  Text(
                    _syncStatusMessage!,
                    style: theme.textBody.copyWith(
                      color: _syncStatusIsError
                          ? theme.colorTaskAlert
                          : theme.colorTextPrimary,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Shown instead of "no calendar detected" when the calendars exist but the
/// user has not allowed Amble to read them.
class _AccessOff extends StatelessWidget {
  const _AccessOff({
    required this.theme,
    required this.settingsUnavailable,
    required this.onEnable,
  });

  final AmbleTheme theme;
  final bool settingsUnavailable;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Calendar access is off for Amble',
          style: theme.textBody.copyWith(
            color: theme.colorTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: theme.spacingXs),
        Text(
          'Allow Amble to read your calendars to show their events on the '
          'Timeline. Amble never edits them.',
          style: theme.textBody.copyWith(color: theme.colorTextSecondary),
        ),
        SizedBox(height: theme.spacingSm),
        AppButton(
          label: 'Enable permission',
          variant: AppButtonVariant.secondary,
          onPressed: onEnable,
        ),
        if (settingsUnavailable) ...[
          SizedBox(height: theme.spacingSm),
          Text(
            'Could not open settings. Allow Calendars for Amble in your '
            'system settings.',
            style: theme.textBody.copyWith(color: theme.colorTaskAlert),
          ),
        ],
      ],
    );
  }
}
