import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/clock_provider.dart';
import '../services/assistant/assistant_activity.dart';
import '../services/assistant/assistant_server.dart';
import '../services/assistant/assistant_toolbox.dart';
import '../services/assistant/mcp_protocol.dart';
import 'assistant_backend.dart';
import 'assistant_connection.dart';
import 'claude_connector.dart';

/// The assistant's changes this session, for Settings › Claude and the Undo
/// toast.
final assistantActivityProvider = Provider<AssistantActivityLog>(
  (ref) => AssistantActivityLog(ref.read(nowProvider)),
);

final assistantToolboxProvider = Provider<AssistantToolbox>(
  (ref) => AssistantToolbox(
    backend: AppAssistantBackend(ref),
    activity: ref.watch(assistantActivityProvider),
    permission: () => ref.read(assistantConnectionProvider).permission,
  ),
);

/// Whether the endpoint can run here: the desktop Mac app only, where the
/// Claude extension lives.
final assistantServerSupportedProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS,
);

sealed class AssistantServerStatus {
  const AssistantServerStatus();
}

/// Not connected, or not on a platform that serves assistants.
class AssistantServerOff extends AssistantServerStatus {
  const AssistantServerOff();
}

class AssistantServerRunning extends AssistantServerStatus {
  const AssistantServerRunning(this.port);

  final int port;
}

/// The saved port is taken by another app. Settings offers Reconnect.
class AssistantServerPortBusy extends AssistantServerStatus {
  const AssistantServerPortBusy(this.port, this.reason);

  final int port;
  final String reason;
}

/// Runs the endpoint while an assistant is connected, and stops it when the
/// user disconnects (or the secret, port or permission source changes).
/// Watched from the app root so it lives for the whole session.
final assistantServerProvider = FutureProvider<AssistantServerStatus>((
  ref,
) async {
  // Only what the server itself depends on: the permission and the "Claude
  // seen" flag change without restarting it mid-conversation.
  final connection = ref.watch(
    assistantConnectionProvider.select(
      (s) => (connected: s.connected, port: s.port, secret: s.secret),
    ),
  );
  if (!connection.connected || !ref.watch(assistantServerSupportedProvider)) {
    return const AssistantServerOff();
  }
  final info = await PackageInfo.fromPlatform();
  final server = AssistantServer(
    protocol: McpProtocol(
      toolbox: ref.watch(assistantToolboxProvider),
      appVersion: info.version,
    ),
    secret: connection.secret,
    // Claude's copy carries an old secret: offer Update in Settings.
    onWrongSecret: () =>
        ref.read(claudeExtensionStaleProvider.notifier).set(true),
    // Claude has installed the extension; its file held the secret.
    onFirstAuthorisedRequest: () => ref
        .read(claudeConnectorProvider)
        .claudeConnected()
        .catchError(
          (Object error) => developer.log(
            'Could not remove the Claude extension file',
            name: 'amble.assistant',
            error: error,
          ),
        ),
  );
  ref.onDispose(server.stop);
  try {
    await server.start(connection.port);
  } on SocketException catch (error) {
    return AssistantServerPortBusy(connection.port, error.message);
  }
  return AssistantServerRunning(connection.port);
});
