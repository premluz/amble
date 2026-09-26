import 'package:flutter/material.dart';

import '../../core/widgets/app_context_dock.dart';
import '../../shared/models/tracked_behavior_view_mode.dart';

/// Icon/label/cycle-order for [TrackedBehaviorViewMode] — moved here
/// (2026-09-20, was a private extension inside
/// `tracked_behavior_list_screen.dart`) so both that screen and this
/// dock can read the same icon/label without duplicating the switch.
/// `next` is kept even though the top single-icon cycling button it once
/// drove is gone (replaced by this dock's all-three-at-once switcher) —
/// left in place rather than deleted in case a cycling entry point is
/// wanted again; it's cheap to keep and does not affect the dock above.
extension TrackedBehaviorViewModeDisplay on TrackedBehaviorViewMode {
  /// Weekly → Monthly → Six-monthly → Weekly — mirrors
  /// `TimelineViewMode.next()`'s exact cycling shape.
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

/// The Tracked screen's own bottom-docked view-mode switcher — Weekly ·
/// Monthly · Six-monthly, three connected icons in one floating pane.
/// Requested directly: "on tracked also add that bottom nav with 3 icons
/// connected for changing views (and remove the top single icon)" —
/// replacing the old top-right single icon that cycled through the three
/// modes one tap at a time with an always-visible, all-three-at-once
/// switcher, matching the Day screen's own `AppBottomDock` visual
/// language exactly (reuses that same [AppDockPane]/[AppDockIconButton]
/// pair rather than a second, independently-styled pill).
///
/// A plain exclusive-select switcher, not a toggle group — exactly one of
/// the three is ever "selected" (accent-colored), the same shape
/// `AppBottomDock`'s own List/Timeline pair uses for its own
/// mutually-exclusive pair, just with a third option here.
class AppTrackedViewDock extends StatelessWidget {
  const AppTrackedViewDock({
    super.key,
    required this.activeMode,
    required this.onSelectMode,
  });

  final TrackedBehaviorViewMode activeMode;
  final ValueChanged<TrackedBehaviorViewMode> onSelectMode;

  @override
  Widget build(BuildContext context) => AppContextDock(
    configuration: AppContextDockConfiguration(
      stateId: 'tracked-view',
      groups: [
        AppContextGroup(
          id: 'tracked-view-modes',
          actions: [
            for (final mode in TrackedBehaviorViewMode.values)
              AppContextAction(
                id: 'tracked-${mode.name}',
                icon: mode.icon,
                tooltip: mode.label,
                selected: mode == activeMode,
                onPressed: () => onSelectMode(mode),
              ),
          ],
        ),
      ],
    ),
  );
}
