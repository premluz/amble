import 'dart:convert';
import 'dart:typed_data';

import 'assistant_tool.dart';
import 'stored_zip.dart';

/// Builds the one-click Claude extension (`.mcpb`, MCP Bundle manifest 0.3,
/// checked 2026-10-10): a manifest plus the small Node helper that pipes
/// Claude's messages to Amble's local endpoint. Claude Desktop runs `node`
/// servers on its own built-in Node, so the person installs nothing else.
///
/// The connection details are written into the manifest's `env`, so the
/// person never sees or copies them. The file therefore holds the secret:
/// the caller deletes it once Claude has connected (see
/// `AssistantServer.onFirstAuthorisedRequest`).
abstract final class ClaudeBundle {
  static const fileName = 'Amble.mcpb';
  static const helperAsset = 'assets/claude/amble-mcp.js';
  static const _helperPath = 'server/index.js';

  /// The extension's version: the app's major.minor, then the minute it was
  /// built. Claude treats an extension with an unchanged name and version
  /// as already installed and keeps the old copy, with the old secret
  /// (seen 2026-10-10), so every new file must look newer than the last.
  static String versionFor(String appVersion, DateTime builtAt) {
    final parts = appVersion.split(RegExp(r'[.+-]'));
    final major = int.tryParse(parts.first) ?? 0;
    final minor = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final minute =
        builtAt.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;
    return '$major.$minor.$minute';
  }

  static Uint8List build({
    required String version,
    required int port,
    required String secret,
    required String appBundleId,
    required String helperScript,
    required List<AssistantTool> tools,
  }) {
    final manifest = {
      'manifest_version': '0.3',
      'name': 'amble',
      'display_name': 'Amble',
      'version': version,
      'description':
          'See your Amble plan, find free time and, if you allow '
          'it, add and move tasks.',
      'long_description':
          'Ask Claude about your day in Amble: "Find me four one-hour slots '
          'this week", "What\'s important today?". Everything stays on this '
          'Mac. Amble decides what Claude may do: Settings › Claude.',
      'author': {'name': 'Amble'},
      'server': {
        'type': 'node',
        'entry_point': _helperPath,
        'mcp_config': {
          'command': 'node',
          'args': ['\${__dirname}/$_helperPath'],
          'env': {
            'AMBLE_PORT': '$port',
            'AMBLE_SECRET': secret,
            'AMBLE_BUNDLE_ID': appBundleId,
          },
        },
      },
      'tools': [
        for (final tool in tools)
          {'name': tool.name, 'description': tool.description},
      ],
      'compatibility': {
        'platforms': ['darwin'],
      },
    };
    return storedZip({
      'manifest.json': utf8.encode(
        const JsonEncoder.withIndent('  ').convert(manifest),
      ),
      _helperPath: utf8.encode(helperScript),
    });
  }
}
