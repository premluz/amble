import 'package:flutter/material.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';
import 'app_button.dart';
import 'app_nav_label.dart';
import 'app_nav_press.dart';
import 'app_stagger_exit.dart';

export 'app_nav_label.dart';

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

    // **2026-09-26 — real bug, fixed: same height/hit area as
    // `AppTabSwitch`.** Reported directly: switching between the main
    // shell (this bar) and the merged Edit screen (`AppTabSwitch`'s
    // Tasks/Zones tabs) visibly "jumped" — this bar had NO fixed height
    // at all (bare `Text` in `theme.textTitle`, no padding), sizing to
    // whatever that text's own line-height happened to be, while
    // `AppTabSwitch` reserves a deliberate `appButtonHeightFor(theme,
    // AppButtonSize.md)` (40px) track. Wrapping this whole row at that
    // SAME height — and centering each label/icon inside it — matches the
    // hit area and layout height exactly, without adopting any of
    // `AppTabSwitch`'s visual language (no shared track, no highlight
    // fill): this bar still reads as bare text per this class's own "not
    // a standard tab bar" doc comment above, just now the same physical
    // size as the row it visually swaps places with.
    return SizedBox(
      height: appButtonHeightFor(theme, AppButtonSize.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < destinations.length; i++) ...[
            if (i > 0) SizedBox(width: theme.spacingLg),
            AppStaggerExit(
              index: i,
              child: AppNavLabel(
                theme: theme,
                label: destinations[i],
                selected: i == selectedIndex,
                onTap: () => onDestinationSelected(i),
                height: appButtonHeightFor(theme, AppButtonSize.md),
              ),
            ),
          ],
          const Spacer(),
          // Pulled right by the gap between the gear and its tap box's own
          // right edge, so the GLYPH (not the invisible box) ends on the
          // screen-padding line — optically aligned with everything else
          // that sits at that edge. The tap box moves with it.
          // Settings leaves last, after every destination.
          AppStaggerExit(
            index: destinations.length,
            child: Transform.translate(
              offset: Offset(
                (appButtonHeightFor(theme, AppButtonSize.md) -
                        TopNavTokens.settingsIconSize) /
                    2,
                0,
              ),
              child: AppNavSettingsGear(
                selected: settingsSelected,
                onTap: onSettingsTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The main nav's Settings control — a gear icon in a nav-sized tap box,
/// shared by [AppTopNav] (phone) and `AppSideNav` (wide layout) so the two
/// navs can't drift into two different Settings buttons.
class AppNavSettingsGear extends StatelessWidget {
  const AppNavSettingsGear({
    super.key,
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final size = appButtonHeightFor(theme, AppButtonSize.md);
    return AppNavPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.radiusSm),
      builder: (context, pressed) => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: AppNavWash(
            visible: pressed,
            child: Icon(
              Icons.settings_outlined,
              // Same active/inactive contrast a selected destination label
              // uses. Inactive is colorForegroundTertiary, not
              // colorTextTertiary — the same resting tone as an inactive
              // label, named for a non-text element.
              color: selected
                  ? theme.colorTextPrimary
                  : theme.colorForegroundTertiary,
              size: TopNavTokens.settingsIconSize,
            ),
          ),
        ),
      ),
    );
  }
}
