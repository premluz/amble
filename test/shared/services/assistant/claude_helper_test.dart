import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:amble/shared/services/assistant/assistant_activity.dart';
import 'package:amble/shared/services/assistant/assistant_server.dart';
import 'package:amble/shared/services/assistant/assistant_tool.dart';
import 'package:amble/shared/services/assistant/assistant_toolbox.dart';
import 'package:amble/shared/services/assistant/claude_bundle.dart';
import 'package:amble/shared/services/assistant/mcp_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_assistant_backend.dart';

/// Runs the real Node helper (`assets/claude/amble-mcp.js`) against a real
/// endpoint, the way Claude Desktop would: JSON-RPC lines on stdin, answers
/// on stdout. Skipped where Node is not installed.
final _node = Platform.environment['PATH']
    ?.split(':')
    .map((dir) => File('$dir/node'))
    .where((file) => file.existsSync())
    .firstOrNull;

final _now = DateTime(2026, 10, 12, 8);
const _secret = 'helper-secret';

class _Helper {
  _Helper(this.process) {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _lines.add(jsonDecode(line) as Map<String, Object?>));
  }

  final Process process;
  final _lines = StreamController<Map<String, Object?>>();
  late final _replies = StreamIterator(_lines.stream);

  Future<Map<String, Object?>> send(Map<String, Object?> message) async {
    process.stdin.writeln(jsonEncode(message));
    await process.stdin.flush();
    if (!message.containsKey('id')) return const {};
    if (!await _replies.moveNext().timeout(const Duration(seconds: 15))) {
      throw StateError('helper closed');
    }
    return _replies.current;
  }

  Future<void> close() async {
    await process.stdin.close();
    await process.exitCode.timeout(const Duration(seconds: 5));
  }
}

void main() {
  late AssistantServer server;

  setUp(() async {
    server = AssistantServer(
      protocol: McpProtocol(
        toolbox: AssistantToolbox(
          backend: FakeAssistantBackend(clock: _now),
          activity: AssistantActivityLog(() => _now),
          permission: () => AssistantPermission.read,
        ),
        appVersion: '1.0.0',
      ),
      secret: _secret,
    );
    await server.start(0);
  });

  tearDown(() => server.stop());

  Future<_Helper> start({String secret = _secret, int? port}) async => _Helper(
    await Process.start(
      _node!.path,
      [ClaudeBundle.helperAsset],
      environment: {
        'AMBLE_PORT': '${port ?? server.port}',
        'AMBLE_SECRET': secret,
        'AMBLE_BUNDLE_ID': '',
        'AMBLE_LAUNCH_WAIT_MS': '300',
      },
    ),
  );

  test('pipes a legacy session: initialize, tools/list, tools/call', () async {
    final helper = await start();
    final init = await helper.send({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {
        'protocolVersion': '2025-06-18',
        'capabilities': {},
        'clientInfo': {'name': 'test', 'version': '1'},
      },
    });
    expect((init['result']! as Map)['protocolVersion'], '2025-06-18');
    await helper.send({
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    });
    final list = await helper.send({
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'tools/list',
    });
    expect(((list['result']! as Map)['tools'] as List), hasLength(8));
    final call = await helper.send({
      'jsonrpc': '2.0',
      'id': 3,
      'method': 'tools/call',
      'params': {'name': 'list_categories', 'arguments': {}},
    });
    expect((call['result']! as Map)['isError'], false);
    await helper.close();
  }, skip: _node == null);

  test('pipes a modern request with the mirrored headers', () async {
    final helper = await start();
    final reply = await helper.send({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/call',
      'params': {
        'name': 'list_categories',
        'arguments': {},
        '_meta': {'io.modelcontextprotocol/protocolVersion': '2026-07-28'},
      },
    });
    expect((reply['result']! as Map)['resultType'], 'complete');
    await helper.close();
  }, skip: _node == null);

  test('a wrong secret becomes a plain "reconnect" message', () async {
    final helper = await start(secret: 'old');
    final reply = await helper.send({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/list',
    });
    expect((reply['error']! as Map)['message'], contains('Reconnect Claude'));
    await helper.close();
  }, skip: _node == null);

  test('Amble not running: a plain message after the wait', () async {
    final port = server.port!;
    await server.stop();
    final helper = await start(port: port);
    final reply = await helper.send({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/list',
    });
    expect(
      (reply['error']! as Map)['message'],
      contains("Amble isn't running"),
    );
    await helper.close();
    await server.start(0); // for tearDown
  }, skip: _node == null);
}
