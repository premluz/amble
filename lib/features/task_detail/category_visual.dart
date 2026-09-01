import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/category.dart';

/// The resolved pill fill / icon glyph color for one [Category] — shared
/// between the category-picker chips and (via `TaskCapsuleBlock`'s own
/// legacy-aware wrapper) the timeline pill.
///
/// A built-in seeded category (matched by its fixed [BuiltInCategoryIds])
/// renders through the existing hand-tuned `categoryColors`/
/// `categoryIconColors` Tier 2 maps — those 5 colors were deliberately
/// spaced/measured for distinguishability and contrast (see
/// docs/DECISIONS.md's Phase 3 / 13a-pastel entries), and there's no
/// reason to drop that tuning just because the category is now a
/// persisted row instead of an enum value. A genuinely custom (non-built-
/// in) category reads its color from the new 12-swatch `categorySwatches`
/// palette by [Category.colorToken] instead, using the same swatch for
/// both fill and icon-ring color — the new palette is a single saturated
/// swatch per color, not a tint+icon pair (see docs/DECISIONS.md).
class CategoryVisual {
  const CategoryVisual({required this.pillColor, required this.iconColor});

  final Color pillColor;
  final Color iconColor;
}

CategoryVisual resolveCategoryVisual({
  required AmbleTheme theme,
  required Category category,
}) {
  final builtInToken = builtInTokenFor(category.id);
  if (builtInToken != null) {
    return CategoryVisual(
      pillColor: theme.categoryColors[builtInToken]!,
      iconColor: theme.categoryIconColors[builtInToken]!,
    );
  }

  final swatch = theme.categorySwatches[category.colorToken];
  return CategoryVisual(pillColor: swatch, iconColor: swatch);
}

/// Maps a built-in [Category]'s fixed id back to its original
/// [TaskCategoryToken], so a built-in category still renders through the
/// existing hand-tuned color maps rather than the new 12-swatch palette.
/// Null for any non-built-in (user-created) category id.
TaskCategoryToken? builtInTokenFor(String categoryId) => switch (categoryId) {
  BuiltInCategoryIds.general => TaskCategoryToken.general,
  BuiltInCategoryIds.health => TaskCategoryToken.health,
  BuiltInCategoryIds.work => TaskCategoryToken.work,
  BuiltInCategoryIds.personal => TaskCategoryToken.personal,
  BuiltInCategoryIds.admin => TaskCategoryToken.admin,
  _ => null,
};
