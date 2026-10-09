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
    double widestOf(TextStyle style) {
      var widest = 0.0;
      for (final sample in timelineClockSamples().toSet()) {
        final painter = TextPainter(
          text: TextSpan(text: sample, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        if (painter.width > widest) widest = painter.width;
        painter.dispose();
      }
      return widest;
    }

    // What the column holds: the widest bare label (regular or bold) with
    // its slack, or the widest edge-time pill with its padding.
    final bold = FontWeight.w600;
    final label = [
      widestOf(theme.textCaptionMono),
      widestOf(theme.textCaptionMono.copyWith(fontWeight: bold)),
    ].reduce((a, b) => a > b ? a : b);
    final pill =
        widestOf(theme.textTaskEdgeTime.copyWith(fontWeight: bold)) +
        TimeColumnTokens.edgePillPaddingX(theme) * 2;
    final room = [
      label + TimeColumnTokens.labelSlack,
      pill,
    ].reduce((a, b) => a > b ? a : b);
    final freed = ZoneInsetTokens.freedForTimeColumn(theme);
    expect(freed, theme.spacingLg - ZoneInsetTokens.side(theme));
    expect(
      theme.timelineTimeColumnFixedWidth,
      room + freed + TimeColumnTokens.borrowedFromZoneGap,
    );

    // The side inset's saving and the gap's loan cancel out: a pill starts
    // one screen gutter + the column's room + the old full side inset in.
    final pillStartBefore =
        theme.spacingTimelineGutter * 2 + room + theme.spacingLg;
    expect(
      theme.timelineZoneLeft + ZoneInsetTokens.side(theme),
      moreOrLessEquals(pillStartBefore, epsilon: 0.01),
    );
  });
}
