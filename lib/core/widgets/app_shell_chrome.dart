import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'app_context_dock_config.dart';

/// Route-scoped owner for the persistent shell chrome. Feature routes may
/// claim the dock while active; stale owners cannot clear a newer route.
class AppShellChromeController extends ChangeNotifier {
  String? _ownerId;
  AppContextDockConfiguration? _configuration;
  String? _signature;
  bool _notificationScheduled = false;
  bool _dockObscured = false;
  bool get dockObscured => _dockObscured;

  void setDockObscured(bool value) {
    if (_dockObscured == value) return;
    _dockObscured = value;
    _notifyAfterBuild();
  }

  Widget? header;
  String? _headerState;

  void updateHeader(String state, Widget child) {
    header = child;
    if (_headerState == state) return;
    _headerState = state;
    _notifyAfterBuild();
  }

  AppContextDockConfiguration? get configuration => _configuration;

  void claim(String ownerId, AppContextDockConfiguration configuration) {
    final signature = _configurationSignature(configuration);
    _ownerId = ownerId;
    if (signature == _signature) return;
    _signature = signature;
    _configuration = configuration;
    _notifyAfterBuild();
  }

  void release(String ownerId) {
    if (_ownerId != ownerId) return;
    _dockObscured = false;
    _ownerId = null;
    _signature = null;
    _configuration = null;
    header = null;
    _headerState = null;
    _notifyAfterBuild();
  }

  void _notifyAfterBuild() {
    if (_notificationScheduled) return;
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      if (!_disposed) notifyListeners();
      return;
    }
    _notificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  bool _disposed = false;

  String _configurationSignature(AppContextDockConfiguration configuration) =>
      [
        configuration.stateId,
        for (final group in configuration.groups) ...[
          group.id,
          for (final action in group.actions)
            '${action.id}:${action.icon.codePoint}:${action.tooltip}:${action.selected}:${action.enabled}:${action.destructive}:${action.badgeCount}',
        ],
      ].join('|');

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppShellChromeScope extends InheritedNotifier<AppShellChromeController> {
  const AppShellChromeScope({
    super.key,
    required AppShellChromeController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppShellChromeController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppShellChromeScope>()
          ?.notifier;
}
