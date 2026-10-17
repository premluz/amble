import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/providers/assistant_connection.dart';
import '../../shared/providers/assistant_providers.dart';
import '../../shared/providers/claude_connector.dart';
import '../../shared/services/assistant/assistant_activity.dart';
import '../../shared/services/assistant/assistant_server.dart';
import '../../shared/services/assistant/assistant_tool.dart';
import '../settings/settings_detail_scaffold.dart';
import '../settings/settings_panel.dart';
import 'claude_connected_panel.dart';
import 'claude_setup_panels.dart';

Future<void> showClaudeSettingsScreen(BuildContext context) =>
    pushSettingsDetailRoute<void>(
      context,
      (context) => const ClaudeSettingsScreen(),
    );

/// Settings › Claude: connect Claude Desktop to Amble in three clicks, see
/// what it has done, and turn it off. Written for people who have never
/// heard of MCP; the technical details sit behind "Advanced".
class ClaudeSettingsScreen extends ConsumerStatefulWidget {
  const ClaudeSettingsScreen({super.key});

  @override
  ConsumerState<ClaudeSettingsScreen> createState() =>
      _ClaudeSettingsScreenState();
}

class _ClaudeSettingsScreenState extends ConsumerState<ClaudeSettingsScreen> {
  AssistantPermission _choice = AssistantPermission.read;
  ClaudeConnectOutcome? _outcome;
  bool _busy = false;
  late final AssistantActivityLog _activity = ref.read(
    assistantActivityProvider,
  );

  void _refresh(AssistantActivity _) {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _activity.addListener(_refresh);
  }

  @override
  void dispose() {
    _activity.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _run(Future<ClaudeConnectOutcome> Function() action) async {
    setState(() => _busy = true);
    final outcome = await action();
    if (mounted) {
      setState(() {
        _busy = false;
        _outcome = outcome;
      });
    }
  }

  Future<void> _undo(AssistantActivity entry) async {
    await _activity.undo(entry);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return SettingsDetailScaffold(
      title: 'Claude',
      body: SettingsPanel(theme: theme, child: _state(context)),
    );
  }

  Widget _state(BuildContext context) {
    final connection = ref.watch(assistantConnectionProvider);
    final server = ref.watch(assistantServerProvider).value;
    final connector = ref.read(claudeConnectorProvider);
    if (!connection.connected ||
        (_outcome != null && _outcome != ClaudeConnectOutcome.opened)) {
      return _setup(connector);
    }
    return _connectedState(connection, server, connector);
  }

  /// Before access is on, or when the last Connect press did not reach
  /// Claude.
  Widget _setup(ClaudeConnector connector) {
    if (_outcome == ClaudeConnectOutcome.claudeMissing) {
      return ClaudeStep(
        title: "Claude's desktop app is needed",
        body: 'Install Claude for Mac, then come back here.',
        action: "I've installed it",
        onAction: () => _run(() => connector.connect(_choice)),
        secondary: 'Get Claude',
        onSecondary: () =>
            ref.read(claudeConnectServiceProvider).openClaudeDownloadPage(),
        busy: _busy,
      );
    }
    if (_outcome == ClaudeConnectOutcome.failed) {
      return ClaudeStep(
        title: "Amble couldn't open Claude",
        body: 'Make sure Claude is installed and try again.',
        action: 'Try again',
        onAction: () => _run(() => connector.connect(_choice)),
        busy: _busy,
      );
    }
    return ClaudeIntro(
      permission: _choice,
      onPermissionChanged: (p) => setState(() => _choice = p),
      busy: _busy,
      onConnect: () => _run(() => connector.connect(_choice)),
    );
  }

  /// Access is on: waiting for Install, reconnecting, or connected.
  Widget _connectedState(
    AssistantConnectionState connection,
    AssistantServerStatus? server,
    ClaudeConnector connector,
  ) {
    if (ref.watch(claudeExtensionStaleProvider)) {
      return ClaudeStep(
        title: 'Claude has an old copy of Amble',
        body: "Update it, then click Install in Claude's window.",
        action: 'Update Claude',
        onAction: () => _run(() => connector.connect(connection.permission)),
        busy: _busy,
      );
    }
    if (server is AssistantServerPortBusy) {
      return ClaudeStep(
        title: 'Claude lost its connection',
        body: 'Another app is using what Amble needs. Reconnect to fix it.',
        action: 'Reconnect',
        onAction: () => _run(connector.reconnect),
        busy: _busy,
      );
    }
    if (!connection.claudeSeen) {
      return ClaudeStep(
        title: 'Almost there',
        body:
            'Claude is open. Click Install in its window to finish. This '
            'page updates by itself.',
        action: 'Open Claude again',
        onAction: () => _run(() => connector.connect(connection.permission)),
        secondary: 'Cancel',
        onSecondary: () => _disconnect(connector),
        busy: _busy,
      );
    }
    return ClaudeConnectedPanel(
      permission: connection.permission,
      onPermissionChanged: (p) =>
          ref.read(assistantConnectionProvider.notifier).setPermission(p),
      activity: _activity.entries,
      onUndo: _undo,
      onDisconnect: () => _disconnect(connector),
      advancedSnippet:
          'claude mcp add --transport http amble '
          'http://127.0.0.1:${connection.port}${AssistantServer.path} '
          '--header "Authorization: Bearer ${connection.secret}"',
    );
  }

  Future<void> _disconnect(ClaudeConnector connector) async {
    await connector.disconnect();
    if (mounted) setState(() => _outcome = null);
  }
}

/// The Settings row that opens this screen, shown only where Claude can
/// connect (the Mac app); elsewhere it takes no space.
class ClaudeSettingsLink extends ConsumerWidget {
  const ClaudeSettingsLink({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(assistantServerSupportedProvider)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Padding(
      padding: EdgeInsets.only(top: theme.spacingMd),
      child: SettingsLinkRow(
        label: 'Claude',
        onTap: () => showClaudeSettingsScreen(context),
      ),
    );
  }
}
