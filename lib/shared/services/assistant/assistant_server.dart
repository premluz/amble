import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'mcp_messages.dart';
import 'mcp_protocol.dart';

/// Amble's MCP endpoint for assistants on this computer: one POST route on
/// the loopback address, open only while the user has connected an
/// assistant in Settings › Claude.
///
/// Every request must pass, in order: the `/mcp` path, POST only, a
/// loopback `Host`, no `Origin` (browsers send one; Claude's helper does
/// not, so any page trying to reach this through DNS rebinding is refused),
/// and the bearer secret. Only then is the body read.
class AssistantServer {
  AssistantServer({
    required this.protocol,
    required this.secret,
    this.onFirstAuthorisedRequest,
    this.onWrongSecret,
  });

  static const path = '/mcp';

  /// Larger bodies are refused unread; real requests are a few hundred bytes.
  static const maxBodyBytes = 64 * 1024;

  final McpProtocol protocol;
  final String secret;

  /// Called once, when the first request carrying the right secret
  /// arrives: Claude has installed the extension, so the bundle file that
  /// carried the secret can be deleted.
  final void Function()? onFirstAuthorisedRequest;
  bool _authorisedOnce = false;

  /// Called when a request carries a secret, but not this one: Claude is
  /// running an older copy of the extension (Settings offers Update).
  final void Function()? onWrongSecret;
  HttpServer? _server;

  int? get port => _server?.port;

  /// Listens on 127.0.0.1:[port]; 0 picks a free port (used by tests).
  /// Throws a [SocketException] when the port is taken, for the caller to
  /// report.
  Future<void> start(int port) async {
    if (_server != null) throw StateError('Assistant server already running.');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    server.listen(_serve);
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _serve(HttpRequest request) async {
    try {
      final refusal = _refusal(request);
      final reply = refusal ?? await _handle(request);
      await _send(request.response, reply);
    } catch (error, stack) {
      developer.log(
        'Assistant request failed',
        name: 'amble.assistant',
        error: error,
        stackTrace: stack,
      );
      await _send(
        request.response,
        McpReply(
          500,
          rpcError(null, Mcp.internalError, 'Amble hit an error: $error'),
        ),
      );
    }
  }

  McpReply? _refusal(HttpRequest request) {
    if (request.uri.path != path) return const McpReply(404);
    if (request.method != 'POST') return const McpReply(405);
    if (!_isLoopbackHost(request.headers.host, request.headers.port)) {
      return const McpReply(403);
    }
    if (request.headers.value('origin') != null) return const McpReply(403);
    final authorization = request.headers.value(
      HttpHeaders.authorizationHeader,
    );
    if (!_authorised(authorization)) {
      if (authorization != null) onWrongSecret?.call();
      return const McpReply(401);
    }
    if (!_authorisedOnce) {
      _authorisedOnce = true;
      onFirstAuthorisedRequest?.call();
    }
    if (request.contentLength > maxBodyBytes) return const McpReply(413);
    return null;
  }

  bool _isLoopbackHost(String? host, int? hostPort) =>
      (host == '127.0.0.1' || host == 'localhost') && hostPort == port;

  bool _authorised(String? header) {
    const prefix = 'Bearer ';
    if (header == null || !header.startsWith(prefix)) return false;
    return _sameText(header.substring(prefix.length), secret);
  }

  /// Compares in time that does not depend on where the texts differ.
  static bool _sameText(String a, String b) {
    final x = utf8.encode(a);
    final y = utf8.encode(b);
    var diff = x.length ^ y.length;
    for (var i = 0; i < x.length && i < y.length; i++) {
      diff |= x[i] ^ y[i];
    }
    return diff == 0;
  }

  Future<McpReply> _handle(HttpRequest request) async {
    final bytes = await request.fold<List<int>>([], (all, chunk) {
      if (all.length + chunk.length > maxBodyBytes) {
        throw const HttpException('Request body too large.');
      }
      return all..addAll(chunk);
    });
    final Object? message;
    try {
      message = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return McpReply(400, rpcError(null, Mcp.parseError, 'Parse error.'));
    }
    final headers = <String, String>{};
    request.headers.forEach((name, values) => headers[name] = values.join(','));
    return protocol.handle(message, headers);
  }

  Future<void> _send(HttpResponse response, McpReply reply) async {
    response.statusCode = reply.status;
    final body = reply.body;
    if (body != null) {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(body));
    }
    await response.close();
  }
}
