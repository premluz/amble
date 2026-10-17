import 'dart:io';

import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/providers/assistant_connection.dart';
import 'package:amble/shared/providers/claude_connector.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';
import 'package:amble/shared/services/assistant/assistant_tool.dart';
import 'package:amble/shared/services/assistant/claude_bundle.dart';
import 'package:amble/shared/services/claude_connect_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _FakeClaude extends ClaudeConnectService {
  _FakeClaude({required this.installed, required this.downloads});

  final bool installed;
  final String downloads;
  final opened = <String>[];

  @override
  Future<bool> isClaudeInstalled() async => installed;

  @override
  Future<String?> downloadsDirectory() async => downloads;

  @override
  Future<bool> openInClaude(String path) async {
    opened.add(path);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Box<dynamic> box;
  late Directory downloads;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_claude_connector');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    box = await Hive.openBox<dynamic>(
      'claude_${DateTime.now().microsecondsSinceEpoch}',
    );
    downloads = await Directory.systemTemp.createTemp('amble_downloads');
    PackageInfo.setMockInitialValues(
      appName: 'Amble',
      packageName: 'com.panta.panta',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await downloads.delete(recursive: true);
  });

  ProviderContainer container(_FakeClaude claude) {
    final c = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(box),
        ),
        claudeConnectServiceProvider.overrideWithValue(claude),
        claudeHelperScriptProvider.overrideWithValue(() async => '// helper'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('Claude missing: says so and leaves access off', () async {
    final claude = _FakeClaude(installed: false, downloads: downloads.path);
    final c = container(claude);
    final outcome = await c
        .read(claudeConnectorProvider)
        .connect(AssistantPermission.read);
    expect(outcome, ClaudeConnectOutcome.claudeMissing);
    expect(c.read(assistantConnectionProvider).connected, isFalse);
    expect(claude.opened, isEmpty);
  });

  test('connect turns access on, writes the extension and opens it in '
      'Claude; the file goes once Claude has connected', () async {
    final claude = _FakeClaude(installed: true, downloads: downloads.path);
    final c = container(claude);
    final connector = c.read(claudeConnectorProvider);

    final outcome = await connector.connect(AssistantPermission.readWrite);

    expect(outcome, ClaudeConnectOutcome.opened);
    final state = c.read(assistantConnectionProvider);
    expect(state.connected, isTrue);
    expect(state.permission, AssistantPermission.readWrite);
    final file = File('${downloads.path}/${ClaudeBundle.fileName}');
    expect(claude.opened, [file.path]);
    expect(file.existsSync(), isTrue);
    expect(box.get(PreferenceKeys.assistantBundlePath), file.path);

    await connector.removeBundleFile();
    expect(file.existsSync(), isFalse);
    expect(box.get(PreferenceKeys.assistantBundlePath), isNull);
  });

  test('disconnect turns access off, replaces the secret and removes the '
      'file', () async {
    final claude = _FakeClaude(installed: true, downloads: downloads.path);
    final c = container(claude);
    final connector = c.read(claudeConnectorProvider);
    await connector.connect(AssistantPermission.read);
    final secret = c.read(assistantConnectionProvider).secret;

    await connector.disconnect();

    expect(c.read(assistantConnectionProvider).connected, isFalse);
    expect(c.read(assistantConnectionProvider).secret, isNot(secret));
    expect(
      File('${downloads.path}/${ClaudeBundle.fileName}').existsSync(),
      isFalse,
    );
  });
}
