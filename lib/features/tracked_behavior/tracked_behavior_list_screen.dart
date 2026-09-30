import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dev_config.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_floating_create_button.dart';
import '../../core/widgets/app_top_scroll_fade.dart';
import '../../core/widgets/app_vertical_clip.dart';
import '../../shared/models/tracked_behavior_view_mode.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import 'app_tracked_view_dock.dart';
import 'tracked_behavior_form.dart';
import 'tracked_behavior_row.dart';
import 'tracked_period_calendar.dart';

/// The "Tracked" bottom-nav destination — every saved [TrackedBehavior],
/// tap to edit, "+" to add.
///
/// Mirrors `ZoneListScreen`'s visual language exactly (header row with a
/// trailing "+", a card per row, the same empty state shape), rather than
/// inventing a second list treatment for what is structurally the same
/// screen. The one structural difference: this is a bottom-nav destination
/// rather than a pushed page, so it carries no back button — the nav bar
/// is how you leave it.
///
/// **Create/list/edit only — no delete**, per docs/SCOPE.md. Deleting a
/// behavior that existing tasks reference via `Task.behaviorId` raises the
/// same orphaned-reference question already deliberately deferred for
/// `Category` and `Zone`.
///
/// Reached only when [FeatureFlags.trackedBehaviorEnabled] is on — see
/// `main.dart`, which omits the destination entirely (rather than
/// disabling it) when the flag is off.
class TrackedBehaviorListScreen extends ConsumerWidget {
  const TrackedBehaviorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    // Plain provider order (creation order) — unlike ZoneListScreen, which
    // sorts by start time because a zone has an inherent chronological
    // position. A behavior has no such natural ordering, so imposing one
    // would be an invented rule rather than a reflection of the data.
    final behaviors = ref.watch(trackedBehaviorListProvider);
    final viewMode = ref.watch(trackedBehaviorViewModeSettingProvider);
    final showCalendarLabels =
        isDevConfigAvailable &&
        ref.watch(devTrackedCalendarLabelsVisibleProvider);

    return Container(
      // Matches the Timeline's own background — requested directly:
      // "Tracked should also be the same as the timeline."
      color: theme.colorSurfaceTimeline,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            TrackedPeriodCalendar(
              viewMode: viewMode,
              bodyBuilder: (context, periodDate) => Stack(
                children: [
                  behaviors.isEmpty
                      ? _EmptyState(theme: theme)
                      : AppVerticalClip(
                          child: ListView.separated(
                            // Sides open so cards can trail past the page edge while it slides.
                            clipBehavior: Clip.none,
                            padding: EdgeInsets.fromLTRB(
                              theme.spacingScreenPadding,
                              theme.spacingContentTop,
                              theme.spacingScreenPadding,
                              0,
                            ),
                            itemCount: behaviors.length,
                            separatorBuilder: (context, _) =>
                                SizedBox(height: theme.spacingSm),
                            itemBuilder: (context, index) {
                              final behavior = behaviors[index];
                              return TrackedBehaviorRow(
                                key: ValueKey(behavior.id),
                                theme: theme,
                                behavior: behavior,
                                viewMode: viewMode,
                                periodDate: periodDate,
                                showCalendarLabels: showCalendarLabels,
                                onTap: () => showTrackedBehaviorForm(
                                  context,
                                  behavior: behavior,
                                ),
                              );
                            },
                          ),
                        ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AppTopScrollFade(color: theme.colorSurfaceTimeline),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AppTopScrollFade(
                      color: theme.colorSurfaceTimeline,
                      fromBottom: true,
                    ),
                  ),
                ],
              ),
            ),
            // Floating independently above the bottom nav pill now
            // (2026-09-12, matching every other screen's own
            // `AppFloatingCreateButton`), rather than sharing a bottom bar
            // with the view-cycle switcher.
            AppFloatingCreateButton(
              onPressed: () => showTrackedBehaviorForm(context),
              // After the view dock's buttons, left to right.
              toolbarOrder: TrackedBehaviorViewMode.values.length,
            ),
            // The view-mode switcher's new home — bottom-left, matching
            // `AppBottomDock`'s own placement on the Day screen exactly
            // (`Positioned(left: spacingMd, bottom: spacingBottomClearance)` inside a
            // top-false `SafeArea`), so both screens' floating docks sit
            // at the identical spot.
            Positioned(
              left: theme.spacingMd,
              bottom: theme.spacingBottomClearance,
              child: SafeArea(
                top: false,
                child: AppTrackedViewDock(
                  activeMode: viewMode,
                  onSelectMode: (mode) => ref
                      .read(trackedBehaviorViewModeSettingProvider.notifier)
                      .set(mode),
                ),
              ),
            ),
          ],
        ),
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
        padding: EdgeInsets.symmetric(horizontal: theme.spacingLg),
        child: Text(
          'Nothing tracked yet. Tap + to add one — an intention with a '
          'target, like "Exercise, 60 min, 3x a week."',
          textAlign: TextAlign.center,
          style: theme.textBody.copyWith(color: theme.colorTextSecondary),
        ),
      ),
    );
  }
}
