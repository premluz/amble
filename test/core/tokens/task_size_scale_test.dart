import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';

/// The task-size scale's four fixed rungs — requested directly ("let's
/// establish this size as sm ... md that is slight larger ... lg" with the
/// original values sm=20/12, md=24/14, lg=28/16; a fourth rung, xl=32,
/// added 2026-09-10 for the "Large" option's own bigger badge — see
/// below).
///
/// **2026-09-12 — font rungs shifted one step down the type scale**,
/// requested directly ("zone names and task names ... reduce 1 scale
/// down"): sm/md/lg fonts are now 11/12/14 (was 12/14/16). Badge sizes are
/// UNCHANGED — the request was specifically about text, not the badge/pill
/// diameter. Pins the exact numbers so a future edit to the scale can't
/// silently drift without a test failing — the visual effect (a pill/font
/// a few px off) is easy to miss in a screenshot review but this makes it
/// an explicit assertion.
void main() {
  group('AmbleTheme.light task-size rungs', () {
    test('sm is 20px badge / 11px font', () {
      expect(AmbleTheme.light.sizeTaskBadgeSm, 20.0);
      expect(AmbleTheme.light.textTaskTitleSm.fontSize, 11.0);
    });

    test('md is 24px badge / 12px font', () {
      expect(AmbleTheme.light.sizeTaskBadgeMd, 24.0);
      expect(AmbleTheme.light.textTaskTitleMd.fontSize, 12.0);
    });

    test('lg is 28px badge / 14px font', () {
      expect(AmbleTheme.light.sizeTaskBadgeLg, 28.0);
      expect(AmbleTheme.light.textTaskTitleLg.fontSize, 14.0);
    });

    test(
      'xl badge is 32px — new, added for the "Large" Pill-size option '
      '(main.dart\'s _resolvePillSize), no matching font rung of its own',
      () {
        expect(AmbleTheme.light.sizeTaskBadgeXl, 32.0);
      },
    );

    test('each badge rung strictly increases over the previous one', () {
      expect(
        AmbleTheme.light.sizeTaskBadgeSm,
        lessThan(AmbleTheme.light.sizeTaskBadgeMd),
      );
      expect(
        AmbleTheme.light.sizeTaskBadgeMd,
        lessThan(AmbleTheme.light.sizeTaskBadgeLg),
      );
      expect(
        AmbleTheme.light.sizeTaskBadgeLg,
        lessThan(AmbleTheme.light.sizeTaskBadgeXl),
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
      expect(AmbleTheme.dark.sizeTaskBadgeXl, AmbleTheme.light.sizeTaskBadgeXl);
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

  group('copyWith resolves the active fields to main.dart\'s actual '
      '_resolvePillSize/_resolveFontSize pairing', () {
    // Mirrors exactly what main.dart's own _resolvePillSize/
    // _resolveFontSize do — pinned here since those functions are private
    // to main.dart and untestable directly, matching this codebase's
    // existing pattern of not unit testing main.dart's helpers (there is
    // no main_test.dart).
    //
    // **2026-09-15 — split into two independent settings** (requested
    // directly: "Settings in appearance separately font size and
    // separately pill size, let's split this"). What was one function
    // (`_resolveTaskSize`) resolving BOTH fields off one `TaskSize` value
    // is now two functions, each off its own setting (`TaskSize` for the
    // badge, `TaskFontSize` for the font) — but the NUMBERS below are
    // unchanged: this test still pins the exact same badge+font pairing a
    // user would get by picking the matching-named option on both of the
    // two new controls, which is what migrating an existing single
    // `TaskSize` choice into both settings preserves (see
    // `TaskFontSizeSetting`'s own migration doc comment).
    //
    // Badge/font pairing itself (2026-09-10, requested directly: "Current
    // medium size but with font size from small should be small... large
    // should be larger task pill but font size same as medium") — each
    // named option pairs a badge rung with a font rung ONE STEP SMALLER,
    // not the matching-named rung.
    //
    // **2026-09-12 — the `lg` pairing was reversed.** It used to
    // deliberately borrow `textTaskTitleMd`'s font ("large should be a
    // larger pill but font size same as medium," confirmed directly at
    // the time). This session's "reduce 1 scale down" request was
    // confirmed via AskUserQuestion to mean `lg` gets its OWN one-step
    // reduction instead — `textTaskTitleLg` (now 14, was 16), no longer
    // paired with md's font at all.
    test('sm: badge md (24) + font sm (11) — was badge sm (20)', () {
      final resolved = AmbleTheme.light.copyWith(
        sizeTaskBadge: AmbleTheme.light.sizeTaskBadgeMd,
        textTaskTitle: AmbleTheme.light.textTaskTitleSm,
      );
      expect(resolved.sizeTaskBadge, 24.0);
      expect(resolved.textTaskTitle.fontSize, 11.0);
    });

    test('md: badge lg (28) + font md (12) — was badge md (24)', () {
      final resolved = AmbleTheme.light.copyWith(
        sizeTaskBadge: AmbleTheme.light.sizeTaskBadgeLg,
        textTaskTitle: AmbleTheme.light.textTaskTitleMd,
      );
      expect(resolved.sizeTaskBadge, 28.0);
      expect(resolved.textTaskTitle.fontSize, 12.0);
    });

    test('lg: badge xl (32, new) + font lg (14, its own rung again) — was '
        'badge lg (28) + font md (14, borrowed)', () {
      final resolved = AmbleTheme.light.copyWith(
        sizeTaskBadge: AmbleTheme.light.sizeTaskBadgeXl,
        textTaskTitle: AmbleTheme.light.textTaskTitleLg,
      );
      expect(resolved.sizeTaskBadge, 32.0);
      expect(resolved.textTaskTitle.fontSize, 14.0);
    });

    test(
      'lg\'s font is strictly larger than md\'s again, not pinned equal',
      () {
        final mdResolved = AmbleTheme.light.copyWith(
          sizeTaskBadge: AmbleTheme.light.sizeTaskBadgeLg,
          textTaskTitle: AmbleTheme.light.textTaskTitleMd,
        );
        final lgResolved = AmbleTheme.light.copyWith(
          sizeTaskBadge: AmbleTheme.light.sizeTaskBadgeXl,
          textTaskTitle: AmbleTheme.light.textTaskTitleLg,
        );
        // The whole point of this session's reversal: lg's font is no
        // longer pinned equal to md's — it's a real, distinct, larger
        // step (12 -> 14), same direction its badge already moves.
        expect(
          lgResolved.textTaskTitle.fontSize,
          greaterThan(mdResolved.textTaskTitle.fontSize!),
          reason:
              'lg should read as genuinely larger than md again, not '
              'share its exact font size',
        );
        expect(
          lgResolved.sizeTaskBadge,
          greaterThan(mdResolved.sizeTaskBadge),
          reason: 'lg\'s badge must still be strictly larger than md\'s',
        );
      },
    );
  });
}
