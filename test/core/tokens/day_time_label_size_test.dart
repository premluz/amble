import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (name, theme) in [
    ('light', AmbleTheme.light),
    ('dark', AmbleTheme.dark),
  ]) {
    test('$name: every time on the left of the Day screen reads at one size '
        '— hour ticks and list-view row times (textCaptionMono) and a '
        'task\'s start/end (textTaskEdgeTime)', () {
      expect(theme.textTaskEdgeTime.fontSize, theme.textCaptionMono.fontSize);
      expect(
        theme.textTaskEdgeTime.fontFamily,
        theme.textCaptionMono.fontFamily,
      );
    });
  }
}
