import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_press_feedback.dart';

/// The app's primary section switcher — "Day · Inbox · Tracked" as plain
/// text-label destinations, left-aligned, with Settings as a separate icon
/// on the far right. Requested directly against a reference screenshot,
/// with an explicit instruction not to build this as a conventional tab
/// bar: **"Do not design this as two standard tab bars. Make the hierarchy
/// immediately understandable from form alone."**
///
/// Deliberately NOT [AppTabSwitch] or [AppConnectedButtons] — both of
/// those render a shared track/capsule behind the options, which is
/// exactly the "standard tab bar" look this widget exists to avoid. Here,
/// each destination is bare text; the selected one is distinguished only
/// by color/weight (primary text vs. secondary, semibold vs. regular), the
/// same "quiet, editorial" language the reference used. Settings sits
/// outside the destination row entirely, visually marked as a DIFFERENT
/// kind of control (a small icon, not a label) — this is the deliberate
/// "reversal of conventional mobile navigation" from the spec: the primary
/// section switch lives at the top, not the bottom.
///
/// Provider-agnostic, like [AppDateAccordion] — takes [destinations] and
/// [selectedIndex] and calls [onDestinationSelected]; owns no navigation
/// state itself, so any caller (the root shell, a Widgetbook use case) can
/// drive it with its own index.
class AppTopNav extends StatelessWidget {
  const AppTopNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onSettingsTap,
    this.settingsSelected = false,
  });

  final List<String> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSettingsTap;

  /// Whether Settings is the currently-open screen — requested directly:
  /// "only active state for gear icon (settings)," and "currently when
  /// settings selected (1 menu item active) > none should be." Settings
  /// has no entry in [destinations] (see the caller's own doc comment on
  /// why), so a Day/Inbox/Tracked label can never legitimately report
  /// `selected` while Settings is open — this flag is what lets the gear
  /// icon itself carry the SAME active/light treatment [_TopNavLabel]
  /// already gives a selected destination, instead.
  final bool settingsSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Row(
      children: [
        for (var i = 0; i < destinations.length; i++) ...[
          if (i > 0) SizedBox(width: theme.spacingLg),
          _TopNavLabel(
            theme: theme,
            label: destinations[i],
            selected: i == selectedIndex,
            onTap: () => onDestinationSelected(i),
          ),
        ],
        const Spacer(),
        AppPressFeedback(
          onTap: onSettingsTap,
          borderRadius: BorderRadius.circular(theme.radiusSm),
          child: Padding(
            padding: EdgeInsets.all(theme.spacingXs),
            child: Icon(
              Icons.settings_outlined,
              // Same active/inactive contrast a selected destination
              // label uses (colorTextPrimary vs. colorTextTertiary) —
              // requested directly, "should highlight as Active (light)
              // same as menu items in top nav." Kept as
              // colorTextSecondary rather than colorTextTertiary for the
              // INACTIVE state specifically, matching this icon's own
              // pre-existing resting color (a label's own inactive tone
              // was never applied to this icon before, and changing it
              // was not asked for — only the missing ACTIVE state was).
              color: settingsSelected
                  ? theme.colorTextPrimary
                  : theme.colorTextSecondary,
              size: theme.spacingLg,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopNavLabel extends StatelessWidget {
  const _TopNavLabel({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AmbleTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.radiusSm),
      child: Text(
        label,
        style: theme.textTitle.copyWith(
          color: selected ? theme.colorTextPrimary : theme.colorTextTertiary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
