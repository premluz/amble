import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';

/// The task-size scale's three fixed rungs — requested directly ("let's
/// establish this size as sm ... md that is slight larger ... lg" with the
/// final values confirmed as sm=20/12, md=24/14, lg=28/16). Pins the exact
/// numbers so a future edit to the scale can't silently drift without a
/// test failing — the visual effect (a pill/font a few px off) is easy to
/// miss in a screenshot review but this makes it an explicit assertion.
void main() {
  group('AmbleTheme.light task-size rungs', () {
    test('sm is 20px badge / 12px font', () {
      expect(AmbleTheme.light.sizeTaskBadgeSm, 20.0);
      expect(AmbleTheme.light.textTaskTitleSm.fontSize, 12.0);
    });

    test('md is 24px badge / 14px font', () {
      expect(AmbleTheme.light.sizeTaskBadgeMd, 24.0);
      expect(AmbleTheme.light.textTaskTitleMd.fontSize, 14.0);
    });

    test('lg is 28px badge / 16px font', () {
      expect(AmbleTheme.light.sizeTaskBadgeLg, 28.0);
      expect(AmbleTheme.light.textTaskTitleLg.fontSize, 16.0);
    });

    test('each rung strictly increases over the previous one', () {
      expect(
        AmbleTheme.light.sizeTaskBadgeSm,
        lessThan(AmbleTheme.light.sizeTaskBadgeMd),
      );
      expect(
        AmbleTheme.light.sizeTaskBadgeMd,
        lessThan(AmbleTheme.light.sizeTaskBadgeLg),
      );
      expect(
        AmbleTheme.light.textTaskTitleSm.fontSize,
        lessThan(AmbleTheme.light.textTaskTitleMd.fontSize!),
      );
      expect(
        AmbleTheme.light.textTaskTitleMd.fontSize,
        lessThan(AmbleTheme.light.textTaskTitleLg.fontSize!),
      );
    });

    test('the ACTIVE fields default to the md rung, matching Task view\'s '
        'own prior fixed size', () {
      expect(AmbleTheme.light.sizeTaskBadge, AmbleTheme.light.sizeTaskBadgeMd);
      expect(
        AmbleTheme.light.textTaskTitle.fontSize,
        AmbleTheme.light.textTaskTitleMd.fontSize,
      );
    });
  });

  group('AmbleTheme.dark task-size rungs', () {
    // Same numbers as light — only the color varies between palettes, per
    // every other text/size token in this theme.
    test('match the light palette\'s own rungs exactly', () {
      expect(AmbleTheme.dark.sizeTaskBadgeSm, AmbleTheme.light.sizeTaskBadgeSm);
      expect(AmbleTheme.dark.sizeTaskBadgeMd, AmbleTheme.light.sizeTaskBadgeMd);
      expect(AmbleTheme.dark.sizeTaskBadgeLg, AmbleTheme.light.sizeTaskBadgeLg);
      expect(
        AmbleTheme.dark.textTaskTitleSm.fontSize,
        AmbleTheme.light.textTaskTitleSm.fontSize,
      );
      expect(
        AmbleTheme.dark.textTaskTitleMd.fontSize,
        AmbleTheme.light.textTaskTitleMd.fontSize,
      );
      expect(
        AmbleTheme.dark.textTaskTitleLg.fontSize,
        AmbleTheme.light.textTaskTitleLg.fontSize,
      );
    });
  });

  group('copyWith resolves the active fields to a chosen rung', () {
    // Mirrors exactly what main.dart's own _resolveTaskSize does — pinned
    // here since that function is private to main.dart and untestable
    // directly, matching this codebase's existing pattern of not unit
    // testing main.dart's helpers (there is no main_test.dart).
    test('sm', () {
      final resolved = AmbleTheme.light.copyWith(
        sizeTaskBadge: AmbleTheme.light.sizeTaskBadgeSm,
        textTaskTitle: AmbleTheme.light.textTaskTitleSm,
      );
      expect(resolved.sizeTaskBadge, 20.0);
      expect(resolved.textTaskTitle.fontSize, 12.0);
    });

    test('lg', () {
      final resolved = AmbleTheme.light.copyWith(
        sizeTaskBadge: AmbleTheme.light.sizeTaskBadgeLg,
        textTaskTitle: AmbleTheme.light.textTaskTitleLg,
      );
      expect(resolved.sizeTaskBadge, 28.0);
      expect(resolved.textTaskTitle.fontSize, 16.0);
    });
  });
}
