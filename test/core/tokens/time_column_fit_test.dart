import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/tokens/type_primitives.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/load_app_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  // What main.dart does with the dual-font setting OFF (the default): time
  // labels switch to the proportional sans font, where "m" is wide.
  final sans = AmbleTheme.light.copyWith(
    textCaptionMono: AmbleTheme.light.textCaptionMono.copyWith(
      fontFamily: TypePrimitives.fontFamilySans,
    ),
  );

  for (final (name, theme) in [('mono', AmbleTheme.light), ('sans', sans)]) {
    test('$name: every label fits its column with room to spare — the "m" '
        'of "12 pm" is never cut off', () {
      final labelRoom =
          theme.timelineTimeColumnFixedWidth -
          ZoneInsetTokens.freedForTimeColumn(theme) -
          TimeColumnTokens.borrowedFromZoneGap;
      // Bold too: the "now" label is bold.
      final styles = {
        'regular': theme.textCaptionMono,
        'bold': theme.textCaptionMono.copyWith(fontWeight: FontWeight.w700),
      };
      for (final MapEntry(key: weight, value: style) in styles.entries) {
        for (final label in ['12 pm', '12 am', '11 pm', '12:48p', '13:48']) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: TextDirection.ltr,
          )..layout();
          expect(
            painter.width + TimeColumnTokens.labelSlack,
            lessThanOrEqualTo(labelRoom + 0.01),
            reason:
                '$weight "$label" (${painter.width}px) fits $labelRoom '
                'with slack',
          );
          painter.dispose();
        }
      }
    });
  }
}
