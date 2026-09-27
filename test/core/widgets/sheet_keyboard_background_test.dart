import 'dart:ui' as ui;

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_sheet_motion.dart';
import 'package:amble/core/widgets/app_step_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _capture = ValueKey('capture');
const _content = ValueKey('content');
const _pageColor = Colors.red;

Widget _sheet(AmbleTheme theme, bool step) => step
    ? StepScaffold(
        theme: theme,
        headerColor: theme.colorAccent,
        onBack: null,
        onClose: () {},
        primaryLabel: 'Done',
        onPrimaryPressed: () {},
        body: const SizedBox(key: _content, height: 40),
      )
    : AppSheetMotion(
        theme: theme,
        routeAnimation: const AlwaysStoppedAnimation(1),
        autofocusesKeyboard: false,
        child: SizedBox(
          key: _content,
          width: double.infinity,
          height: 120,
          child: ColoredBox(color: theme.colorSurfaceOverlay),
        ),
      );

Future<void> _expectCorners(
  WidgetTester tester,
  Color color,
  double inset,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  final image = await boundary.toImage();
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  for (final x in [0, image.width - 1]) {
    final offset = ((image.height - inset.toInt() + 1) * image.width + x) * 4;
    expect(
      Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      ),
      color,
    );
  }
  image.dispose();
}

void main() {
  for (final theme in [AmbleTheme.light, AmbleTheme.dark]) {
    for (final step in [false, true]) {
      testWidgets(
        'keyboard corners have sheet fill: step=$step ${theme.colorSurfaceOverlay}',
        (tester) async {
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(extensions: [theme]),
              home: RepaintBoundary(
                key: _capture,
                child: ColoredBox(
                  color: _pageColor,
                  child: _sheet(theme, step),
                ),
              ),
            ),
          );
          for (final inset in [180.0, 300.0]) {
            tester.view.viewInsets = FakeViewPadding(
              bottom: inset * tester.view.devicePixelRatio,
            );
            await tester.pumpAndSettle();
            await tester.runAsync(
              () => _expectCorners(tester, theme.colorSurfaceOverlay, inset),
            );
            final screenHeight =
                tester.view.physicalSize.height / tester.view.devicePixelRatio;
            final content = step ? find.text('Done') : find.byKey(_content);
            expect(
              tester.getRect(content).bottom,
              lessThanOrEqualTo(screenHeight - inset),
            );
          }
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
