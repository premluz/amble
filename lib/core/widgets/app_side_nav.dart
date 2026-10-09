import 'package:flutter/material.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';
import 'app_button.dart';
import 'app_nav_label.dart';
import 'app_top_nav.dart' show AppNavSettingsGear;
import 'app_hairline.dart';

/// The wide layout's left sidebar — the same destinations as [AppTopNav]
/// ("Days · Things · Patterns", Settings as a separate gear), stacked
/// vertically. Requested directly, against a desktop-calendar reference:
/// "two panes on the sides: one left navigation... the central area will
/// display the content." The shell shows it instead of [AppTopNav] once the
/// window reaches [ShellLayoutTokens.sideNavMinWindowWidth].
///
/// Same label and gear widgets as [AppTopNav] ([AppNavLabel],
/// [AppNavSettingsGear]), so the two navs differ only in direction, never
/// in look. Provider-agnostic, same contract as [AppTopNav].
class AppSideNav extends StatelessWidget {
  const AppSideNav({
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

  /// See [AppTopNav.settingsSelected].
  final bool settingsSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final rowHeight = appButtonHeightFor(theme, AppButtonSize.md);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorSurfaceTimeline,
        border: Border(
          right: AppHairline.side(context, ShellLayoutTokens.dividerAlpha),
        ),
      ),
      child: SizedBox(
        width: ShellLayoutTokens.sideNavWidth,
        child: Padding(
          // Below the top safe area: on macOS that is the title bar, whose
          // window buttons sit over this sidebar's top-left corner.
          padding: EdgeInsets.all(
            theme.spacingLg,
          ).copyWith(top: theme.spacingLg + MediaQuery.paddingOf(context).top),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < destinations.length; i++)
                // In a Row, not straight in the Column: AppNavLabel centers
                // its text, which in a Column spans the sidebar's full
                // width. A Row gives it unbounded width, so it shrinks to
                // the text and sits left-aligned, like the gear below.
                Row(
                  children: [
                    AppNavLabel(
                      theme: theme,
                      label: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onDestinationSelected(i),
                      height: rowHeight,
                    ),
                  ],
                ),
              const Spacer(),
              // Pulled left by the gap between the gear and its tap box's
              // edge, so the GLYPH lines up with the labels above it — the
              // mirror of [AppTopNav]'s own right-edge optical alignment.
              Transform.translate(
                offset: Offset(
                  -(rowHeight - TopNavTokens.settingsIconSize) / 2,
                  0,
                ),
                child: AppNavSettingsGear(
                  selected: settingsSelected,
                  onTap: onSettingsTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
