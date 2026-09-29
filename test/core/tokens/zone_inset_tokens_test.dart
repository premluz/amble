import 'package:amble/core/timeline_clock.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final theme = AmbleTheme.light;

  test('tasks sit 25% closer to their zone\'s edges', () {
    expect(ZoneInsetTokens.side(theme), theme.spacingLg * .75);
    expect(ZoneInsetTokens.vertical(theme), theme.spacingMd * .75);
  });

  test('the side inset\'s saving goes to the time column: zones start later '
      'by exactly that much, and a pill starts where it did before', () {
    var widestLabel = 0.0;
    for (final sample in timelineClockSamples().toSet()) {
      final painter = TextPainter(
        text: TextSpan(text: sample, style: theme.textCaptionMono),
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > widestLabel) widestLabel = painter.width;
      painter.dispose();
    }
    final freed = ZoneInsetTokens.freedForTimeColumn(theme);
    expect(freed, theme.spacingLg - ZoneInsetTokens.side(theme));
    expect(
      theme.timelineTimeColumnFixedWidth,
      widestLabel +
          TimeColumnTokens.labelSlack +
          freed +
          TimeColumnTokens.borrowedFromZoneGap,
    );

    // The side inset's saving and the gap's loan cancel out: a pill starts
    // one screen gutter + the label (with its slack) + the old full side
    // inset in.
    final pillStartBefore =
        theme.spacingTimelineGutter * 2 +
        widestLabel +
        TimeColumnTokens.labelSlack +
        theme.spacingLg;
    expect(
      theme.timelineZoneLeft + ZoneInsetTokens.side(theme),
      moreOrLessEquals(pillStartBefore, epsilon: 0.01),
    );
  });
}
