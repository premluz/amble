import 'dart:io';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/assistant/assistant_undo_toaster.dart';
import 'package:amble/features/assistant/claude_settings_screen.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/providers/assistant_connection.dart';
import 'package:amble/shared/providers/assistant_providers.dart';
import 'package:amble/shared/providers/claude_connector.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/services/assistant/assistant_tool.dart';
import 'package:amble/shared/services/claude_connect_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _FakeClaude extends ClaudeConnectService {
  _FakeClaude(this.downloads);

  final String downloads;
  bool installed = true;
  int opened = 0;
  int downloadPage = 0;

  @override
  Future<bool> isClaudeInstalled() async => installed;

  @override
  Future<String?> downloadsDirectory() async => downloads;

  @override
  Future<bool> openInClaude(String path) async {
    opened++;
    return true;
  }

  @override
  Future<bool> openClaudeDownloadPage() async {
    downloadPage++;
    return true;
  }
}

void main() {
  late Box<dynamic> box;
  late Directory downloads;
  late _FakeClaude claude;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_claude_screen');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    box = await Hive.openBox<dynamic>(
      'claude_screen_${DateTime.now().microsecondsSinceEpoch}',
    );
    downloads = await Directory.systemTemp.createTemp('amble_screen');
    claude = _FakeClaude(downloads.path);
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

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget home, {
    bool supported = true,
  }) async {
    final container = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(box),
        ),
        claudeConnectServiceProvider.overrideWithValue(claude),
        claudeHelperScriptProvider.overrideWithValue(() async => '// helper'),
        assistantServerSupportedProvider.overrideWithValue(supported),
        assistantServerProvider.overrideWith(
          (ref) async => const AssistantServerRunning(1),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(extensions: [AmbleTheme.light]),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(text));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('not connected: plain words, read-only chosen, one button', (
    tester,
  ) async {
    await pump(tester, const ClaudeSettingsScreen());
    expect(find.text('Connect to Claude'), findsOneWidget);
    expect(find.text('See my plan'), findsOneWidget);
    expect(
      find.text('Claude can read your tasks, zones and free time.'),
      findsOneWidget,
    );
    for (final word in ['MCP', 'localhost', 'token', 'server', 'port']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
  });

  testWidgets('Connect opens Claude and waits for Install; Claude reaching '
      'Amble moves on by itself', (tester) async {
    final c = await pump(tester, const ClaudeSettingsScreen());
    await tapText(tester, 'See and update my plan');
    await tapText(tester, 'Connect to Claude');

    expect(claude.opened, 1);
    expect(find.text('Almost there'), findsOneWidget);
    expect(
      c.read(assistantConnectionProvider).permission,
      AssistantPermission.readWrite,
    );

    await tester.runAsync(
      () => c.read(claudeConnectorProvider).claudeConnected(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Connected to Claude'), findsOneWidget);
    expect(find.text('Find me four one-hour slots this week'), findsOneWidget);
  });

  testWidgets('Claude missing: Get Claude, then retry', (tester) async {
    claude.installed = false;
    await pump(tester, const ClaudeSettingsScreen());
    await tapText(tester, 'Connect to Claude');
    expect(find.text("Claude's desktop app is needed"), findsOneWidget);
    await tapText(tester, 'Get Claude');
    expect(claude.downloadPage, 1);

    claude.installed = true;
    await tapText(tester, "I've installed it");
    expect(find.text('Almost there'), findsOneWidget);
  });

  testWidgets('an old copy in Claude: Update rebuilds and reopens', (
    tester,
  ) async {
    final c = await pump(tester, const ClaudeSettingsScreen());
    await tapText(tester, 'Connect to Claude');
    await tester.runAsync(
      () => c.read(claudeConnectorProvider).claudeConnected(),
    );
    c.read(claudeExtensionStaleProvider.notifier).set(true);
    await tester.pumpAndSettle();

    expect(find.text('Claude has an old copy of Amble'), findsOneWidget);
    await tapText(tester, 'Update Claude');
    expect(claude.opened, 2);
    expect(c.read(claudeExtensionStaleProvider), isFalse);
  });

  testWidgets('Disconnect turns it off and returns to the start', (
    tester,
  ) async {
    final c = await pump(tester, const ClaudeSettingsScreen());
    await tapText(tester, 'Connect to Claude');
    await tester.runAsync(
      () => c.read(claudeConnectorProvider).claudeConnected(),
    );
    await tester.pumpAndSettle();
    final secret = c.read(assistantConnectionProvider).secret;

    await tapText(tester, 'Disconnect');

    expect(c.read(assistantConnectionProvider).connected, isFalse);
    expect(c.read(assistantConnectionProvider).secret, isNot(secret));
    expect(find.text('Connect to Claude'), findsOneWidget);
  });

  testWidgets('an assistant change shows an Undo toast that undoes it', (
    tester,
  ) async {
    final c = await pump(
      tester,
      const AssistantUndoToaster(child: SizedBox.expand()),
    );
    var undone = 0;
    c
        .read(assistantActivityProvider)
        .record(
          'Added "Deep work", Tue 13 Oct, 10:00.',
          undo: () async {
            undone++;
          },
        );
    await tester.pump();
    expect(find.textContaining('Claude: Added "Deep work"'), findsOneWidget);
    await tapText(tester, 'Undo');
    expect(undone, 1);
  });

  testWidgets('the Settings row is hidden where Claude cannot connect', (
    tester,
  ) async {
    await pump(tester, const ClaudeSettingsLink(), supported: false);
    expect(find.text('Claude'), findsNothing);
  });

  testWidgets('and shown on the Mac', (tester) async {
    await pump(tester, const ClaudeSettingsLink());
    expect(find.text('Claude'), findsOneWidget);
  });
}
