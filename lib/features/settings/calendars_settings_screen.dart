import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_selectable_chip.dart';
import '../../core/widgets/app_switch.dart';
import '../../shared/providers/calendar_providers.dart';
import '../../shared/providers/preferences_providers.dart';
import 'settings_detail_scaffold.dart';
import 'settings_panel.dart';

Future<void> showCalendarsSettingsScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (context) => const CalendarsSettingsScreen()),
  );
}

class CalendarsSettingsScreen extends ConsumerStatefulWidget {
  const CalendarsSettingsScreen({super.key});

  @override
  ConsumerState<CalendarsSettingsScreen> createState() =>
      _CalendarsSettingsScreenState();
}

class _CalendarsSettingsScreenState
    extends ConsumerState<CalendarsSettingsScreen> {
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
                  'Timeline. Amble never edits or removes anything on '
                  'these calendars.',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextSecondary,
                  ),
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
