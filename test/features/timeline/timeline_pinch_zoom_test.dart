import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/timeline_pinch_zoom.dart';
import 'package:amble/shared/providers/preferences_providers.dart';

import '../../support/memory_zone_repositories.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(
          MemoryPreferencesRepository(),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: TimelinePinchZoom(child: SizedBox.expand()),
          ),
        ),
      ),
    );
  }

  double scale() =>
      container.read(timelinePixelsPerMinuteSettingProvider);

  testWidgets('two fingers moving apart increases the scale', (tester) async {
    await pump(tester);
    expect(scale(), 1.5);

    final gesture1 = await tester.createGesture();
    final gesture2 = await tester.createGesture();
    await gesture1.down(const Offset(150, 300));
    await gesture2.down(const Offset(250, 300));
    await tester.pump();

    // Distance was 100, now 200 — doubles the baseline scale (1.5 -> 3.0).
    await gesture1.moveTo(const Offset(100, 300));
    await gesture2.moveTo(const Offset(300, 300));
    await tester.pump();

    expect(scale(), 3.0);

    await gesture1.up();
    await gesture2.up();
  });

  testWidgets('two fingers moving together decreases the scale', (
    tester,
  ) async {
    await pump(tester);

    final gesture1 = await tester.createGesture();
    final gesture2 = await tester.createGesture();
    await gesture1.down(const Offset(100, 300));
    await gesture2.down(const Offset(300, 300));
    await tester.pump();

    // Distance was 200, now 100 — halves the baseline scale (1.5 -> 0.75),
    // clamped up to the 1.0 minimum.
    await gesture1.moveTo(const Offset(150, 300));
    await gesture2.moveTo(const Offset(250, 300));
    await tester.pump();

    expect(scale(), 1.0);

    await gesture1.up();
    await gesture2.up();
  });

  testWidgets('the result is clamped to the 1.0-4.0 range', (tester) async {
    await pump(tester);

    final gesture1 = await tester.createGesture();
    final gesture2 = await tester.createGesture();
    await gesture1.down(const Offset(190, 300));
    await gesture2.down(const Offset(210, 300));
    await tester.pump();

    // Distance was 20, now 2000 — would be 150x the baseline without the
    // clamp.
    await gesture1.moveTo(const Offset(-800, 300));
    await gesture2.moveTo(const Offset(1200, 300));
    await tester.pump();

    expect(scale(), 4.0);

    await gesture1.up();
    await gesture2.up();
  });

  testWidgets('a single finger never changes the scale, no matter how far '
      'it moves', (tester) async {
    await pump(tester);

    final gesture = await tester.createGesture();
    await gesture.down(const Offset(100, 100));
    await tester.pump();
    await gesture.moveTo(const Offset(300, 300));
    await tester.pump();

    expect(scale(), 1.5);

    await gesture.up();
  });

  testWidgets('a third finger joining rebases rather than continuing the '
      'old pinch', (tester) async {
    await pump(tester);

    final gesture1 = await tester.createGesture();
    final gesture2 = await tester.createGesture();
    await gesture1.down(const Offset(150, 300));
    await gesture2.down(const Offset(250, 300));
    await tester.pump();
    await gesture1.moveTo(const Offset(100, 300));
    await gesture2.moveTo(const Offset(300, 300));
    await tester.pump();
    expect(scale(), 3.0);

    // A third finger joins — no baseline for 3 pointers, so no more scale
    // changes happen while it's down.
    final gesture3 = await tester.createGesture();
    await gesture3.down(const Offset(50, 50));
    await tester.pump();
    await gesture1.moveTo(const Offset(50, 300));
    await gesture2.moveTo(const Offset(350, 300));
    await tester.pump();

    expect(scale(), 3.0);

    await gesture1.up();
    await gesture2.up();
    await gesture3.up();
  });

  testWidgets('a single-finger tap still reaches the child underneath — the '
      'gesture is passive and never intercepts a one-finger interaction', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: TimelinePinchZoom(
              child: GestureDetector(
                onTap: () => tapped = true,
                child: Container(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Container));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
