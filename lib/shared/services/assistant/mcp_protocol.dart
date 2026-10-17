import 'assistant_tool.dart';
import 'assistant_toolbox.dart';
import 'mcp_messages.dart';

/// The MCP JSON-RPC layer over an [AssistantToolbox]: no networking, so it
/// is tested directly. One message in, one [McpReply] out.
class McpProtocol {
  McpProtocol({required this.toolbox, required this.appVersion});

  final AssistantToolbox toolbox;
  final String appVersion;

  /// [headers] holds the request's header values, keyed in lower case.
  Future<McpReply> handle(Object? message, Map<String, String> headers) async {
    if (message is! Map<String, Object?> || message['jsonrpc'] != '2.0') {
      return McpReply(
        400,
        rpcError(null, Mcp.invalidRequest, 'Not JSON-RPC 2.0.'),
      );
    }
    final method = message['method'];
    final id = message['id'];
    if (method is! String) {
      return McpReply(400, rpcError(id, Mcp.invalidRequest, 'No method.'));
    }
    if (!message.containsKey('id')) return const McpReply.accepted();
    final params = message['params'];
    final args = params is Map<String, Object?>
        ? params
        : const <String, Object?>{};
    final meta = args['_meta'];
    final modernVersion = meta is Map ? meta[Mcp.metaVersion] : null;
    if (method == 'initialize') return McpReply(200, _initialize(id, args));
    if (modernVersion != null) {
      final problem = _checkModern(id, method, args, modernVersion, headers);
      if (problem != null) return problem;
      return _dispatch(id, method, args, modern: true);
    }
    final headerVersion =
        headers['mcp-protocol-version'] ?? Mcp.headerlessLegacyVersion;
    if (!Mcp.legacyVersions.contains(headerVersion)) {
      return McpReply(400, _unsupported(id, headerVersion));
    }
    return _dispatch(id, method, args, modern: false);
  }

  Map<String, Object?> _initialize(Object? id, Map<String, Object?> params) {
    final requested = params['protocolVersion'];
    final version = Mcp.legacyVersions.contains(requested)
        ? requested
        : Mcp.legacyVersions.first;
    return rpcResult(id, {
      'protocolVersion': version,
      'capabilities': _capabilities,
      'serverInfo': _serverInfo,
      'instructions': Mcp.instructions,
    });
  }

  McpReply? _checkModern(
    Object? id,
    String method,
    Map<String, Object?> params,
    Object version,
    Map<String, String> headers,
  ) {
    if (!Mcp.modernVersions.contains(version)) {
      return McpReply(400, _unsupported(id, version));
    }
    String? mismatch;
    if (headers['mcp-protocol-version'] != version) {
      mismatch = 'MCP-Protocol-Version';
    } else if (headers['mcp-method'] != method) {
      mismatch = 'Mcp-Method';
    } else if (method == 'tools/call' &&
        decodeHeaderValue(headers['mcp-name'] ?? '') != params['name']) {
      mismatch = 'Mcp-Name';
    }
    if (mismatch == null) return null;
    return McpReply(
      400,
      rpcError(id, Mcp.headerMismatch, 'Header mismatch: $mismatch.'),
    );
  }

  Map<String, Object?> _unsupported(Object? id, Object? requested) =>
      rpcError(id, Mcp.unsupportedVersion, 'Unsupported protocol version', {
        'supported': [...Mcp.modernVersions, ...Mcp.legacyVersions],
        'requested': requested,
      });

  Future<McpReply> _dispatch(
    Object? id,
    String method,
    Map<String, Object?> params, {
    required bool modern,
  }) async {
    final result = switch (method) {
      'ping' => <String, Object?>{},
      'server/discover' when modern => _discover(),
      'tools/list' => {
        'tools': [for (final t in toolbox.available) toolDefinition(t)],
      },
      'tools/call' => await _callTool(id, params),
      _ => null,
    };
    if (result == null) {
      return McpReply(
        modern ? 404 : 200,
        rpcError(id, Mcp.methodNotFound, 'Method not found: $method'),
      );
    }
    if (result.containsKey('error')) return McpReply(200, result);
    return McpReply(200, rpcResult(id, _withEraFields(method, result, modern)));
  }

  /// What the 2026-07-28 revision adds to a result: `resultType`, and the
  /// caching hints it requires on cacheable list results.
  Map<String, Object?> _withEraFields(
    String method,
    Map<String, Object?> result,
    bool modern,
  ) => {
    if (modern) 'resultType': 'complete',
    ...result,
    if (modern && _cacheable.contains(method)) ...{
      'ttlMs': Mcp.listTtlMs,
      'cacheScope': Mcp.cacheScope,
    },
  };

  static const _cacheable = {'tools/list', 'server/discover'};

  Map<String, Object?> _discover() => {
    'supportedVersions': [...Mcp.modernVersions, ...Mcp.legacyVersions],
    'capabilities': _capabilities,
    '_meta': {Mcp.metaServerInfo: _serverInfo},
    'instructions': Mcp.instructions,
  };

  /// A whole JSON-RPC error message when the call itself is malformed, or
  /// the tool's result. An unknown tool is a protocol error, per the spec;
  /// a refused or failed call is a tool result with `isError`, so the
  /// assistant can read the reason and recover.
  Future<Map<String, Object?>> _callTool(
    Object? id,
    Map<String, Object?> params,
  ) async {
    final name = params['name'];
    final arguments = params['arguments'] ?? const <String, Object?>{};
    if (name is! String || arguments is! Map<String, Object?>) {
      return rpcError(
        id,
        Mcp.invalidParams,
        'tools/call needs a name and arguments.',
      );
    }
    if (!toolbox.knows(name)) {
      return rpcError(id, Mcp.invalidParams, 'Unknown tool: $name');
    }
    final AssistantToolResult result = await toolbox.call(name, arguments);
    return toolCallResult(result);
  }

  Map<String, Object?> get _serverInfo => {
    'name': Mcp.serverName,
    'version': appVersion,
  };

  static const _capabilities = {
    'tools': {'listChanged': false},
  };
}
