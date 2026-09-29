import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';

import '../../support/memory_zone_repositories.dart';

void main() {
  test(
    'defaults to visible and persists across a new provider container',
    () async {
      final preferences = MemoryPreferencesRepository();
      final container = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(showZonesSettingProvider), isTrue);

      await container.read(showZonesSettingProvider.notifier).set(false);
      expect(preferences.getValue<bool>(PreferenceKeys.showZones), isFalse);

      final relaunched = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(relaunched.dispose);

      expect(relaunched.read(showZonesSettingProvider), isFalse);
    },
  );
}
