import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_selectable_chip.dart';

/// The Inbox's Tasks/Templates tab selector.
///
/// Two [AppSelectableChip]s rather than a Material `TabBar`: the app has no
/// `AppBar` anywhere (see ARCHITECTURE.md's system-bar note) for a TabBar to
/// live in, and this chip is already the design system's own established
/// two-way selector — the duration presets and the Repeats day-of-week row
/// both use it. Reaching for `TabBar` here would mean a raw Material widget
/// in a feature screen, against design principle 4.
class InboxTabSwitcher extends StatelessWidget {
  const InboxTabSwitcher({
    super.key,
    required this.theme,
    required this.showTemplates,
    required this.onChanged,
  });

  final AmbleTheme theme;
  final bool showTemplates;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacingScreenPadding,
        0,
        theme.spacingScreenPadding,
        theme.spacingMd,
      ),
      child: Row(
        children: [
          AppSelectableChip(
            label: 'Tasks',
            selected: !showTemplates,
            onTap: () => onChanged(false),
          ),
          SizedBox(width: theme.spacingSm),
          AppSelectableChip(
            label: 'Templates',
            selected: showTemplates,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}
