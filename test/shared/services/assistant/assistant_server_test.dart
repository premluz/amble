import 'dart:convert';
import 'dart:io';

import 'package:amble/shared/services/assistant/assistant_activity.dart';
import 'package:amble/shared/services/assistant/assistant_server.dart';
import 'package:amble/shared/services/assistant/assistant_tool.dart';
import 'package:amble/shared/services/assistant/assistant_toolbox.dart';
import 'package:amble/shared/services/assistant/mcp_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_assistant_backend.dart';

final _now = DateTime(2026, 10, 12, 8);
const _secret = 'test-secret';

void main() {
  late AssistantServer server;
  late HttpClient client;

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
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
  });

  Future<(int, String)> post({
    String path = AssistantServer.path,
    String method = 'POST',
    String? auth = 'Bearer $_secret',
    String? origin,
    String? host,
    Object? body,
  }) async {
    final request = await client.open(method, '127.0.0.1', server.port!, path);
    if (auth != null) {
      request.headers.set(HttpHeaders.authorizationHeader, auth);
    }
    if (origin != null) request.headers.set('origin', origin);
    if (host != null) request.headers.host = host;
    request.headers.contentType = ContentType.json;
    if (method == 'POST') {
      request.write(
        jsonEncode(
          body ??
              {'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list', 'params': {}},
        ),
      );
    }
    final response = await request.close();
    return (response.statusCode, await response.transform(utf8.decoder).join());
  }

  test('listens on the loopback address only', () async {
    final (status, body) = await post();
    expect(status, 200);
    expect(jsonDecode(body)['result']['tools'], hasLength(8));
  });

  test('a missing or wrong secret is 401', () async {
    expect((await post(auth: null)).$1, 401);
    expect((await post(auth: 'Bearer wrong')).$1, 401);
    expect((await post(auth: _secret)).$1, 401, reason: 'Bearer prefix');
  });

  test('any Origin header (a browser) is 403, even with the secret', () async {
    expect((await post(origin: 'https://evil.example')).$1, 403);
    expect((await post(origin: 'http://127.0.0.1')).$1, 403);
  });

  test('a Host other than loopback (DNS rebinding) is 403', () async {
    expect((await post(host: 'evil.example')).$1, 403);
  });

  test('GET and other paths are refused', () async {
    expect((await post(method: 'GET')).$1, 405);
    expect((await post(method: 'DELETE')).$1, 405);
    expect((await post(path: '/other')).$1, 404);
  });

  test('a body that is not JSON is a 400 parse error', () async {
    final request = await client.post('127.0.0.1', server.port!, '/mcp');
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_secret');
    request.write('{not json');
    final response = await request.close();
    expect(response.statusCode, 400);
    await response.drain<void>();
  });

  test('the first authorised request fires the one-time hook, once', () async {
    var calls = 0;
    final hooked = AssistantServer(
      protocol: server.protocol,
      secret: _secret,
      onFirstAuthorisedRequest: () => calls++,
    );
    await hooked.start(0);
    addTearDown(hooked.stop);
    Future<int> hit(String auth) async {
      final request = await client.post('127.0.0.1', hooked.port!, '/mcp');
      request.headers.set(HttpHeaders.authorizationHeader, auth);
      request.write('{}');
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode;
    }

    expect(await hit('Bearer wrong'), 401);
    expect(calls, 0, reason: 'a refused request must not count');
    await hit('Bearer $_secret');
    await hit('Bearer $_secret');
    expect(calls, 1);
  });

  test('an outdated secret (an old copy in Claude) is reported; a missing '
      'one is not', () async {
    var stale = 0;
    final watched = AssistantServer(
      protocol: server.protocol,
      secret: _secret,
      onWrongSecret: () => stale++,
    );
    await watched.start(0);
    addTearDown(watched.stop);
    Future<void> hit(String? auth) async {
      final request = await client.post('127.0.0.1', watched.port!, '/mcp');
      if (auth != null) {
        request.headers.set(HttpHeaders.authorizationHeader, auth);
      }
      request.write('{}');
      await (await request.close()).drain<void>();
    }

    await hit(null);
    expect(stale, 0);
    await hit('Bearer old-secret');
    expect(stale, 1);
  });

  test('stop closes the port', () async {
    final port = server.port!;
    await server.stop();
    expect(
      () => client.post('127.0.0.1', port, '/mcp').then((r) => r.close()),
      throwsA(isA<SocketException>()),
    );
    await server.start(0); // so tearDown has something to stop
  });
}
