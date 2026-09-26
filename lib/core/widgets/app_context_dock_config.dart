import 'package:flutter/material.dart';

import '../haptics.dart';

@immutable
class AppContextAction {
  const AppContextAction({
    required this.id,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.enabled = true,
    this.destructive = false,
    this.accessibilityLabel,
    this.haptic = AmbleHaptic.tap,
  });

  final String id;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final bool enabled;
  final bool destructive;
  final String? accessibilityLabel;
  final AmbleHaptic haptic;
}

@immutable
class AppContextGroup {
  const AppContextGroup({
    required this.id,
    required this.actions,
    this.backgroundColor,
  });

  final String id;
  final List<AppContextAction> actions;
  final Color? backgroundColor;
}

@immutable
class AppContextDockConfiguration {
  const AppContextDockConfiguration({
    required this.stateId,
    required this.groups,
  });

  final String stateId;
  final List<AppContextGroup> groups;
}
