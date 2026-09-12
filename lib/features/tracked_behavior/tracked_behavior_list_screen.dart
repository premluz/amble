import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_floating_create_button.dart';
import '../../core/widgets/app_subtle_icon_button.dart';
import '../../core/widgets/app_top_scroll_fade.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/models/tracked_behavior_view_mode.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import 'tracked_behavior_form.dart';
import 'tracked_behavior_row.dart';

extension on TrackedBehaviorViewMode {
  /// Weekly → Monthly → Six-monthly → Weekly — mirrors
  /// `TimelineViewMode.next()`'s exact cycling shape, one global setting
  /// for the whole screen (confirmed directly, over a per-card switcher).
  TrackedBehaviorViewMode get next => switch (this) {
    TrackedBehaviorViewMode.weekly => TrackedBehaviorViewMode.monthly,
    TrackedBehaviorViewMode.monthly => TrackedBehaviorViewMode.sixMonthly,
    TrackedBehaviorViewMode.sixMonthly => TrackedBehaviorViewMode.weekly,
  };

  IconData get icon => switch (this) {
    TrackedBehaviorViewMode.weekly => Icons.view_week_outlined,
    TrackedBehaviorViewMode.monthly => Icons.calendar_view_month_outlined,
    TrackedBehaviorViewMode.sixMonthly => Icons.grid_view_rounded,
  };

  String get label => switch (this) {
    TrackedBehaviorViewMode.weekly => 'Weekly view',
    TrackedBehaviorViewMode.monthly => 'Monthly view',
    TrackedBehaviorViewMode.sixMonthly => 'Six-month view',
  };
}

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

    return Container(
      // Matches the Timeline's own background — requested directly:
      // "Tracked should also be the same as the timeline."
      color: theme.colorSurfaceTimeline,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Same bump as the Inbox screen's identical header —
                // requested directly, together. The view-cycle switcher
                // moved up here (2026-09-12, "move to the top right
                // functional icons like we do on timeline") from the old
                // bottom extension bar's own `leading` slot, styled with
                // the same subtle-outline circle `AppCalendarHeader`'s
                // utility icons use rather than a plain `IconButton`.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    theme.spacingScreenPadding,
                    theme.spacingLg,
                    theme.spacingScreenPadding,
                    theme.spacingMd,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Tracked', style: theme.textHeadline),
                      ),
                      AppSubtleIconButton(
                        icon: viewMode.icon,
                        tooltip: viewMode.label,
                        onTap: () => ref
                            .read(
                              trackedBehaviorViewModeSettingProvider.notifier,
                            )
                            .set(viewMode.next),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  // Stack, so top/bottom fades overlay the list's own
                  // scrolling content directly — reversed back from an
                  // earlier attempt that moved the top fade INTO the fixed
                  // heading above instead (a separate, non-scrolling sibling
                  // box, never actually behind any real content). Reported
                  // directly, matching the Inbox screen's identical fix and
                  // reasoning: a fade living in its own static header can
                  // only ever blend against that header's own flat
                  // background, never the list sliding past underneath it —
                  // the hard-cut-at-the-header-boundary bug this reverses.
                  // The title above stays clear of the fade by construction:
                  // the fade is confined to this Expanded's own bounds, which
                  // start below the fixed heading, so it can never paint over
                  // the title text (the original problem the header-embedded
                  // fade was built to solve).
                  child: Stack(
                    children: [
                      behaviors.isEmpty
                          ? _EmptyState(theme: theme)
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(
                                theme.spacingScreenPadding,
                                // spacingContentTop — the shared value every
                                // list/sheet uses now, confirmed directly at
                                // 30px so Tasks/Templates/Tracked all start
                                // at the same y level.
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
                                  onTap: () => showTrackedBehaviorForm(
                                    context,
                                    behavior: behavior,
                                  ),
                                );
                              },
                            ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: AppTopScrollFade(
                          color: theme.colorSurfaceTimeline,
                        ),
                      ),
                      // Mirrored bottom fade — requested directly: "use same
                      // at the bottom."
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
              ],
            ),
            // Floating independently above the bottom nav pill now
            // (2026-09-12, matching every other screen's own
            // `AppFloatingCreateButton`), rather than sharing a bottom bar
            // with the view-cycle switcher (which moved to the top-right
            // header row above).
            AppFloatingCreateButton(
              onPressed: () => showTrackedBehaviorForm(context),
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
