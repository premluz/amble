import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:amble/core/haptics.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/what_matters_tokens.dart';
import 'package:amble/core/widgets/app_bottom_dock.dart';
import 'package:amble/core/widgets/app_dock_primitives.dart';
import 'package:amble/core/widgets/app_press_feedback.dart';
import 'package:amble/core/widgets/what_matters_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _wash = ValueKey('what-matters-wash');
const _glow = ValueKey('what-matters-glow');
const _width = 200;
const _height = 400;

Future<ByteData> _pixels(WidgetTester tester) async {
  final painter = tester.widget<CustomPaint>(find.byKey(_wash)).painter!;
  final result = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    painter.paint(
      Canvas(recorder),
      Size(_width.toDouble(), _height.toDouble()),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(_width, _height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();
    return bytes;
  });
  if (result == null) throw StateError('Ripple pixel capture failed');
  return result;
}

int _alpha(ByteData pixels, int y) =>
    pixels.getUint8((y * _width + _width ~/ 2) * 4 + 3);
int _peak(ByteData pixels) {
  var peak = 0;
  for (var y = 1; y < _height; y++) {
    if (_alpha(pixels, y) > _alpha(pixels, peak)) peak = y;
  }
  return peak;
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'bottom ripple moves upward and leaves the page untinted: dark=$dark',
      (tester) async {
        final enabled = ValueNotifier(false);
        addTearDown(enabled.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
              extensions: [dark ? AmbleTheme.dark : AmbleTheme.light],
            ),
            home: ValueListenableBuilder<bool>(
              valueListenable: enabled,
              builder: (_, value, _) => WhatMattersScene(
                enabled: value,
                child: WhatMattersScene(
                  enabled: value,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        );
        // No ripple layer while the mode is off.
        expect(find.byKey(_wash), findsNothing);
        enabled.value = true;
        await tester.pump();
        await tester.pump(WhatMattersTokens.enter * .25);
        final early = await _pixels(tester);
        await tester.pump(WhatMattersTokens.enter * .3);
        final later = await _pixels(tester);
        expect(_peak(later), lessThan(_peak(early)));
        expect(_alpha(later, _peak(later)), greaterThan(_alpha(later, 0)));
        await tester.pumpAndSettle();
        final settled = await _pixels(tester);
        expect(_alpha(settled, 0), 0);
        expect(_alpha(settled, _height - 1), 0);
      },
    );

    testWidgets(
      'turning What Matters OFF plays no ripple; the glow fades instead: '
      'dark=$dark',
      (tester) async {
        final enabled = ValueNotifier(true);
        addTearDown(enabled.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
              extensions: [dark ? AmbleTheme.dark : AmbleTheme.light],
            ),
            home: ValueListenableBuilder<bool>(
              valueListenable: enabled,
              builder: (_, value, _) => WhatMattersScene(
                enabled: value,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        enabled.value = false;
        await tester.pump();
        await tester.pump(WhatMattersTokens.leave * .5);
        expect(find.byKey(_wash), findsNothing);
      },
    );

    testWidgets(
      'while on, the backdrop glows from the bottom BEHIND the content and '
      'fades back to the plain page colour when off: dark=$dark',
      (tester) async {
        final enabled = ValueNotifier(false);
        addTearDown(enabled.dispose);
        final theme = dark ? AmbleTheme.dark : AmbleTheme.light;
        final background = theme.colorSurfaceTimeline;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
              extensions: [theme],
            ),
            home: ValueListenableBuilder<bool>(
              valueListenable: enabled,
              builder: (_, value, _) => WhatMattersScene(
                enabled: value,
                child: WhatMattersBackdrop(
                  color: background,
                  child: const SizedBox.expand(key: ValueKey('content')),
                ),
              ),
            ),
          ),
        );
        Future<ByteData> glowPixels() async {
          final painter = tester
              .widget<CustomPaint>(find.byKey(_glow))
              .painter!;
          final bytes = await tester.runAsync(() async {
            final recorder = ui.PictureRecorder();
            painter.paint(
              Canvas(recorder),
              Size(_width.toDouble(), _height.toDouble()),
            );
            final image = await recorder.endRecording().toImage(
              _width,
              _height,
            );
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            image.dispose();
            return data;
          });
          if (bytes == null) throw StateError('Glow pixel capture failed');
          return bytes;
        }

        // How far a pixel's colour has moved away from the page colour.
        int tint(ByteData pixels, int y) {
          final i = (y * _width + _width ~/ 2) * 4;
          final base = [background.r, background.g, background.b];
          var sum = 0;
          for (var c = 0; c < 3; c++) {
            sum += (pixels.getUint8(i + c) - (base[c] * 255).round()).abs();
          }
          return sum;
        }

        final off = await glowPixels();
        expect(tint(off, _height - 1), lessThanOrEqualTo(3), reason: 'off');
        expect(_alpha(off, 0), 255, reason: 'paints the page colour itself');

        enabled.value = true;
        await tester.pumpAndSettle();
        final on = await glowPixels();
        expect(tint(on, _height - 1), greaterThan(12), reason: 'visible glow');
        expect(
          tint(on, _height - 1),
          greaterThan(tint(on, 0)),
          reason: 'rises from the bottom',
        );
        final paint = tester.widget<CustomPaint>(find.byKey(_glow));
        expect(paint.foregroundPainter, isNull, reason: 'behind the content');
        expect(
          find.descendant(
            of: find.byKey(_glow),
            matching: find.byKey(const ValueKey('content')),
          ),
          findsOneWidget,
        );

        enabled.value = false;
        await tester.pumpAndSettle();
        expect(
          tint(await glowPixels(), _height - 1),
          lessThanOrEqualTo(3),
          reason: 'off again',
        );
      },
    );

    testWidgets(
      'selected What Matters dock pane is tinted and its haptic is stronger: '
      'dark=$dark',
      (tester) async {
        final theme = dark ? AmbleTheme.dark : AmbleTheme.light;
        final enabled = ValueNotifier(false);
        addTearDown(enabled.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
              extensions: [theme],
            ),
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: enabled,
                builder: (_, value, _) => AppBottomDock(
                  activeView: AppBottomDockView.list,
                  onSelectView: (_) {},
                  onEditTap: () {},
                  whatMattersEnabled: value,
                  onWhatMattersTap: () => enabled.value = !enabled.value,
                ),
              ),
            ),
          ),
        );
        final pane = find
            .descendant(
              of: find.byKey(const ValueKey('dock-pane-day-matters')),
              matching: find.byType(AppDockSurface),
            )
            .first;
        expect(tester.widget<AppDockSurface>(pane).backgroundColor, isNull);
        await tester.tap(find.byTooltip('What Matters'));
        await tester.pumpAndSettle();
        expect(tester.widget<AppDockSurface>(pane).backgroundColor, isNotNull);
        final allPanes = tester.widgetList<AppDockSurface>(
          find.byType(AppDockSurface),
        );
        expect(
          allPanes.where((pane) => pane.backgroundColor != null).length,
          1,
        );
        final feedback = find
            .descendant(
              of: find.byTooltip('What Matters'),
              matching: find.byType(AppPressFeedback),
            )
            .first;
        expect(
          tester.widget<AppPressFeedback>(feedback).haptic,
          AmbleHaptic.lift,
        );
        expect(
          tester
              .widget<AppPressFeedback>(
                find
                    .descendant(
                      of: find.byTooltip('Edit Day'),
                      matching: find.byType(AppPressFeedback),
                    )
                    .first,
              )
              .haptic,
          AmbleHaptic.tap,
        );
        await tester.tap(find.byTooltip('What Matters'));
        await tester.pumpAndSettle();
        expect(tester.widget<AppDockSurface>(pane).backgroundColor, isNull);
      },
    );
  }
}
