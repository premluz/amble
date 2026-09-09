import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/dev_config.dart';

void main() {
  test('DevTrackedTabInCycle defaults to true', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(devTrackedTabInCycleProvider), isTrue);
  });

  test('set() flips it off then back on', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(devTrackedTabInCycleProvider.notifier);
    notifier.set(false);
    expect(container.read(devTrackedTabInCycleProvider), isFalse);

    notifier.set(true);
    expect(container.read(devTrackedTabInCycleProvider), isTrue);
  });
}
