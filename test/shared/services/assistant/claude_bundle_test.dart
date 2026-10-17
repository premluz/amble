import 'dart:convert';
import 'dart:io';

import 'package:amble/shared/services/assistant/assistant_tool.dart';
import 'package:amble/shared/services/assistant/claude_bundle.dart';
import 'package:amble/shared/services/assistant/stored_zip.dart';
import 'package:flutter_test/flutter_test.dart';

final _hasUnzip = File('/usr/bin/unzip').existsSync();

Future<String> _unzipFile(List<int> zip, String name) async {
  final dir = await Directory.systemTemp.createTemp('amble_zip');
  addTearDown(() => dir.delete(recursive: true));
  final file = File('${dir.path}/test.zip')..writeAsBytesSync(zip);
  final result = await Process.run('/usr/bin/unzip', ['-p', file.path, name]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return result.stdout as String;
}

void main() {
  group('storedZip', () {
    test('CRC-32 matches the standard check value', () {
      expect(crc32(utf8.encode('123456789')), 0xcbf43926);
    });

    test('starts with a local header and ends with the directory record', () {
      final zip = storedZip({'a.txt': utf8.encode('hello')});
      expect(zip.sublist(0, 4), [0x50, 0x4b, 0x03, 0x04]);
      final end = zip.length - 22;
      expect(zip.sublist(end, end + 4), [0x50, 0x4b, 0x05, 0x06]);
    });

    test('a standard unzip reads every file back', () async {
      final zip = storedZip({
        'manifest.json': utf8.encode('{"a":1}'),
        'server/index.js': utf8.encode('console.log("é")'),
      });
      expect(await _unzipFile(zip, 'manifest.json'), '{"a":1}');
      expect(await _unzipFile(zip, 'server/index.js'), 'console.log("é")');
    }, skip: !_hasUnzip);
  });

  group('ClaudeBundle', () {
    test('every new file has a newer version, so Claude replaces its copy', () {
      final earlier = ClaudeBundle.versionFor(
        '1.4.0',
        DateTime(2026, 10, 10, 17),
      );
      final later = ClaudeBundle.versionFor(
        '1.4.0',
        DateTime(2026, 10, 10, 17, 1),
      );
      expect(earlier, matches(RegExp(r'^1\.4\.\d+$')));
      int patch(String v) => int.parse(v.split('.').last);
      expect(patch(later), greaterThan(patch(earlier)));
      expect(
        ClaudeBundle.versionFor('2.0.1+7', DateTime(2026)),
        startsWith('2.0.'),
      );
    });

    test(
      'the manifest runs the helper on Node with the connection in env',
      () async {
        final zip = ClaudeBundle.build(
          version: '1.2.3',
          port: 47213,
          secret: 's3cret',
          appBundleId: 'com.panta.panta',
          helperScript: '// helper',
          tools: [
            AssistantTool(
              name: 'get_day',
              description: 'One day.',
              inputSchema: const {'type': 'object'},
              run: (_) async => const AssistantToolResult(summary: ''),
            ),
          ],
        );
        final manifest =
            jsonDecode(await _unzipFile(zip, 'manifest.json')) as Map;
        expect(manifest['manifest_version'], '0.3');
        expect(manifest['display_name'], 'Amble');
        expect(manifest['version'], '1.2.3');
        final server = manifest['server'] as Map;
        expect(server['type'], 'node');
        final config = server['mcp_config'] as Map;
        expect(config['command'], 'node');
        expect(config['args'], [r'${__dirname}/server/index.js']);
        expect(config['env'], {
          'AMBLE_PORT': '47213',
          'AMBLE_SECRET': 's3cret',
          'AMBLE_BUNDLE_ID': 'com.panta.panta',
        });
        expect(
          (manifest['tools'] as List).single,
          containsPair('name', 'get_day'),
        );
        expect(await _unzipFile(zip, 'server/index.js'), '// helper');
      },
      skip: !_hasUnzip,
    );
  });
}
