import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/widgets/app_press_feedback.dart';
import '../../shared/models/zone.dart';
import '../../shared/providers/zone_providers.dart';
import 'zone_form_screen.dart';

/// Opens the Zones list — every saved [Zone], tap to edit, "+" to add.
/// Reached from Settings' "Zones" section; a real pushed page, not a
/// sheet, since this is a place to browse and manage a list rather than a
/// single focused action.
Future<void> showZoneListScreen(BuildContext context) {
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (context) => const ZoneListScreen()));
}

class ZoneListScreen extends StatelessWidget {
  const ZoneListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Scaffold(
      backgroundColor: theme.colorSurfacePrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(theme.spacingScreenPadding),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: theme.spacingMd),
                  Expanded(child: Text('Zones', style: theme.textHeadline)),
                  AppIconButton(
                    icon: Icons.add_rounded,
                    onPressed: () => showZoneFormScreen(context),
                  ),
                ],
              ),
            ),
            const Expanded(child: ZoneListBody()),
          ],
        ),
      ),
    );
  }
}

/// The list+rows portion of the Zones screen, with no `Scaffold`/back
/// button/heading of its own — extracted so the same list can be embedded
/// directly inside the Manage screen's "Zones" sub-tab (no nested page
/// chrome) as well as wrapped in [ZoneListScreen]'s pushed-page shell for
/// Settings → Zones. Requested directly, alongside adding the Manage
/// sub-tab: "Zones > list of zones and add new zone (edit also)."
class ZoneListBody extends ConsumerWidget {
  const ZoneListBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    // Chronological by start time — requested directly. zoneListProvider
    // itself stays in plain insertion/creation order (its own consumers,
    // like the Zone Timeline view, already derive their own visual
    // position from each zone's real time), so this screen sorts its own
    // copy rather than changing what every other reader of the provider
    // sees.
    //
    // One row per SERIES, not per materialized instance: a recurring zone
    // now generates up to ~56 instances (8-week rolling window, see
    // `zone_recurrence_generator.dart`), and this is a management list, not
    // a day view — showing every instance would bury the list. Only
    // non-recurring zones and each series' own template row are listed;
    // tapping a recurring zone's row edits the template (its shared
    // title/time/repeat/notification fields), mirroring how there is no
    // per-occurrence editing UI in scope this session.
    final zones = [
      ...ref
          .watch(zoneListProvider)
          .where((zone) => !zone.isRecurring || zone.isRecurrenceTemplate),
    ]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    if (zones.isEmpty) return _EmptyState(theme: theme);

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: theme.spacingScreenPadding),
      itemCount: zones.length,
      separatorBuilder: (_, _) => SizedBox(height: theme.spacingSm),
      itemBuilder: (context, index) => _ZoneRow(
        theme: theme,
        zone: zones[index],
        onTap: () => showZoneFormScreen(context, zone: zones[index]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.spacingLg),
        child: Text(
          'No zones yet. Tap + to add one — a named time window like '
          '"Morning ritual," 7:00–8:00.',
          textAlign: TextAlign.center,
          style: theme.textBody.copyWith(color: theme.colorTextSecondary),
        ),
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.theme,
    required this.zone,
    required this.onTap,
  });

  final AmbleTheme theme;
  final Zone zone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = _formatMinutes(zone.startMinutes);
    final end = _formatMinutes(zone.endMinutes);

    return AppPressFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.radiusXl),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(theme.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorSurfaceSecondary,
          borderRadius: BorderRadius.circular(theme.radiusXl),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.title,
                    style: theme.textBody.copyWith(
                      color: theme.colorTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: theme.spacingXs),
                  Text(
                    '$start – $end',
                    style: theme.textBody.copyWith(
                      color: theme.colorTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorTextSecondary),
          ],
        ),
      ),
    );
  }

  /// `HH:MM`, 24-hour — a zone is a raw time-of-day window with no am/pm
  /// concept attached to it in the model, so this reads the same way
  /// regardless of locale rather than routing through `TimeOfDay.format`
  /// (which needs a `BuildContext` for locale/12-24h resolution this
  /// simple row doesn't otherwise need).
  String _formatMinutes(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
