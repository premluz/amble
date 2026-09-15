import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_category_token_mapping.dart';
import 'package:amble/shared/models/task_category.dart';

/// Reported directly: "gray on light mode for default (non selected
/// category) is too light, non legible on light mode" and "both light dark
/// mode default should not have emoji."
void main() {
  double _luminance(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;

  double _contrast(Color a, Color b) {
    final la = _luminance(a);
    final lb = _luminance(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  group('the default/uncategorised pill is legible', () {
    // The actual defect: measured against `colorSurfacePrimary`, the
    // default grey gave a contrast ratio of 1.01 in light mode — visually
    // indistinguishable from the page it sits on — while the four COLORED
    // tints all landed at 1.08-1.10. The grey was the only tint defined at
    // OKLCH lightness 0.956 instead of the shared 0.900.
    //
    // Asserted RELATIVE to the other categories rather than against a
    // hardcoded ratio: the point is that the default behaves like every
    // other category, which stays true if the whole palette is retuned.
    for (final (themeName, theme) in [
      ('light', AmbleTheme.light),
      ('dark', AmbleTheme.dark),
    ]) {
      test('$themeName: the general tint separates from the surface about '
          'as well as every colored tint does', () {
        final surface = theme.colorSurfacePrimary;
        final general = _contrast(
          theme.categoryColors[TaskCategoryToken.general]!,
          surface,
        );
        final colored = [
          TaskCategoryToken.health,
          TaskCategoryToken.work,
          TaskCategoryToken.personal,
          TaskCategoryToken.admin,
        ].map((t) => _contrast(theme.categoryColors[t]!, surface)).toList();

        final weakestColored = colored.reduce((a, b) => a < b ? a : b);

        expect(
          general,
          greaterThanOrEqualTo(weakestColored * 0.95),
          reason:
              'the default pill must not be markedly fainter than the '
              'faintest colored one — general=$general, '
              'weakest colored=$weakestColored',
        );
      });
    }
  });

  group('the default/uncategorised badge carries no emoji', () {
    // "both light dark mode default should not have emoji" — the glyph was
    // '⚪', a white circle, which on light mode was invisible against the
    // pale pill it sat on (compounding the contrast bug above). The grey
    // fill alone is the "uncategorised" signal.
    test('the legacy general category resolves to an empty glyph', () {
      expect(TaskCategory.general.emoji, isEmpty);
    });

    test('every OTHER category still has its own glyph — this is scoped to '
        'the default, not a blanket removal', () {
      for (final category in TaskCategory.values) {
        if (category == TaskCategory.general) continue;
        expect(
          category.emoji,
          isNotEmpty,
          reason: '${category.name} must keep its emoji',
        );
      }
    });
  });
}
