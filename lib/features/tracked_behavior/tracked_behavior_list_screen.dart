import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_bottom_extension_bar.dart';
import '../../core/widgets/app_top_scroll_fade.dart';
import '../../shared/models/tracked_behavior.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import 'tracked_behavior_form.dart';
import 'tracked_behavior_row.dart';

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

    return Container(
      // Matches the Timeline's own background — requested directly:
      // "Tracked should also be the same as the timeline."
      color: theme.colorSurfaceTimeline,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Same bump as the Inbox screen's identical header —
            // requested directly, together.
            Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacingScreenPadding,
                theme.spacingLg,
                theme.spacingScreenPadding,
                theme.spacingMd,
              ),
              child: Text('Tracked', style: theme.textHeadline),
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
                    child: AppTopScrollFade(color: theme.colorSurfaceTimeline),
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
            // Same bottom "extension" bar the Timeline's DayStrip and the
            // Inbox use — requested directly, so the "+" sits at the
            // exact same screen position on every tab rather than
            // floating at a per-screen spot. No tab switcher here (this
            // screen has only one view), so [leading] is empty space —
            // still gives the create button the shared bar's rounded-top,
            // shadowed chrome instead of floating loose over the list.
            AppBottomExtensionBar(
              leading: const SizedBox.shrink(),
              onCreatePressed: () => showTrackedBehaviorForm(context),
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
