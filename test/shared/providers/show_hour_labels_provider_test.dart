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
    Hive.init('./.dart_tool/test_hive_show_hour_labels');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<dynamic>(
      'test_show_hour_labels_${DateTime.now().microsecondsSinceEpoch}',
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

  test('defaults to true when nothing is stored', () {
    expect(container.read(showHourLabelsSettingProvider), isTrue);
  });

  test('set updates state and persists through the repository', () async {
    await container.read(showHourLabelsSettingProvider.notifier).set(false);

    expect(container.read(showHourLabelsSettingProvider), isFalse);
    expect(
      container
          .read(preferencesRepositoryProvider)
          .getValue<bool>(PreferenceKeys.showHourLabels),
      isFalse,
    );
  });

  test(
    'persists across a simulated relaunch (new container, same box)',
    () async {
      await container.read(showHourLabelsSettingProvider.notifier).set(false);
      container.dispose();

      final relaunched = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(box),
          ),
        ],
      );
      addTearDown(relaunched.dispose);

      expect(relaunched.read(showHourLabelsSettingProvider), isFalse);
    },
  );
}
