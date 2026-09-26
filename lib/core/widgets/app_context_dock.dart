import 'dart:async';

import 'package:flutter/material.dart';

import '../tokens/motion_primitives.dart';
import '../tokens/semantic_theme.dart';
import 'app_button.dart';
import 'app_context_dock_config.dart';
import 'app_dock_primitives.dart';

export 'app_context_dock_config.dart';

part 'app_context_dock_render.dart';
part 'app_context_dock_entrance.dart';

/// A state-driven dock. Action IDs are stable across configurations, so a
/// retained action keeps its button state while groups resize around it.
class AppContextDock extends StatefulWidget {
  const AppContextDock({super.key, required this.configuration, this.theme});

  final AppContextDockConfiguration configuration;
  final AmbleTheme? theme;

  @override
  State<AppContextDock> createState() => _AppContextDockState();
}

class _DockEntry {
  _DockEntry(this.action, this.groupId, this.slot);
  AppContextAction action;
  String groupId;
  int slot;
  bool present = true;
  bool entering = false;
  bool exiting = false;
  Rect? rect;
}

class _DockPaneEntry {
  _DockPaneEntry(this.group);
  AppContextGroup group;
  Rect? rect;
  bool present = true;
  bool entering = false;
}

class _AppContextDockState extends State<AppContextDock> {
  final _entries = <String, _DockEntry>{};
  final _panes = <String, _DockPaneEntry>{};
  final _pendingRemoval = <String>{};
  String? _shapeSignature;
  int _transitionGeneration = 0;
  Timer? _pruneTimer;
  final _entranceTimers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _replaceConfiguration(widget.configuration, initial: true);
  }

  @override
  void didUpdateWidget(AppContextDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _replaceConfiguration(widget.configuration);
  }

  void _replaceConfiguration(
    AppContextDockConfiguration configuration, {
    bool initial = false,
  }) {
    final shapeSignature = _configurationShape(configuration);
    for (final pane in _panes.values) {
      pane.present = false;
    }
    for (final group in configuration.groups) {
      final pane = _panes.putIfAbsent(
        group.id,
        () => _DockPaneEntry(group)..entering = !initial,
      );
      pane.group = group;
      pane.present = group.actions.isNotEmpty;
    }
    if (!initial && shapeSignature == _shapeSignature) {
      for (final group in configuration.groups) {
        for (final action in group.actions) {
          final entry = _entries[action.id];
          if (entry != null) entry.action = action;
        }
      }
      return;
    }

    final incoming = <String, _DockEntry>{};
    for (final group in configuration.groups) {
      for (var slot = 0; slot < group.actions.length; slot++) {
        final action = group.actions[slot];
        final existing = _entries[action.id];
        if (existing == null) {
          incoming[action.id] = _DockEntry(action, group.id, slot)
            ..entering = !initial;
        } else {
          existing
            ..action = action
            ..groupId = group.id
            ..slot = slot
            ..exiting = false
            ..present = true;
          incoming[action.id] = existing;
        }
      }
    }
    for (final entry in _entries.entries) {
      if (!incoming.containsKey(entry.key)) {
        entry.value.present = false;
        incoming[entry.key] = entry.value;
      }
    }
    _entries
      ..clear()
      ..addAll(incoming);
    _shapeSignature = shapeSignature;
    if (initial) return;
    final generation = ++_transitionGeneration;
    _pruneTimer?.cancel();
    _pendingRemoval
      ..clear()
      ..addAll(
        _entries.values
            .where((entry) => !entry.present)
            .map((entry) => entry.action.id),
      );
    _scheduleEntrance(generation);
    _pruneTimer = Timer(
      Duration(milliseconds: MotionPrimitives.durationContextDockMs +
          _pendingRemoval.length * MotionPrimitives.durationContextDockStaggerMs),
      () {
        if (!mounted || generation != _transitionGeneration) return;
        setState(() {
          _entries.removeWhere((id, _) => _pendingRemoval.contains(id));
          _panes.removeWhere((id, pane) => !pane.present);
          _pendingRemoval.clear();
        });
      },
    );
  }

  String _configurationShape(
    AppContextDockConfiguration configuration,
  ) => configuration.groups
      .map(
        (group) =>
            '${group.id}:${group.actions.map((action) => action.id).join(',')}',
      )
      .join('|');

  void _revealEntry(_DockEntry entry, int generation) {
    if (!mounted || generation != _transitionGeneration || !entry.present) return;
    setState(() {
      entry.entering = false;
      // A new pane arrives with its first icon, never as an empty shell.
      _panes[entry.groupId]?.entering = false;
    });
  }

  void _hideEntry(_DockEntry entry, int generation) {
    if (!mounted || generation != _transitionGeneration || entry.present) return;
    setState(() => entry.exiting = true);
  }

  @override
  void dispose() {
    _pruneTimer?.cancel();
    for (final timer in _entranceTimers) {
      timer.cancel();
    }
    _pendingRemoval.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? Theme.of(context).extension<AmbleTheme>()!;
    return _AppContextDockLayout(
      theme: theme,
      configuration: widget.configuration,
      entries: _entries,
      panes: _panes,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(
              milliseconds: MotionPrimitives.durationContextDockMs,
            ),
    );
  }
}
