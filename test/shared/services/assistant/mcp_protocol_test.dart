import 'package:amble/shared/services/assistant/assistant_activity.dart';
import 'package:amble/shared/services/assistant/assistant_tool.dart';
import 'package:amble/shared/services/assistant/assistant_toolbox.dart';
import 'package:amble/shared/services/assistant/mcp_messages.dart';
import 'package:amble/shared/services/assistant/mcp_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_assistant_backend.dart';

final _now = DateTime(2026, 10, 12, 8);
const _modern = '2026-07-28';

Map<String, Object?> _modernMeta() => {
  '_meta': {
    Mcp.metaVersion: _modern,
    'io.modelcontextprotocol/clientInfo': {'name': 'test', 'version': '1'},
    'io.modelcontextprotocol/clientCapabilities': <String, Object?>{},
  },
};

void main() {
  late AssistantPermission permission;
  late McpProtocol protocol;

  setUp(() {
    permission = AssistantPermission.read;
    protocol = McpProtocol(
      toolbox: AssistantToolbox(
        backend: FakeAssistantBackend(clock: _now),
        activity: AssistantActivityLog(() => _now),
        permission: () => permission,
      ),
      appVersion: '1.2.3',
    );
  });

  Future<McpReply> send(
    String method, [
    Map<String, Object?> params = const {},
    Map<String, String> headers = const {},
  ]) => protocol.handle({
    'jsonrpc': '2.0',
    'id': 1,
    'method': method,
    'params': params,
  }, headers);

  Map<String, Object?> result(McpReply reply) =>
      reply.body!['result']! as Map<String, Object?>;

  Map<String, Object?> error(McpReply reply) =>
      reply.body!['error']! as Map<String, Object?>;

  group('legacy clients (initialize handshake)', () {
    test('initialize echoes a supported version and names Amble', () async {
      final reply = await send('initialize', {'protocolVersion': '2025-06-18'});
      expect(reply.status, 200);
      expect(result(reply)['protocolVersion'], '2025-06-18');
      expect(result(reply)['serverInfo'], {
        'name': 'Amble',
        'version': '1.2.3',
      });
      expect(result(reply)['capabilities'], contains('tools'));
    });

    test('an unknown requested version gets the newest legacy one', () async {
      final reply = await send('initialize', {'protocolVersion': '2024-01-01'});
      expect(result(reply)['protocolVersion'], Mcp.legacyVersions.first);
    });

    test('a notification is acknowledged with 202 and no body', () async {
      final reply = await protocol.handle({
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      }, const {});
      expect(reply.status, 202);
      expect(reply.body, isNull);
    });

    test('tools/list offers every tool, with hints', () async {
      final tools = (result(await send('tools/list'))['tools']! as List)
          .cast<Map>();
      expect(tools, hasLength(8));
      expect(tools.first['annotations'], containsPair('readOnlyHint', true));
      final add = tools.firstWhere((t) => t['name'] == 'add_task');
      expect(add['annotations'], containsPair('readOnlyHint', false));
      expect(add['annotations'], containsPair('destructiveHint', false));
    });

    test('tools/call returns text and structured content', () async {
      final reply = await send('tools/call', {
        'name': 'get_availability',
        'arguments': {'from': '2026-10-12', 'to': '2026-10-12'},
      });
      final body = result(reply);
      expect(body['isError'], false);
      expect(body['structuredContent'], contains('free'));
      expect(((body['content']! as List).single as Map)['type'], 'text');
    });

    test('a refused write is a tool error the assistant can read', () async {
      final reply = await send('tools/call', {
        'name': 'add_task',
        'arguments': {
          'title': 'X',
          'start': '2026-10-13T10:00',
          'duration_minutes': 30,
        },
      });
      expect(reply.status, 200);
      expect(result(reply)['isError'], true);
    });

    test('an unknown tool is a protocol error (-32602)', () async {
      final reply = await send('tools/call', {'name': 'nope', 'arguments': {}});
      expect(error(reply)['code'], Mcp.invalidParams);
    });

    test('an unknown method is -32601', () async {
      expect(error(await send('resources/list'))['code'], Mcp.methodNotFound);
    });

    test('a legacy header naming an unknown version is refused', () async {
      final reply = await send('tools/list', const {}, {
        'mcp-protocol-version': '1999-01-01',
      });
      expect(reply.status, 400);
      expect(error(reply)['code'], Mcp.unsupportedVersion);
    });
  });

  group('modern clients (per-request metadata)', () {
    Map<String, String> headers(String method, [String? name]) => {
      'mcp-protocol-version': _modern,
      'mcp-method': method,
      'mcp-name': ?name,
    };

    test('server/discover lists versions and the server', () async {
      final reply = await send(
        'server/discover',
        _modernMeta(),
        headers('server/discover'),
      );
      final body = result(reply);
      expect(body['resultType'], 'complete');
      expect(body['supportedVersions'], contains(_modern));
      expect(body['supportedVersions'], contains('2025-06-18'));
    });

    test('tools/list and server/discover carry the required cache hints '
        '(Claude rejects them otherwise)', () async {
      for (final method in ['tools/list', 'server/discover']) {
        final body = result(await send(method, _modernMeta(), headers(method)));
        expect(body['ttlMs'], 0, reason: method);
        expect(body['cacheScope'], 'private', reason: method);
      }
    });

    test('legacy results carry no modern-only fields', () async {
      final body = result(await send('tools/list'));
      expect(body.containsKey('ttlMs'), isFalse);
      expect(body.containsKey('resultType'), isFalse);
    });

    test('tools/call with matching headers works', () async {
      final reply = await send('tools/call', {
        ..._modernMeta(),
        'name': 'list_categories',
        'arguments': <String, Object?>{},
      }, headers('tools/call', 'list_categories'));
      expect(reply.status, 200);
      expect(result(reply)['resultType'], 'complete');
    });

    test('a header that disagrees with the body is -32020', () async {
      final reply = await send('tools/call', {
        ..._modernMeta(),
        'name': 'list_categories',
        'arguments': <String, Object?>{},
      }, headers('tools/call', 'get_day'));
      expect(reply.status, 400);
      expect(error(reply)['code'], Mcp.headerMismatch);
    });

    test('a base64-encoded Mcp-Name is decoded before comparing', () async {
      final reply = await send('tools/call', {
        ..._modernMeta(),
        'name': 'list_categories',
        'arguments': <String, Object?>{},
      }, headers('tools/call', '=?base64?bGlzdF9jYXRlZ29yaWVz?='));
      expect(reply.status, 200);
    });

    test('an unsupported modern version lists what is supported', () async {
      final reply = await send(
        'tools/list',
        {
          '_meta': {Mcp.metaVersion: '2099-01-01'},
        },
        {'mcp-protocol-version': '2099-01-01', 'mcp-method': 'tools/list'},
      );
      expect(reply.status, 400);
      expect(error(reply)['code'], Mcp.unsupportedVersion);
      expect((error(reply)['data']! as Map)['supported'], contains(_modern));
    });

    test('an unknown method is 404 with -32601', () async {
      final reply = await send(
        'prompts/list',
        _modernMeta(),
        headers('prompts/list'),
      );
      expect(reply.status, 404);
      expect(error(reply)['code'], Mcp.methodNotFound);
    });
  });

  test('a body that is not JSON-RPC 2.0 is a 400', () async {
    final reply = await protocol.handle({'hello': 'world'}, const {});
    expect(reply.status, 400);
  });
}
