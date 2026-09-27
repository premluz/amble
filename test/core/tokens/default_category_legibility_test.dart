import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/task_detail/category_visual.dart';
import 'package:amble/features/timeline/task_category_token_mapping.dart';
import 'package:amble/shared/models/task_category.dart';

/// Reported directly: "gray on light mode for default (non selected
/// category) is too light, non legible on light mode" and "both light dark
/// mode default should not have emoji."
///
/// **Since categorized under the unified `categorySwatches` system**
/// (built-in categories used to route through a separate, now-removed
/// `categoryColors`/`categoryIconColors` map pair — see
/// `category_visual.dart`'s `resolveCategoryVisual`) — General's own
/// swatch (`generalCategoryColorToken`, index 0 into `categorySwatches`)
/// is now a real saturated color like every other index, not a
/// dedicated muted grey. The specific legacy-grey contrast bug this file
/// originally guarded against cannot recur under the new system (there
/// is no separate grey value left to regress), so the pill-legibility
/// group below is retired; the emoji-suppression group still applies
/// unchanged, since that's the legacy `TaskCategory` enum's own concern,
/// untouched by this session's color unification.
void main() {
  group('General resolves through the same swatch system as every '
      'other category', () {
    for (final (themeName, theme) in [
      ('light', AmbleTheme.light),
      ('dark', AmbleTheme.dark),
    ]) {
      test('$themeName: generalCategoryColorToken indexes a real swatch', () {
        expect(
          theme.categorySwatches[generalCategoryColorToken],
          isNotNull,
        );
        expect(generalCategoryColorToken, lessThan(theme.categorySwatches.length));
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
