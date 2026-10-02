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

  test('DevTrackedCalendarLabelsVisible defaults to hidden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(devTrackedCalendarLabelsVisibleProvider), isFalse);
  });

  test('DevTrackedCalendarLabelsVisible can be enabled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(
      devTrackedCalendarLabelsVisibleProvider.notifier,
    );
    notifier.set(true);
    expect(container.read(devTrackedCalendarLabelsVisibleProvider), isTrue);
  });

  test('DevTrackedPatternDemoData defaults to off and can be enabled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(devTrackedPatternDemoDataProvider), isFalse);

    container.read(devTrackedPatternDemoDataProvider.notifier).set(true);
    expect(container.read(devTrackedPatternDemoDataProvider), isTrue);
  });

  test('DevShowTouches defaults to on and can be disabled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(devShowTouchesProvider.notifier);
    expect(container.read(devShowTouchesProvider), isTrue);

    notifier.set(false);
    expect(container.read(devShowTouchesProvider), isFalse);
  });

  test('DevAccentStrength defaults to full and clamps changes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(devAccentStrengthProvider.notifier);
    expect(container.read(devAccentStrengthProvider), 1.0);

    notifier.set(.35);
    expect(container.read(devAccentStrengthProvider), closeTo(.35, 0.0001));

    notifier.set(2.0);
    expect(container.read(devAccentStrengthProvider), 1.0);

    notifier.set(-1.0);
    expect(container.read(devAccentStrengthProvider), 0.0);
  });
}
