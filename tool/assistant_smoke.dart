// Checks a running Amble assistant endpoint end to end, so the manual check
// in docs/WORK_ORDER_CLAUDE_CONNECTION.md is one command:
//
//   dart run tool/assistant_smoke.dart --port 47213 --secret <secret>
//
// It speaks the legacy (initialize) era, like most clients today, then asks
// for this week's free hour-long slots. Exits non-zero on any failure.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final options = _options(args);
  final port = int.parse(options['port'] ?? '47213');
  final secret = options['secret'];
  if (secret == null) {
    stderr.writeln('Usage: --port <port> --secret <secret>');
    exit(64);
  }
  final client = HttpClient();
  final today = DateTime.now();
  final weekEnd = today.add(const Duration(days: 6));
  String day(DateTime d) => d.toIso8601String().substring(0, 10);
  try {
    await _call(client, port, secret, 'initialize', {
      'protocolVersion': '2025-06-18',
      'capabilities': {},
      'clientInfo': {'name': 'amble-smoke', 'version': '1'},
    });
    final tools = await _call(client, port, secret, 'tools/list', {});
    final names = [for (final t in tools['tools'] as List) (t as Map)['name']];
    stdout.writeln('Tools: ${names.join(', ')}');
    final free = await _call(client, port, secret, 'tools/call', {
      'name': 'get_availability',
      'arguments': {'from': day(today), 'to': day(weekEnd), 'min_minutes': 60},
    });
    stdout.writeln(((free['content'] as List).first as Map)['text']);
  } finally {
    client.close();
  }
}

Map<String, String> _options(List<String> args) => {
  for (var i = 0; i + 1 < args.length; i += 2)
    args[i].replaceFirst('--', ''): args[i + 1],
};

Future<Map<String, Object?>> _call(
  HttpClient client,
  int port,
  String secret,
  String method,
  Map<String, Object?> params,
) async {
  final request = await client.post('127.0.0.1', port, '/mcp');
  request.headers
    ..set(HttpHeaders.authorizationHeader, 'Bearer $secret')
    ..set('MCP-Protocol-Version', '2025-06-18')
    ..contentType = ContentType.json;
  request.write(
    jsonEncode({
      'jsonrpc': '2.0',
      'id': method,
      'method': method,
      'params': params,
    }),
  );
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode != HttpStatus.ok) {
    stderr.writeln('$method failed: HTTP ${response.statusCode} $body');
    exit(1);
  }
  final decoded = jsonDecode(body) as Map<String, Object?>;
  if (decoded['error'] != null) {
    stderr.writeln('$method failed: ${decoded['error']}');
    exit(1);
  }
  return decoded['result']! as Map<String, Object?>;
}
