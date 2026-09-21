import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_voice_waveform.dart';

void main() {
  final theme = AmbleTheme.light;

  Future<void> pump(
    WidgetTester tester, {
    double level = 0.5,
    bool isActive = true,
    double width = 320,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: AppVoiceWaveform(
              theme: theme,
              level: level,
              isActive: isActive,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders without overflow at phone width', (tester) async {
    await pump(tester, width: 320);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow at a very narrow width', (
    tester,
  ) async {
    await pump(tester, width: 120);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepts an out-of-range level without throwing — a raw '
      'platform sound-level value is not pre-clamped by callers', (
    tester,
  ) async {
    await pump(tester, level: 3.4);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    await pump(tester, level: -1.2);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the animation keeps ticking across many frames without '
      'ever throwing or settling into an error state', (tester) async {
    await pump(tester);

    // Several frames spanning more than one full loop of the widget's own
    // 2s AnimationController.repeat() — a static end state or a bad
    // shouldRepaint would surface as an exception somewhere in this
    // stretch, not necessarily on the very first frame.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('isActive: false does not throw and does not schedule a '
      'perpetual repaint loop assertion failure', (tester) async {
    await pump(tester, isActive: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
