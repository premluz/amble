import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_selectable_chip.dart';

/// The four sub-tabs of the "Manage" screen (formerly just "Inbox," now
/// broadened to also host Zones and Categories management) — requested
/// directly: "The first tab will be 'Inbox Manage,' and it will have:
/// Tasks, Templates, Zones (list + add + edit), Categories (list + add +
/// edit)."
enum InboxManageTab { tasks, templates, zones, categories }

/// The Manage screen's own tab selector — the [leading] content of its
/// [AppBottomExtensionBar], the same bottom "extension" bar the Timeline's
/// DayStrip uses for day navigation.
///
/// [AppSelectableChip]s in a horizontally scrollable row rather than a
/// Material `TabBar`: the app has no `AppBar` anywhere (see
/// ARCHITECTURE.md's system-bar note) for a TabBar to live in, and this
/// chip is already the design system's own established selector — the
/// duration presets and the Repeats day-of-week row both use it. Scrolling
/// (rather than shrinking each chip) is what four labels now need to fit
/// without truncating, where the original two-chip switcher had room to
/// spare.
class InboxTabSwitcher extends StatelessWidget {
  const InboxTabSwitcher({
    super.key,
    required this.theme,
    required this.selected,
    required this.onChanged,
  });

  final AmbleTheme theme;
  final InboxManageTab selected;
  final ValueChanged<InboxManageTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (index, tab) in InboxManageTab.values.indexed) ...[
            if (index > 0) SizedBox(width: theme.spacingSm),
            AppSelectableChip(
              label: _label(tab),
              selected: selected == tab,
              onTap: () => onChanged(tab),
            ),
          ],
        ],
      ),
    );
  }

  String _label(InboxManageTab tab) => switch (tab) {
    InboxManageTab.tasks => 'Tasks',
    InboxManageTab.templates => 'Templates',
    InboxManageTab.zones => 'Zones',
    InboxManageTab.categories => 'Categories',
  };
}
