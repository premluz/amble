import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/providers/assistant_connection.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/services/assistant/assistant_tool.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

void main() {
  late Box<dynamic> box;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_assistant_connection');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    box = await Hive.openBox<dynamic>(
      'assistant_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() => box.deleteFromDisk());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(box),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('off and read-only out of the box, on the default port', () {
    final state = container().read(assistantConnectionProvider);
    expect(state.connected, isFalse);
    expect(state.permission, AssistantPermission.read);
    expect(state.port, AssistantLimits.defaultPort);
  });

  test(
    'connect saves the choice and a secret that survives a relaunch',
    () async {
      final first = container();
      await first
          .read(assistantConnectionProvider.notifier)
          .connect(AssistantPermission.readWrite);
      final secret = first.read(assistantConnectionProvider).secret;
      expect(secret.length, greaterThanOrEqualTo(40));

      final relaunched = container().read(assistantConnectionProvider);
      expect(relaunched.connected, isTrue);
      expect(relaunched.permission, AssistantPermission.readWrite);
      expect(relaunched.secret, secret);
    },
  );

  test('disconnect turns it off and replaces the secret', () async {
    final c = container();
    final notifier = c.read(assistantConnectionProvider.notifier);
    await notifier.connect(AssistantPermission.read);
    final before = c.read(assistantConnectionProvider).secret;
    await notifier.disconnect();
    final after = c.read(assistantConnectionProvider);
    expect(after.connected, isFalse);
    expect(after.secret, isNot(before));
  });

  test('secrets are random', () {
    expect(newAssistantSecret(), isNot(newAssistantSecret()));
  });
}
