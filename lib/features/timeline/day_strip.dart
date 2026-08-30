import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_icon_button.dart';
import 'selected_date_provider.dart';

const _weekdayAbbreviations = [
  'MON',
  'TUE',
  'WED',
  'THU',
  'FRI',
  'SAT',
  'SUN',
];

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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorSurfacePrimary,
        // A subtle shadow on the TOP edge only, separating this bar from
        // the timeline content scrolling underneath it — the same
        // "adjacent to nav" relationship the bottom nav bar itself has
        // with the screen above it, just mirrored to the top of this bar.
        boxShadow: [
          BoxShadow(
            color: theme.shadowPane.first.color,
            blurRadius: theme.shadowPane.first.blurRadius,
            offset: Offset(
              theme.shadowPane.first.offset.dx,
              -theme.shadowPane.first.offset.dy,
            ),
            spreadRadius: theme.shadowPane.first.spreadRadius,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacingMd,
            vertical: theme.spacingSm,
          ),
          child: Row(
            children: [
              // The "return to today" chevron — shown only once the strip
              // has been scrolled away from today, replacing that space
              // with a tap target back to it rather than sitting alongside
              // the strip permanently.
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
              SizedBox(width: theme.spacingSm),
              AppIconButton(
                icon: Icons.add_rounded,
                onPressed: widget.onCreatePressed,
              ),
            ],
          ),
        ),
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
    // Grey background marks the CURRENT day specifically (per the
    // mockup — "grey bg is for the current day"), independent of which
    // day is selected. A selected-but-not-today day is distinguished by
    // its outline instead, so both states can be shown at once without
    // one hiding the other (e.g. viewing tomorrow while today is still
    // visibly today in the strip).
    final background = isToday ? theme.colorSurfaceField : Colors.transparent;

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
              border: isSelected && !isToday
                  ? Border.all(
                      color: theme.colorTextSecondary,
                      width: theme.borderWidthHairline,
                    )
                  : null,
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
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
