import 'dart:ui' as ui;

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_floating_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _capture = ValueKey('glass-paint');
const _size = Size(160, 80);

Future<List<Color>> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_capture),
  );
  final image = await boundary.toImage();
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final result = <Color>[];
  for (final y in [0, 40, 79]) {
    final offset = (y * image.width + 80) * 4;
    result.add(
      Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      ),
    );
  }
  image.dispose();
  return result;
}

Future<List<Color>> _paint(
  WidgetTester tester,
  AmbleTheme theme,
  FloatingMaterial material,
  FloatingElevation elevation, {
  bool openBottom = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: _capture,
          child: ColoredBox(
            color: theme.colorSurfaceTimeline,
            child: AppFloatingSurface(
              theme: theme,
              material: material,
              elevation: elevation,
              openBottom: openBottom,
              borderRadius: BorderRadius.circular(theme.radiusMd),
              child: SizedBox.fromSize(size: _size),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final fill = tester.widget<ColoredBox>(
    find.descendant(
      of: find.byType(AppFloatingSurface),
      matching: find.byType(ColoredBox),
    ),
  );
  expect(
    fill.color,
    theme.colorSurfaceOverlay.withValues(
      alpha: material == FloatingMaterial.glass ? .92 : 1,
    ),
  );

  return (await tester.runAsync(() => _pixels(tester)))!;
}

void main() {
  for (final theme in [AmbleTheme.light, AmbleTheme.dark]) {
    testWidgets(
      'edge is brighter on top, for glass and solid ${theme.colorSurfaceOverlay}',
      (tester) async {
        final menu = await _paint(
          tester,
          theme,
          FloatingMaterial.glass,
          FloatingElevation.menu,
        );
        final drag = await _paint(
          tester,
          theme,
          FloatingMaterial.glass,
          FloatingElevation.drag,
        );
        expect(
          menu[0].computeLuminance(),
          greaterThan(menu[2].computeLuminance()),
        );
        expect(
          drag[0].computeLuminance(),
          greaterThan(drag[2].computeLuminance()),
        );
        final solid = await _paint(
          tester,
          theme,
          FloatingMaterial.solid,
          FloatingElevation.menu,
        );
        expect(solid[1], theme.colorSurfaceOverlay);
        expect(solid[0], isNot(theme.colorSurfaceOverlay));
        expect(solid[2], isNot(theme.colorSurfaceOverlay));
      },
    );

    testWidgets(
      'an open bottom draws no bottom edge (a sheet meets the screen edge) '
      '${theme.colorSurfaceOverlay}',
      (tester) async {
        final sheet = await _paint(
          tester,
          theme,
          FloatingMaterial.solid,
          FloatingElevation.menu,
          openBottom: true,
        );
        expect(sheet[0], isNot(theme.colorSurfaceOverlay));
        expect(sheet[2], theme.colorSurfaceOverlay);
      },
    );
  }
}
