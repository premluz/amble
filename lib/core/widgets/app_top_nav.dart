import 'package:flutter/material.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';
import 'app_button.dart';
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
            AppNavLabel(
              theme: theme,
              label: destinations[i],
              selected: i == selectedIndex,
              onTap: () => onDestinationSelected(i),
              height: appButtonHeightFor(theme, AppButtonSize.md),
            ),
          ],
          const Spacer(),
          // Pulled right by the gap between the gear and its tap box's own
          // right edge, so the GLYPH (not the invisible box) ends on the
          // screen-padding line — optically aligned with everything else
          // that sits at that edge. The tap box moves with it.
          Transform.translate(
            offset: Offset(
              (appButtonHeightFor(theme, AppButtonSize.md) -
                      TopNavTokens.settingsIconSize) /
                  2,
              0,
            ),
            child: AppPressFeedback(
              onTap: onSettingsTap,
              borderRadius: BorderRadius.circular(theme.radiusSm),
              child: SizedBox(
                width: appButtonHeightFor(theme, AppButtonSize.md),
                height: appButtonHeightFor(theme, AppButtonSize.md),
                child: Center(
                  child: Icon(
                    Icons.settings_outlined,
                    // Same active/inactive contrast a selected destination
                    // label uses. Inactive state uses colorForegroundTertiary,
                    // not colorTextTertiary — same resting tone as the main
                    // nav's own inactive label, but named for a non-text
                    // element since this is an icon, not text.
                    color: settingsSelected
                        ? theme.colorTextPrimary
                        : theme.colorForegroundTertiary,
                    size: TopNavTokens.settingsIconSize,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A navigation label — the main nav's destinations and the page-level sub
/// nav's tabs (`AppSubNav`) share it, so both read as one navigation
/// language: `textBody`, bold primary when selected, medium tertiary when
/// not. [height] null keeps the label at its text height (the sub nav,
/// which sits in the page-heading slot); the main nav passes its 40px row.
class AppNavLabel extends StatelessWidget {
  const AppNavLabel({
    super.key,
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
    this.height,
  });

  final AmbleTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double? height;

  /// The label's text style, for anything that must match it exactly.
  static TextStyle styleFor(AmbleTheme theme, {required bool selected}) =>
      theme.textBody.copyWith(
        color: selected ? theme.colorTextPrimary : theme.colorTextTertiary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      );

  @override
  Widget build(BuildContext context) {
    final text = Text(label, style: styleFor(theme, selected: selected));
    final rowHeight = height;
    return AppPressFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(theme.radiusSm),
      // In the main nav: the full row height, not just the text's own
      // intrinsic bounds — see `AppTopNav.build`'s own comment on why this
      // bar's hit area matches `AppTabSwitch`'s 40px track exactly.
      // `Center` keeps the text vertically centered inside that taller box.
      child: rowHeight == null
          ? text
          : SizedBox(
              height: rowHeight,
              child: Center(child: text),
            ),
    );
  }
}
