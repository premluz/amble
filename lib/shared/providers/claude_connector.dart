import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/clock_provider.dart';

import '../repositories/preferences_repository.dart';
import '../services/assistant/assistant_tool.dart';
import '../services/assistant/claude_bundle.dart';
import '../services/claude_connect_service.dart';
import 'assistant_connection.dart';
import 'assistant_providers.dart';
import 'preferences_providers.dart';

/// How a press of "Connect to Claude" ended, for the Settings screen to
/// explain in plain words.
enum ClaudeConnectOutcome {
  /// Claude is showing its Install dialog.
  opened,

  /// Claude Desktop is not on this Mac.
  claudeMissing,

  /// The file could not be written or Claude did not open it.
  failed,
}

/// True when Claude has presented an outdated secret since the last
/// Connect: its installed copy of the extension is older than Amble's
/// current one. Session-only; cleared by Connect.
class ClaudeExtensionStale extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool stale) => state = stale;
}

final claudeExtensionStaleProvider =
    NotifierProvider<ClaudeExtensionStale, bool>(ClaudeExtensionStale.new);

final claudeConnectServiceProvider = Provider<ClaudeConnectService>(
  (ref) => const ClaudeConnectService(),
);

/// Loads the helper script; overridable in tests.
final claudeHelperScriptProvider = Provider<Future<String> Function()>(
  (ref) =>
      () => rootBundle.loadString(ClaudeBundle.helperAsset),
);

/// Turns access on and hands Claude a ready-made extension: no copying, no
/// config files. Also removes that file again once Claude has connected,
/// because it carries the connection secret.
class ClaudeConnector {
  ClaudeConnector(this._ref);

  final Ref _ref;

  PreferencesRepository get _prefs => _ref.read(preferencesRepositoryProvider);

  Future<ClaudeConnectOutcome> connect(AssistantPermission permission) async {
    final service = _ref.read(claudeConnectServiceProvider);
    _ref.read(claudeExtensionStaleProvider.notifier).set(false);
    if (!await service.isClaudeInstalled()) {
      return ClaudeConnectOutcome.claudeMissing;
    }
    await _ref.read(assistantConnectionProvider.notifier).connect(permission);
    final directory = await service.downloadsDirectory();
    if (directory == null) return ClaudeConnectOutcome.failed;
    final info = await PackageInfo.fromPlatform();
    final connection = _ref.read(assistantConnectionProvider);
    final bytes = ClaudeBundle.build(
      version: ClaudeBundle.versionFor(info.version, _ref.read(nowProvider)()),
      port: connection.port,
      secret: connection.secret,
      appBundleId: info.packageName,
      helperScript: await _ref.read(claudeHelperScriptProvider)(),
      tools: _ref.read(assistantToolboxProvider).available,
    );
    final file = File('$directory/${ClaudeBundle.fileName}');
    await file.writeAsBytes(bytes, flush: true);
    await _prefs.setValue(PreferenceKeys.assistantBundlePath, file.path);
    return await service.openInClaude(file.path)
        ? ClaudeConnectOutcome.opened
        : ClaudeConnectOutcome.failed;
  }

  /// Claude has reached Amble for the first time since Connect: stop
  /// waiting in Settings and delete the file that carried the secret.
  Future<void> claudeConnected() async {
    await _ref.read(assistantConnectionProvider.notifier).markClaudeSeen();
    await removeBundleFile();
  }

  /// The saved port is taken: move to a free one and hand Claude a fresh
  /// extension that points there.
  Future<ClaudeConnectOutcome> reconnect() async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    await _ref.read(assistantConnectionProvider.notifier).setPort(port);
    return connect(_ref.read(assistantConnectionProvider).permission);
  }

  /// Deletes the extension file if it is still there. Safe to call often.
  Future<void> removeBundleFile() async {
    final path = _prefs.getValue<String>(PreferenceKeys.assistantBundlePath);
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
    await _prefs.setValue<String?>(PreferenceKeys.assistantBundlePath, null);
  }

  /// Turns access off, replaces the secret and removes any leftover file.
  Future<void> disconnect() async {
    await _ref.read(assistantConnectionProvider.notifier).disconnect();
    await removeBundleFile();
  }
}

final claudeConnectorProvider = Provider<ClaudeConnector>(ClaudeConnector.new);
