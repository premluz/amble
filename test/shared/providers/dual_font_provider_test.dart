import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';

void main() {
  late Box<dynamic> box;
  late ProviderContainer container;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_dual_font');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<dynamic>(
      'test_dual_font_${DateTime.now().microsecondsSinceEpoch}',
    );
    container = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(box),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await box.deleteFromDisk();
  });

  test('defaults to true (dual-font on) when nothing is stored', () {
    expect(container.read(dualFontSettingProvider), isTrue);
  });

  test('set updates state and persists through the repository', () async {
    await container.read(dualFontSettingProvider.notifier).set(false);

    expect(container.read(dualFontSettingProvider), isFalse);
    expect(
      container
          .read(preferencesRepositoryProvider)
          .getValue<bool>(PreferenceKeys.dualFontEnabled),
      isFalse,
    );
  });

  test(
    'persists across a simulated relaunch (new container, same box)',
    () async {
      await container.read(dualFontSettingProvider.notifier).set(false);
      container.dispose();

      final relaunched = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(box),
          ),
        ],
      );
      addTearDown(relaunched.dispose);

      expect(relaunched.read(dualFontSettingProvider), isFalse);
    },
  );
}
