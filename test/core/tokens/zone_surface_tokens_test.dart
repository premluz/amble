import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (name, theme) in [
    ('light', AmbleTheme.light),
    ('dark', AmbleTheme.dark),
  ]) {
    test('$name: a zone card is the secondary surface, a bit see-through', () {
      final fill = ZoneSurfaceTokens.fill(theme);
      expect(fill.a, lessThan(1));
      expect(fill.a, greaterThan(.5), reason: 'only a bit');
      expect(fill.withValues(alpha: 1), theme.colorSurfaceSecondary);
    });
  }
}
