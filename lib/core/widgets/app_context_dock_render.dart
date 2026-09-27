part of 'app_context_dock.dart';

class _AppContextDockLayout extends StatelessWidget {
  const _AppContextDockLayout({
    required this.theme,
    required this.configuration,
    required this.entries,
    required this.panes,
    required this.duration,
  });

  final AmbleTheme theme;
  final AppContextDockConfiguration configuration;
  final Map<String, _DockEntry> entries;
  final Map<String, _DockPaneEntry> panes;
  final Duration duration;

  double get _buttonSize => appButtonHeightFor(theme, AppButtonSize.md);

  Map<String, List<_DockEntry>> _entriesByGroup() {
    final result = <String, List<_DockEntry>>{};
    for (final group in configuration.groups) {
      result[group.id] = [
        for (final action in group.actions) entries[action.id]!,
      ];
    }
    return result;
  }

  double _groupWidth(int count) =>
      theme.spacingXs * 2 +
      _buttonSize * count +
      theme.spacingXs * (count > 0 ? count - 1 : 0);

  @override
  Widget build(BuildContext context) {
    final byGroup = _entriesByGroup();
    final groups = configuration.groups;
    final positions = <String, Rect>{};
    final groupRects = <String, Rect>{};
    var left = 0.0;
    final height = _buttonSize + theme.spacingXs * 2;
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      final groupEntries = byGroup[group.id] ?? const <_DockEntry>[];
      if (groupEntries.isEmpty) continue;
      final width = _groupWidth(groupEntries.length);
      groupRects[group.id] = Rect.fromLTWH(left, 0, width, height);
      panes[group.id]!.rect = groupRects[group.id];
      for (var index = 0; index < groupEntries.length; index++) {
        final entry = groupEntries[index];
        positions[entry.action.id] = Rect.fromLTWH(
          left + theme.spacingXs + index * (_buttonSize + theme.spacingXs),
          theme.spacingXs,
          _buttonSize,
          _buttonSize,
        );
        entry.rect = positions[entry.action.id];
      }
      left += width;
      if (groupIndex < groups.length - 1) left += theme.spacingSm;
    }

    // Departing controls fade where they were; they never join target layout.
    for (final entry in entries.values.where((entry) => !entry.present)) {
      if (entry.rect case final rect?) positions[entry.action.id] = rect;
    }

    return SizedBox(
      width: left,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final pane in panes.values)
            if (pane.rect case final rect?)
              AnimatedPositioned(
                key: ValueKey('dock-pane-${pane.group.id}'),
                duration: duration,
                curve: theme.curveStandard,
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity:
                        !pane.entering &&
                            (pane.present ||
                                entries.values.any(
                                  (entry) =>
                                      entry.groupId == pane.group.id &&
                                      !entry.exiting,
                                ))
                        ? 1
                        : 0,
                    duration: duration,
                    curve: theme.curveStandard,
                    child: AppDockSurface(
                      theme: theme,
                      grouped: pane.group.actions.length > 1,
                      backgroundColor: pane.group.backgroundColor,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
          for (final entry in entries.values)
            if (positions[entry.action.id] case final rect?)
              AnimatedPositioned(
                key: ValueKey('dock-action-${entry.action.id}'),
                duration: duration,
                curve: theme.curveStandard,
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                child: AnimatedOpacity(
                  opacity: !entry.exiting && !entry.entering ? 1 : 0,
                  duration: duration,
                  curve: theme.curveStandard,
                  // `entering` is deliberately EXCLUDED from every gate
                  // below (unlike the opacity fade above, which keeps it)
                  // — regression, reported directly: "when multiselecting
                  // zones and delete, it deletes 1 or 2 sometimes but not
                  // all at once selected." Root cause: `entering` starts
                  // `true` for any action newly added to an ALREADY-VISIBLE
                  // dock (e.g. Edit/Remove appearing next to an existing
                  // Close the moment a selection becomes non-empty — see
                  // `AppContextDock._replaceConfiguration`'s own
                  // `..entering = !initial`), and stays `true` for the
                  // ~200-270ms staggered entrance. A user who selects
                  // several items and taps Remove quickly (an entirely
                  // ordinary interaction, not an edge case) can tap before
                  // that timer clears `entering`, and the tap was
                  // previously swallowed here with no feedback at all —
                  // confirmed directly with a widget-test probe: the
                  // button doesn't even exist in the tree for the first
                  // frame after selecting, then exists-but-ignores-taps
                  // for another ~200ms. `entering` genuinely only means
                  // "still fading in cosmetically" once a dock already has
                  // visible content (it is NEVER `true` on the dock's own
                  // first-ever mount — see `_replaceConfiguration`'s
                  // `initial` parameter), so gating real interaction on it
                  // was never actually protecting a genuine "not ready
                  // yet" state, only adding a needless dead window.
                  child: ExcludeFocus(
                    excluding: !entry.present,
                    child: ExcludeSemantics(
                      excluding: !entry.present,
                      child: IgnorePointer(
                        ignoring: !entry.present,
                        child: Semantics(
                          key: ValueKey(entry.action.id),
                          button: true,
                          enabled: entry.action.enabled,
                          label:
                              entry.action.accessibilityLabel ??
                              entry.action.tooltip,
                          child: AppDockIconButton(
                            theme: theme,
                            icon: entry.action.icon,
                            tooltip: entry.action.tooltip,
                            selected: entry.action.selected,
                            isDestructive: entry.action.destructive,
                            haptic: entry.action.haptic,
                            badgeCount: entry.action.badgeCount,
                            onTap: entry.action.enabled && entry.present
                                ? entry.action.onPressed
                                : null,
                          ),
                        ),
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
