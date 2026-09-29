import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/voice_mode_tokens.dart';
import 'package:amble/core/widgets/app_voice_waveform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bars = 24;
const _delay = .12;

void main() {
  test('keys rise in order, left to right: an earlier key is up while a '
      'later one is still waiting its turn', () {
    const t = _delay + 5 * VoiceModeTokens.keyStaggerSeconds;
    expect(waveformKeyScale(t, 0, _delay, _bars), greaterThan(0));
    expect(waveformKeyScale(t, 10, _delay, _bars), 0);
    expect(waveformKeyScale(_delay, 0, _delay, _bars), 0, reason: 'delay');
  });

  test('each key springs up past its height, back under, then exactly '
      'its height — bouncy, like a piano key', () {
    final samples = [
      for (var ms = 0; ms <= 1200; ms += 8)
        waveformKeyScale(ms / 1000, 3, _delay, _bars),
    ];
    final peak = samples.reduce((a, b) => a > b ? a : b);
    expect(peak, greaterThan(1.05), reason: 'larger');
    expect(
      samples.sublist(samples.indexOf(peak)).reduce((a, b) => a < b ? a : b),
      lessThan(1),
      reason: 'then smaller',
    );
    expect(
      waveformKeyScale(waveformKeysSeconds(_delay, _bars), 3, _delay, _bars),
      1,
      reason: 'then actual',
    );
  });

  testWidgets('without an entrance delay the bars are simply there, and '
      'with one the entrance plays once and ends', (tester) async {
    Widget host(Duration? delay) => MaterialApp(
      home: Scaffold(
        body: AppVoiceWaveform(
          key: ValueKey(delay),
          theme: AmbleTheme.dark,
          level: .5,
          entranceDelay: delay,
        ),
      ),
    );
    await tester.pumpWidget(host(null));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(host(VoiceModeTokens.keysDelay));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
