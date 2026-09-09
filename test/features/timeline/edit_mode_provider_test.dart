import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/edit_mode_provider.dart';

void main() {
  test('starts false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(editModeEnabledProvider), isFalse);
  });

  test('toggle flips true then false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(editModeEnabledProvider.notifier);
    notifier.toggle();
    expect(container.read(editModeEnabledProvider), isTrue);

    notifier.toggle();
    expect(container.read(editModeEnabledProvider), isFalse);
  });

  test('a fresh container always starts false — nothing persists between '
      'instances, matching the "ephemeral, not persisted" contract', () {
    final first = ProviderContainer();
    first.read(editModeEnabledProvider.notifier).toggle();
    expect(first.read(editModeEnabledProvider), isTrue);
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(second.read(editModeEnabledProvider), isFalse);
  });
}
