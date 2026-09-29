import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/voice_mode_tokens.dart';
import 'package:amble/core/widgets/app_voice_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _width = 200;
const _height = 400;
final _theme = AmbleTheme.dark;

Future<ByteData> _render(
  WidgetTester tester, {
  required double scrim,
  required double rise,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      // Still, so the drift doesn't keep the test's frames running.
      data: const MediaQueryData(disableAnimations: true),
      child: AppVoiceGlow(
        theme: _theme,
        scrim: AlwaysStoppedAnimation(scrim),
        rise: AlwaysStoppedAnimation(rise),
      ),
    ),
  );
  final painter = tester
      .widget<CustomPaint>(find.byKey(const ValueKey('voice-glow')))
      .painter!;
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    painter.paint(
      Canvas(recorder),
      Size(_width.toDouble(), _height.toDouble()),
    );
    final image = await recorder.endRecording().toImage(_width, _height);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data;
  });
  if (bytes == null) throw StateError('Glow pixel capture failed');
  return bytes;
}

List<int> _rgba(ByteData pixels, double x, double y) {
  final i =
      ((y * (_height - 1)).round() * _width + (x * (_width - 1)).round()) * 4;
  return [for (var c = 0; c < 4; c++) pixels.getUint8(i + c)];
}

List<int> get _base => [
  (_theme.colorSurfaceBase.r * 255).round(),
  (_theme.colorSurfaceBase.g * 255).round(),
  (_theme.colorSurfaceBase.b * 255).round(),
  255,
];

int _distance(List<int> a, List<int> b) {
  var sum = 0;
  for (var c = 0; c < 3; c++) {
    sum += (a[c] - b[c]).abs();
  }
  return sum;
}

void main() {
  testWidgets('sunk: only the page colour, and nothing at all before the '
      'scrim arrives', (tester) async {
    final none = await _render(tester, scrim: 0, rise: 0);
    expect(_rgba(none, .5, .5)[3], 0);
    final covered = await _render(tester, scrim: 1, rise: 0);
    expect(_distance(_rgba(covered, .5, .99), _base), lessThanOrEqualTo(2));
  });

  testWidgets('risen: glows at the base, and everything above the reach line '
      'stays the plain page colour', (tester) async {
    final risen = await _render(tester, scrim: 1, rise: 1);
    expect(_distance(_rgba(risen, .5, .99), _base), greaterThan(40));
    final clean = (1 - VoiceModeTokens.glowReach) * .95;
    for (final x in [0.0, .25, .5, .75, 1.0]) {
      expect(
        _distance(_rgba(risen, x, clean), _base),
        lessThanOrEqualTo(2),
        reason: 'top stays clean at x=$x',
      );
    }
    expect(
      _distance(_rgba(risen, .5, .9), _base),
      greaterThan(_distance(_rgba(risen, .5, .5), _base)),
      reason: 'strongest toward the base',
    );
  });

  testWidgets('layered, not one radial wash: the two sides of the base are '
      'different tones', (tester) async {
    final risen = await _render(tester, scrim: 1, rise: 1);
    expect(
      _distance(_rgba(risen, .2, .97), _rgba(risen, .8, .97)),
      greaterThan(6),
    );
  });
}
