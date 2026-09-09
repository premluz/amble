import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dev_config.dart';
import '../../core/feature_flags.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_bottom_extension_bar.dart';
import '../../shared/providers/preferences_providers.dart';
import 'selected_date_provider.dart';

/// The Timeline's three display modes, cycled by the icon button leading
/// [DayStrip] — requested directly, from a mockup. Each maps onto the
/// SAME two existing persisted settings that already independently
/// controlled Zone view and hour-labels/collapsed mode; this is a new,
/// coordinated way to move between them, not a new setting of its own.
enum TimelineViewMode {
  /// `ZoneViewEnabledSetting` on. Only reachable when
  /// `FeatureFlags.zoneEnabled` is also true, AND (debug builds only) the
  /// `devZoneViewInCycle` dev-config toggle isn't switched off — see
  /// [TimelineViewMode.next].
  zone,

  /// `ZoneViewEnabledSetting` off, `ShowHourLabelsSetting` off — tasks
  /// stack one after another, sized by duration, no time axis.
  list,

  /// `ZoneViewEnabledSetting` off, `ShowHourLabelsSetting` on — the
  /// original spatial Timeline, tasks positioned against a real time
  /// axis.
  task,
}

extension on TimelineViewMode {
  /// Zone → List → Task → Zone — confirmed directly. Skips [zone] when
  /// [zoneFeatureEnabled] is false, since that mode isn't reachable at
  /// all with the feature flag off (matches every other Zone UI surface's
  /// own gating).
  TimelineViewMode next({required bool zoneFeatureEnabled}) => switch (this) {
    TimelineViewMode.zone => TimelineViewMode.list,
    TimelineViewMode.list => TimelineViewMode.task,
    TimelineViewMode.task =>
      zoneFeatureEnabled ? TimelineViewMode.zone : TimelineViewMode.list,
  };

  IconData get icon => switch (this) {
    TimelineViewMode.zone => Icons.grid_view_rounded,
    TimelineViewMode.list => Icons.view_agenda_outlined,
    TimelineViewMode.task => Icons.view_timeline_outlined,
  };
}

const _weekdayAbbreviations = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// How many days the strip renders on each side of today. The strip is a
/// real scrollable list (not a fixed ±N window that shifts as the user
/// navigates) — confirmed directly: scrolling the strip itself reveals
/// more days, the same way a calendar app's week strip works. This is
/// simply how far out that scrollable range extends before running out of
/// chips; comfortably past what a reasonable amount of horizontal
/// scrolling would reach.
const _daysEitherSide = 60;

/// The day-navigation container that replaces [DayNavigationRow] — a
/// horizontally scrolling strip of day chips (weekday + day-of-month),
/// the create button, sitting directly above the bottom nav as its own
/// bar. Requested directly, from a wireframe: "it should sit above the
/// nav in the container that holds days and + button... this section is
/// adjacent to nav and has top subtle shadow."
///
/// Replaces whole-screen swipe-to-change-day (removed from
/// [TimelineScreen] in the same change) — navigating days now happens
/// only through this strip or by tapping a chip, never by swiping the
/// task list itself.
class DayStrip extends ConsumerStatefulWidget {
  const DayStrip({super.key, required this.onCreatePressed});

  final VoidCallback onCreatePressed;

  @override
  ConsumerState<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends ConsumerState<DayStrip> {
  late final ScrollController _scrollController;

  /// Whether the strip's scroll position has moved away from centred-on-
  /// today far enough that the "return to today" chevron should show.
  /// Tracked from scroll offset rather than from [selectedDateProvider]
  /// directly — the strip can be scrolled without a day being tapped yet,
  /// and the chevron is about the STRIP's position, not the selection.
  bool _scrolledAwayFromToday = false;

  static const _chipWidth = 56.0;
  static const _chipSpacing = 8.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Centres the strip on today at first build, so today starts in view
    // without the user having to scroll to find it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnToday());
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final todayOffset = _daysEitherSide * (_chipWidth + _chipSpacing);
    final drift = (_scrollController.offset - todayOffset).abs();
    // A little slack (half a chip) so ordinary scroll settling near today
    // doesn't flicker the chevron in and out.
    final away = drift > (_chipWidth + _chipSpacing) / 2;
    if (away != _scrolledAwayFromToday) {
      setState(() => _scrolledAwayFromToday = away);
    }
  }

  void _centerOnToday({bool animate = false}) {
    if (!_scrollController.hasClients) return;
    final todayOffset = _daysEitherSide * (_chipWidth + _chipSpacing);
    // Centres the TODAY chip in the viewport rather than pinning it to
    // the left edge, matching the mockup's layout (today isn't always the
    // leftmost visible chip).
    final viewportWidth = _scrollController.position.viewportDimension;
    final target = (todayOffset - viewportWidth / 2 + _chipWidth / 2).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  void _returnToToday() {
    ref.read(selectedDateProvider.notifier).goToToday();
    _centerOnToday(animate: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final selectedDate = ref.watch(selectedDateProvider);
    final today = DateTime.now();

    // The dev toggle only ever REMOVES Zone view from the cycle, and only
    // in a debug build: `isDevConfigAvailable` is a plain `kDebugMode`
    // re-export, so this whole term is a compile-time `true` in release
    // and the expression collapses back to `FeatureFlags.zoneEnabled`
    // alone. That guard matters here specifically because this toggle
    // defaults to FALSE — unlike every other dev-config default, which is
    // the safe production value — so reading it unguarded would silently
    // disable a shipped feature (`zoneEnabled` is true in release builds).
    final zoneFeatureEnabled =
        FeatureFlags.zoneEnabled &&
        (!isDevConfigAvailable || ref.watch(devZoneViewInCycleProvider));
    final zoneViewEnabled =
        zoneFeatureEnabled && ref.watch(zoneViewEnabledSettingProvider);
    final showHourLabels = ref.watch(showHourLabelsSettingProvider);
    // Falls back to Task/List when Zone view is unreachable — without
    // this, turning the toggle off while Zone view was the ACTIVE mode
    // would strand the user in a mode the cycle button can no longer
    // reach or leave.
    final currentMode = zoneViewEnabled
        ? TimelineViewMode.zone
        : (showHourLabels ? TimelineViewMode.task : TimelineViewMode.list);

    return AppBottomExtensionBar(
      onCreatePressed: widget.onCreatePressed,
      leading: Row(
        children: [
          // Cycles Zone → List → Task → Zone (skipping Zone when
          // `zoneFeatureEnabled` above is false — either
          // FeatureFlags.zoneEnabled itself, or the debug-only
          // `devZoneViewInCycle` toggle, is off) — requested directly,
          // from a mockup. Writes both existing settings together rather
          // than introducing a new one of its own.
          Padding(
            padding: EdgeInsets.only(right: theme.spacingXs),
            child: IconButton(
              onPressed: () {
                final nextMode = currentMode.next(
                  zoneFeatureEnabled: zoneFeatureEnabled,
                );
                ref
                    .read(zoneViewEnabledSettingProvider.notifier)
                    .set(nextMode == TimelineViewMode.zone);
                ref
                    .read(showHourLabelsSettingProvider.notifier)
                    .set(nextMode == TimelineViewMode.task);
              },
              icon: Icon(currentMode.icon),
              color: theme.colorTextPrimary,
              tooltip: switch (currentMode) {
                TimelineViewMode.zone => 'Zone view',
                TimelineViewMode.list => 'List view',
                TimelineViewMode.task => 'Spatial view',
              },
            ),
          ),
          // The "return to today" chevron — shown only once the strip has
          // been scrolled away from today, replacing that space with a
          // tap target back to it rather than sitting alongside the
          // strip permanently.
          if (_scrolledAwayFromToday)
            Padding(
              padding: EdgeInsets.only(right: theme.spacingXs),
              child: IconButton(
                onPressed: _returnToToday,
                icon: const Icon(Icons.chevron_left_rounded),
                color: theme.colorTaskAlert,
                tooltip: 'Today',
              ),
            ),
          Expanded(
            child: SizedBox(
              height: theme.spacingXl * 1.6,
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: _daysEitherSide * 2 + 1,
                separatorBuilder: (context, index) =>
                    SizedBox(width: _chipSpacing),
                itemBuilder: (context, index) {
                  final date = DateTime(
                    today.year,
                    today.month,
                    today.day + (index - _daysEitherSide),
                  );
                  final isToday = _isSameDay(date, today);
                  final isSelected = _isSameDay(date, selectedDate);
                  return _DayChip(
                    theme: theme,
                    width: _chipWidth,
                    date: date,
                    isToday: isToday,
                    isSelected: isSelected,
                    onTap: () =>
                        ref.read(selectedDateProvider.notifier).goTo(date),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.theme,
    required this.width,
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final AmbleTheme theme;
  final double width;
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // REVISED, per direct feedback: background fill now marks the
    // SELECTED day (any day, not just today) — this supersedes the
    // earlier mockup-driven "grey bg is for the current day" design. The
    // current day is instead marked by a small accent-colored dot below
    // the day number, shown independently of selection, so both states
    // remain visible at once (e.g. viewing tomorrow while today is still
    // visibly today via its own dot). The outline previously used for
    // "selected but not today" is gone — background alone now signals
    // selection, for every day.
    final background = isSelected
        ? theme.colorSurfaceField
        : Colors.transparent;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(theme.radiusMd),
          child: Container(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            padding: EdgeInsets.symmetric(vertical: theme.spacingXs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _weekdayAbbreviations[date.weekday - 1],
                  style: theme.textCaption.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                ),
                SizedBox(height: theme.spacingXs / 2),
                Text(
                  '${date.day}',
                  style: theme.textBody.copyWith(
                    color: theme.colorTextPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                SizedBox(height: theme.spacingXs / 2),
                // Fixed-height slot regardless of isToday, so a non-today
                // chip's text doesn't shift vertically depending on
                // whether its neighbour is showing a dot.
                SizedBox(
                  height: theme.spacingXs,
                  child: isToday
                      ? Center(
                          child: Container(
                            width: theme.spacingXs,
                            height: theme.spacingXs,
                            decoration: BoxDecoration(
                              color: theme.colorAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
