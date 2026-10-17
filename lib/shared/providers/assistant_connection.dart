import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/preferences_repository.dart';
import '../services/assistant/assistant_tool.dart';
import 'preferences_providers.dart';

/// Whether an assistant is connected, and on what terms.
class AssistantConnectionState {
  const AssistantConnectionState({
    required this.connected,
    required this.permission,
    required this.port,
    required this.secret,
    this.claudeSeen = false,
  });

  final bool connected;

  /// Whether Claude has reached Amble since the last Connect: false while
  /// Claude's Install dialog is still waiting for the person.
  final bool claudeSeen;
  final AssistantPermission permission;
  final int port;

  /// The value Claude's extension sends as its bearer token. Never shown in
  /// the everyday UI; rotated on every disconnect.
  final String secret;
}

/// Settings › Claude, persisted through the preferences repository. Off by
/// default; read-only unless the user chooses otherwise.
class AssistantConnection extends Notifier<AssistantConnectionState> {
  PreferencesRepository get _prefs => ref.read(preferencesRepositoryProvider);

  @override
  AssistantConnectionState build() {
    final stored = _prefs.getValue<String>(PreferenceKeys.assistantPermission);
    return AssistantConnectionState(
      connected:
          _prefs.getValue<bool>(PreferenceKeys.assistantConnected) ?? false,
      permission:
          AssistantPermission.values
              .where((p) => p.name == stored)
              .firstOrNull ??
          AssistantPermission.read,
      port:
          _prefs.getValue<int>(PreferenceKeys.assistantPort) ??
          AssistantLimits.defaultPort,
      secret: _prefs.getValue<String>(PreferenceKeys.assistantSecret) ?? '',
      claudeSeen:
          _prefs.getValue<bool>(PreferenceKeys.assistantClaudeSeen) ?? false,
    );
  }

  /// Turns access on with [permission], creating a secret if there is none.
  Future<void> connect(AssistantPermission permission) async {
    final secret = state.secret.isEmpty ? newAssistantSecret() : state.secret;
    await _prefs.setValue(PreferenceKeys.assistantSecret, secret);
    await _prefs.setValue(PreferenceKeys.assistantPermission, permission.name);
    await _prefs.setValue(PreferenceKeys.assistantConnected, true);
    await _prefs.setValue(PreferenceKeys.assistantClaudeSeen, false);
    state = AssistantConnectionState(
      connected: true,
      permission: permission,
      port: state.port,
      secret: secret,
    );
  }

  Future<void> setPermission(AssistantPermission permission) async {
    await _prefs.setValue(PreferenceKeys.assistantPermission, permission.name);
    state = AssistantConnectionState(
      connected: state.connected,
      permission: permission,
      port: state.port,
      secret: state.secret,
      claudeSeen: state.claudeSeen,
    );
  }

  /// Records that Claude has reached Amble, so Settings stops waiting.
  Future<void> markClaudeSeen() async {
    if (state.claudeSeen) return;
    await _prefs.setValue(PreferenceKeys.assistantClaudeSeen, true);
    state = _copy(claudeSeen: true);
  }

  /// Moves to another port, for when the saved one is taken. The extension
  /// must be rebuilt afterwards (it carries the port).
  Future<void> setPort(int port) async {
    await _prefs.setValue(PreferenceKeys.assistantPort, port);
    state = _copy(port: port);
  }

  AssistantConnectionState _copy({bool? claudeSeen, int? port}) =>
      AssistantConnectionState(
        connected: state.connected,
        permission: state.permission,
        port: port ?? state.port,
        secret: state.secret,
        claudeSeen: claudeSeen ?? state.claudeSeen,
      );

  /// Turns access off and replaces the secret, so an extension installed
  /// earlier stops working even if access is turned on again later.
  Future<void> disconnect() async {
    final secret = newAssistantSecret();
    await _prefs.setValue(PreferenceKeys.assistantSecret, secret);
    await _prefs.setValue(PreferenceKeys.assistantConnected, false);
    await _prefs.setValue(PreferenceKeys.assistantClaudeSeen, false);
    state = AssistantConnectionState(
      connected: false,
      permission: state.permission,
      port: state.port,
      secret: secret,
    );
  }
}

/// Distinct values one byte can hold.
const _byteValues = 256;

/// A fresh random secret, URL-safe text.
String newAssistantSecret() {
  final random = Random.secure();
  return base64UrlEncode([
    for (var i = 0; i < AssistantLimits.secretBytes; i++)
      random.nextInt(_byteValues),
  ]).replaceAll('=', '');
}

final assistantConnectionProvider =
    NotifierProvider<AssistantConnection, AssistantConnectionState>(
      AssistantConnection.new,
    );
