import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/app_theme_mode.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';

void main() {
  late Box<dynamic> box;
  late ProviderContainer container;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_theme_mode');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<dynamic>(
      'test_theme_${DateTime.now().microsecondsSinceEpoch}',
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

  test('defaults to system when nothing is stored', () {
    expect(container.read(themeModeSettingProvider), AppThemeMode.system);
  });

  test('set updates state and persists through the repository', () async {
    await container
        .read(themeModeSettingProvider.notifier)
        .set(AppThemeMode.dark);

    expect(container.read(themeModeSettingProvider), AppThemeMode.dark);
    expect(
      container
          .read(preferencesRepositoryProvider)
          .getValue<AppThemeMode>(PreferenceKeys.themeMode),
      AppThemeMode.dark,
    );
  });

  test('a stored value is read back on a fresh container — it survives a '
      'relaunch', () async {
    await container
        .read(themeModeSettingProvider.notifier)
        .set(AppThemeMode.light);
    container.dispose();

    // A new container over the same box stands in for the next app launch.
    final relaunched = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(box),
        ),
      ],
    );
    addTearDown(relaunched.dispose);

    expect(relaunched.read(themeModeSettingProvider), AppThemeMode.light);
  });

  test('every mode round-trips', () async {
    for (final mode in AppThemeMode.values) {
      await container.read(themeModeSettingProvider.notifier).set(mode);
      expect(container.read(themeModeSettingProvider), mode);
    }
  });

  group('toFlutterThemeMode', () {
    test('maps each stored mode onto the framework enum', () {
      expect(toFlutterThemeMode(AppThemeMode.system), ThemeMode.system);
      expect(toFlutterThemeMode(AppThemeMode.light), ThemeMode.light);
      expect(toFlutterThemeMode(AppThemeMode.dark), ThemeMode.dark);
    });
  });
}
