import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:amble/core/haptics.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/what_matters_tokens.dart';
import 'package:amble/core/widgets/app_bottom_dock.dart';
import 'package:amble/core/widgets/app_press_feedback.dart';
import 'package:amble/core/widgets/what_matters_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _wash = ValueKey('what-matters-wash');
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
      'bottom ripple moves upward and leaves an even tint: dark=$dark',
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
        expect(find.byKey(_wash), findsOneWidget);
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
        expect(_alpha(settled, 0), _alpha(settled, _height - 1));
        final tint = dark
            ? WhatMattersTokens.tintAlphaDark
            : WhatMattersTokens.tintAlphaLight;
        expect(_alpha(settled, 0), closeTo(255 * tint, 1));
      },
    );

    testWidgets(
      'only What Matters pane is tinted and its haptic is stronger: dark=$dark',
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
            .ancestor(
              of: find.byTooltip('What Matters'),
              matching: find.byType(AppDockPane),
            )
            .first;
        expect(tester.widget<AppDockPane>(pane).backgroundColor, isNull);
        await tester.tap(find.byTooltip('What Matters'));
        await tester.pumpAndSettle();
        expect(tester.widget<AppDockPane>(pane).backgroundColor, isNotNull);
        final allPanes = tester.widgetList<AppDockPane>(
          find.byType(AppDockPane),
        );
        expect(
          allPanes.where((pane) => pane.backgroundColor != null).length,
          1,
        );
        final feedback = find.descendant(
          of: pane,
          matching: find.byType(AppPressFeedback),
        );
        expect(
          tester.widget<AppPressFeedback>(feedback).haptic,
          AmbleHaptic.lift,
        );
        final editPane = find
            .ancestor(
              of: find.byTooltip('Edit Day'),
              matching: find.byType(AppDockPane),
            )
            .first;
        expect(
          tester
              .widget<AppPressFeedback>(
                find.descendant(
                  of: editPane,
                  matching: find.byType(AppPressFeedback),
                ),
              )
              .haptic,
          AmbleHaptic.tap,
        );
        await tester.tap(find.byTooltip('What Matters'));
        await tester.pumpAndSettle();
        expect(tester.widget<AppDockPane>(pane).backgroundColor, isNull);
      },
    );
  }
}
