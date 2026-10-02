import 'package:amble/core/dev_config.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/timeline_pinch_zoom.dart';
import 'package:amble/features/timeline/timeline_simulated_pinch.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/preferences_repository.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_zone_repositories.dart';

final _dots = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is SimulatedPinchPainter,
);

Future<(ProviderContainer, ScrollController)> _pump(
  WidgetTester tester, {
  double scale = 1.5,
  Widget? extra,
  bool dark = false,
}) async {
  final repo = MemoryPreferencesRepository();
  await repo.setValue(PreferenceKeys.timelinePixelsPerMinute, scale);
  final container = ProviderContainer(
    overrides: [preferencesRepositoryProvider.overrideWithValue(repo)],
  );
  final scroll = ScrollController(initialScrollOffset: 500);
  addTearDown(container.dispose);
  addTearDown(scroll.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(
          extensions: [dark ? AmbleTheme.dark : AmbleTheme.light],
        ),
        home: Column(
          children: [
            ?extra,
            Expanded(child: _viewport(scroll)),
          ],
        ),
      ),
    ),
  );
  return (container, scroll);
}

Widget _viewport(ScrollController scroll) => Consumer(
  builder: (context, ref, _) => TimelinePinchZoom(
    scrollController: scroll,
    child: SingleChildScrollView(
      controller: scroll,
      padding: const EdgeInsets.only(top: TimelineScrollTokens.topClearance),
      child: SizedBox(
        width: double.infinity,
        height:
            ref.watch(timelinePixelsPerMinuteSettingProvider) *
            Duration.minutesPerDay,
      ),
    ),
  ),
);

Future<void> _hover(WidgetTester tester, Offset point) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: point);
  await mouse.moveTo(point + const Offset(1, 0));
  await mouse.moveTo(point);
}

SimulatedPinchPainter _painter(WidgetTester tester) {
  final painter = tester.widget<CustomPaint>(_dots).painter;
  if (painter is! SimulatedPinchPainter) {
    throw StateError('Expected the keyboard pinch painter, got $painter');
  }
  return painter;
}

void main() {
  for (final sample in [
    (1.5, const Offset(200, 200), false),
    (3.0, const Offset(350, 380), true),
  ]) {
    testWidgets('1 spreads dots at the cursor and anchors zoom: $sample', (
      tester,
    ) async {
      final (container, scroll) = await _pump(
        tester,
        scale: sample.$1,
        dark: sample.$3,
      );
      await _hover(tester, sample.$2);
      expect(_dots, findsNothing);
      final before = scroll.offset;
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final first = _painter(tester).centers;
      expect((first.first + first.last) / 2, sample.$2);
      await tester.pump(const Duration(milliseconds: 100));
      final next = _painter(tester).centers;
      expect(
        (next.first - next.last).distance,
        greaterThan((first.first - first.last).distance),
      );
      await tester.pumpAndSettle();
      expect(_dots, findsNothing);
      final scale = container.read(timelinePixelsPerMinuteSettingProvider);
      expect(scale, sample.$1 * SimulatedPinch.zoomFactor);
      final timeBefore =
          (before + sample.$2.dy - TimelineScrollTokens.topClearance) /
          sample.$1;
      final timeAfter =
          (scroll.offset + sample.$2.dy - TimelineScrollTokens.topClearance) /
          scale;
      expect(timeAfter, closeTo(timeBefore, .001));
    });
  }

  testWidgets('2 brings dots together and zooms out', (tester) async {
    final (container, _) = await _pump(tester, scale: 3);
    await _hover(tester, const Offset(300, 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final first = _painter(tester).centers;
    await tester.pump(const Duration(milliseconds: 100));
    final next = _painter(tester).centers;
    expect(
      (next.first - next.last).distance,
      lessThan((first.first - first.last).distance),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(timelinePixelsPerMinuteSettingProvider),
      3 / SimulatedPinch.zoomFactor,
    );
    expect(_dots, findsNothing);
  });

  testWidgets('disabled gate ignores keys and cancels an active animation', (
    tester,
  ) async {
    final (container, _) = await _pump(tester);
    await _hover(tester, const Offset(300, 300));
    final gate = container.read(devShowTouchesProvider.notifier);
    gate.set(false);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pumpAndSettle();
    expect(_dots, findsNothing);
    expect(container.read(timelinePixelsPerMinuteSettingProvider), 1.5);
    gate.set(true);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_dots, findsOneWidget);
    gate.set(false);
    await tester.pumpAndSettle();
    expect(_dots, findsNothing);
  });

  testWidgets('typing 1 and 2 in a field does not pinch', (tester) async {
    final (container, _) = await _pump(
      tester,
      extra: const Material(child: TextField()),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await _hover(tester, const Offset(300, 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_dots, findsNothing);
    expect(container.read(timelinePixelsPerMinuteSettingProvider), 1.5);
  });
}
