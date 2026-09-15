import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';

/// The "Pill shape" setting's three fixed rungs — requested directly, with
/// exact values confirmed via AskUserQuestion to match Material 3's own
/// named component-corner scale rather than reusing the pre-existing
/// hardcoded pill corner (radiusSm, 4px) unchanged: "Full (circle) /
/// Rounded / Small rounding (current) (match these values to industry
/// standard in design system)."
///
/// Pins the exact numbers so a future edit to the scale can't silently
/// drift without a test failing, mirroring `task_size_scale_test.dart`'s
/// own reasoning for the sibling "Task size" setting.
void main() {
  group('AmbleTheme.light pill-shape rungs', () {
    test('small is 8px — Material 3\'s own "small" component corner, a '
        'deliberate step up from the old hardcoded radiusSm (4px)', () {
      expect(AmbleTheme.light.radiusPillSmall, 8.0);
      expect(
        AmbleTheme.light.radiusPillSmall,
        greaterThan(AmbleTheme.light.radiusSm),
        reason: 'this rung is a NEW, larger value — not radiusSm renamed',
      );
    });

    test('rounded is 16px — Material 3\'s own "large" component corner', () {
      expect(AmbleTheme.light.radiusPillRounded, 16.0);
    });

    test('full is fully round, same value radiusTaskPill already uses', () {
      expect(AmbleTheme.light.radiusPillFull, AmbleTheme.light.radiusTaskPill);
    });

    test('each rung strictly increases over the previous one', () {
      expect(
        AmbleTheme.light.radiusPillSmall,
        lessThan(AmbleTheme.light.radiusPillRounded),
      );
      expect(
        AmbleTheme.light.radiusPillRounded,
        lessThan(AmbleTheme.light.radiusPillFull),
      );
    });

    test('the ACTIVE radiusPill field defaults to the small rung, matching '
        'PillShapeSetting\'s own default', () {
      expect(AmbleTheme.light.radiusPill, AmbleTheme.light.radiusPillSmall);
    });
  });

  group('AmbleTheme.dark pill-shape rungs match light exactly', () {
    test('every rung is theme-independent — a corner radius, unlike a '
        'color, has no reason to differ between light and dark', () {
      expect(AmbleTheme.dark.radiusPillSmall, AmbleTheme.light.radiusPillSmall);
      expect(
        AmbleTheme.dark.radiusPillRounded,
        AmbleTheme.light.radiusPillRounded,
      );
      expect(AmbleTheme.dark.radiusPillFull, AmbleTheme.light.radiusPillFull);
    });
  });
}
