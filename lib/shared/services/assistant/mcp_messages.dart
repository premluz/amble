import 'dart:convert';

import 'assistant_tool.dart';

/// Versions and error codes from the MCP specification, checked against
/// revision 2026-07-28 on 2026-10-10 (see docs/DECISIONS.md). Amble is a
/// "dual-era" server: modern clients send per-request metadata, legacy ones
/// open with `initialize`, and both are served on the same endpoint.
abstract final class Mcp {
  static const modernVersions = ['2026-07-28'];
  static const legacyVersions = ['2025-11-25', '2025-06-18', '2025-03-26'];

  /// A legacy request without `MCP-Protocol-Version` is treated as this,
  /// as the specification allows.
  static const headerlessLegacyVersion = '2025-03-26';

  static const metaVersion = 'io.modelcontextprotocol/protocolVersion';
  static const metaServerInfo = 'io.modelcontextprotocol/serverInfo';

  static const parseError = -32700;
  static const methodNotFound = -32601;
  static const invalidParams = -32602;
  static const internalError = -32603;
  static const invalidRequest = -32600;
  static const headerMismatch = -32020;
  static const unsupportedVersion = -32022;

  /// Caching hints the 2026-07-28 spec requires on `tools/list` and
  /// `server/discover` results (server/utilities/caching). The tool list
  /// changes the moment the person changes Claude's permission in Settings,
  /// so it is never cached (0 ms), and it describes this person's access,
  /// so it is private.
  static const listTtlMs = 0;
  static const cacheScope = 'private';

  static const serverName = 'Amble';
  static const instructions =
      'Amble is the person\'s day planner. Times are local and written '
      'YYYY-MM-DDTHH:MM. Look before changing: use get_availability or '
      'get_day, propose times, and add or move tasks only after the person '
      'agrees.';
}

/// What to send back for one POST: an HTTP status and, unless it is a bare
/// acknowledgement, a JSON body.
class McpReply {
  const McpReply(this.status, [this.body]);

  const McpReply.accepted() : status = 202, body = null;

  final int status;
  final Map<String, Object?>? body;
}

Map<String, Object?> rpcResult(Object? id, Map<String, Object?> result) => {
  'jsonrpc': '2.0',
  'id': id,
  'result': result,
};

Map<String, Object?> rpcError(
  Object? id,
  int code,
  String message, [
  Object? data,
]) => {
  'jsonrpc': '2.0',
  'id': id,
  'error': {'code': code, 'message': message, 'data': ?data},
};

/// A tool as `tools/list` describes it. Read tools are marked read-only and
/// the writes as non-destructive (they add or move; nothing is deleted).
Map<String, Object?> toolDefinition(AssistantTool tool) => {
  'name': tool.name,
  'description': tool.description,
  'inputSchema': tool.inputSchema,
  'annotations': {
    'readOnlyHint': !tool.writes,
    'destructiveHint': false,
    'openWorldHint': false,
  },
};

/// A tool's outcome in the shape `tools/call` returns: the summary and the
/// data as text (for clients that only read text), plus the data as
/// `structuredContent` when it is an object.
Map<String, Object?> toolCallResult(AssistantToolResult result) {
  final data = result.data;
  final text = data == null
      ? result.summary
      : '${result.summary}\n${jsonEncode(data)}';
  return {
    'content': [
      {'type': 'text', 'text': text},
    ],
    if (data is Map<String, Object?>) 'structuredContent': data,
    'isError': result.isError,
  };
}

/// Decodes the `=?base64?...?=` form a client uses for header values that
/// are not plain ASCII.
String decodeHeaderValue(String value) {
  const prefix = '=?base64?';
  const suffix = '?=';
  if (!value.startsWith(prefix) || !value.endsWith(suffix)) return value;
  final encoded = value.substring(prefix.length, value.length - suffix.length);
  return utf8.decode(base64.decode(encoded));
}
