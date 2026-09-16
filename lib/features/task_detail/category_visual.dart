import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

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

/// A curated set of Tabler glyphs offered in the new/edit-category picker
/// — hand-picked, not the full ~6,250-icon set, matching how the old
/// curated emoji set (`add_category_modal.dart`'s `_curatedCategoryEmoji`)
/// was never a full emoji-picker either. Broadened from the original
/// 16-icon set — requested directly: "add more icons... broader choice
/// of icons that represent tasks, lifestyle, etc. Not UI or anything
/// like that" — every addition is a concrete real-world thing (a
/// lifestyle domain, an activity, an object), never a generic app/UI
/// glyph (no gear, no bell, no generic arrow/chevron).
const List<IconData> curatedCategoryIcons = [
  TablerIcons.circle,
  TablerIcons.heart,
  TablerIcons.briefcase,
  TablerIcons.home,
  TablerIcons.clipboardList,
  TablerIcons.star,
  TablerIcons.bulb,
  TablerIcons.book,
  TablerIcons.run,
  TablerIcons.school,
  TablerIcons.shoppingCart,
  TablerIcons.plane,
  TablerIcons.tools,
  TablerIcons.pig,
  TablerIcons.paw,
  TablerIcons.music,
  // Health & fitness.
  TablerIcons.dumbbell,
  TablerIcons.yoga,
  TablerIcons.pill,
  TablerIcons.stethoscope,
  TablerIcons.bike,
  TablerIcons.walk,
  TablerIcons.swimming,
  // Food & drink.
  TablerIcons.apple,
  TablerIcons.salad,
  TablerIcons.coffee,
  TablerIcons.toolsKitchen,
  TablerIcons.pizza,
  // Rest & routine.
  TablerIcons.bed,
  TablerIcons.moon,
  TablerIcons.sun,
  TablerIcons.sunrise,
  TablerIcons.hourglass,
  // Money & shopping.
  TablerIcons.wallet,
  TablerIcons.cashBanknote,
  TablerIcons.gift,
  // Family & pets.
  TablerIcons.users,
  TablerIcons.babyCarriage,
  TablerIcons.dog,
  TablerIcons.cat,
  // Places & travel.
  TablerIcons.car,
  TablerIcons.map,
  TablerIcons.compass,
  // Nature.
  TablerIcons.tree,
  TablerIcons.leaf,
  // Communication.
  TablerIcons.phone,
  TablerIcons.mail,
  // Creative & hobbies.
  TablerIcons.palette,
  TablerIcons.camera,
  TablerIcons.guitarPick,
  TablerIcons.shirt,
  // Achievement.
  TablerIcons.trophy,
  TablerIcons.target,
  TablerIcons.checklist,
];

/// The built-in categories' default Tabler glyph — requested directly:
/// "let's get tabler icons installed and use it instead of emojis for
/// categories." Replaces `TaskCategoryTokenMapping.emoji`'s literal glyph
/// per built-in id; General stays a plain outline circle, same reasoning
/// as that mapping's own `''`/`Icons.circle_outlined` default: "the whole
/// point is the absence of one," now expressed as the most neutral glyph
/// in the set rather than an absent one, since a live [Category] row (see
/// [categoryIconFor]) always resolves to SOME icon rather than optionally
/// none.
IconData builtInIconFor(String categoryId) => switch (categoryId) {
  BuiltInCategoryIds.health => TablerIcons.heart,
  BuiltInCategoryIds.work => TablerIcons.briefcase,
  BuiltInCategoryIds.personal => TablerIcons.home,
  BuiltInCategoryIds.admin => TablerIcons.clipboardList,
  _ => TablerIcons.circle,
};

/// Resolves the glyph actually shown for [category]: its own
/// [Category.iconCodePoint] when set, else the matching built-in default,
/// else (a genuinely custom category created before this field existed,
/// still only carrying a legacy [Category.emoji]) null — the caller falls
/// back to that legacy emoji text itself, see [CategoryGlyph].
IconData? categoryIconFor(Category category) {
  final codePoint = category.iconCodePoint;
  if (codePoint != null) {
    // Not const — codePoint is a runtime value read from persisted data,
    // not one of the fixed literals `flutter build`'s icon tree-shaker
    // can see ahead of time. This is the standard, unavoidable shape for
    // reconstructing an IconData from a stored code point (Category only
    // persists an int, not an IconData); every one of curatedCategoryIcons
    // is still a real `const TablerIcons.*` reference at its own call
    // sites. `flutter analyze` therefore always shows exactly one
    // `non_const_argument_for_const_parameter` warning right here — not
    // suppressible by an `// ignore:` comment (this is a hard analyzer
    // diagnostic tied to IconData's own `@mustBeConst` annotation, not an
    // ordinary lint rule). Accepted as a known, permanent warning rather
    // than switching Category.iconCodePoint to a string icon NAME with a
    // hand-maintained name<->icon switch just to keep every reference
    // const (confirmed directly). Consequence: a RELEASE build needs
    // `flutter build ... --no-tree-shake-icons`, since this one dynamic
    // reconstruction is exactly what IconData's own constructor doc
    // comment warns disables tree-shaking ("Instantiating non-const
    // instances of this class in your app will mean the app cannot be
    // built in release mode with icon tree-shaking").
    return IconData(
      codePoint,
      fontFamily: 'tabler-icons',
      fontPackage: 'tabler_icons_plus',
    );
  }
  final builtInToken = builtInTokenFor(category.id);
  if (builtInToken != null) return builtInIconFor(category.id);
  return null;
}

/// Renders [category]'s glyph — a Tabler icon when [categoryIconFor]
/// resolves one, else the legacy [Category.emoji] text (only reachable for
/// a custom category created before [Category.iconCodePoint] existed), else
/// nothing. The one shared render site every `Text(category.emoji, ...)`
/// call in the app converts to, so the Tabler-vs-legacy fallback lives in
/// exactly one place.
class CategoryGlyph extends StatelessWidget {
  const CategoryGlyph({
    super.key,
    required this.category,
    required this.color,
    required this.size,
  });

  final Category category;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = categoryIconFor(category);
    if (icon != null) return Icon(icon, size: size, color: color);
    if (category.emoji.isEmpty) return const SizedBox.shrink();
    return Text(category.emoji, style: TextStyle(fontSize: size));
  }
}

/// The shared category badge: a colored circle or pill holding a
/// centered [CategoryGlyph] — one reusable widget every render site that
/// draws "a colored shape with a category icon in it" now uses, instead
/// of each independently reimplementing `Container(decoration:...) ->
/// Center -> Icon` with its own slightly different glyph-to-badge ratio.
/// Reported directly: "all other pills should be [a] consistent padding
/// scale of icon, ensure using [the] same class[,] reusable."
///
/// [category] null renders the General fallback (a plain outline circle,
/// [BuiltInCategoryIds.general]'s own default) rather than requiring
/// every caller to branch on "no category assigned" itself — mirrors the
/// identical null-handling every call site already had inline.
///
/// [shape] is deliberately a parameter, not a fixed choice: this app has
/// two genuinely different existing badge shapes in use on purpose —
/// [BoxShape.circle] (the Inbox's own toggle badge, template rows,
/// category list) and the "Pill shape" setting's own [radiusPill] rung
/// (task/zone pills, which must keep tracking that setting) — unifying
/// the WIDGET does not mean forcing one shape where two were each chosen
/// deliberately.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.theme,
    required this.category,
    required this.size,
    this.shape = BoxShape.circle,
    this.glyphSizeRatio = 0.55,
  });

  final AmbleTheme theme;
  final Category? category;

  /// Width and height of the badge square.
  final double size;
  final BoxShape shape;

  /// The glyph's size as a fraction of [size] — 0.55 by default, matching
  /// the ratio already tuned for `sizeTaskBadge`-scale badges (Task view,
  /// Zone view, imported events). A badge much smaller than that scale
  /// (e.g. the quick-create mini sheet's template chips, `spacingLg`) can
  /// override this: a thin-stroke Tabler icon at the same 0.55 ratio read
  /// as too small on that badge specifically, reported directly ("Badge
  /// on add task sheet icons too small").
  final double glyphSizeRatio;

  @override
  Widget build(BuildContext context) {
    final resolvedCategory = category;
    final badgeColor = resolvedCategory == null
        ? theme.categoryColors[TaskCategoryToken.general]!
        : resolveCategoryVisual(
            theme: theme,
            category: resolvedCategory,
          ).pillColor;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: shape == BoxShape.circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(theme.radiusPill),
      ),
      child: resolvedCategory == null
          ? Icon(
              builtInIconFor(BuiltInCategoryIds.general),
              size: size * glyphSizeRatio,
              color: glyphColorOn(badgeColor),
            )
          : CategoryGlyph(
              category: resolvedCategory,
              color: glyphColorOn(badgeColor),
              size: size * glyphSizeRatio,
            ),
    );
  }
}

/// The glyph color that reads against a badge/pill filled with
/// [background] — near-white on a dark/saturated fill, near-black on a
/// light one. Needed because a monochrome Tabler icon, unlike the emoji it
/// replaces, carries no color of its own: for a BUILT-IN category the pill
/// (pale tint) and icon ([resolveCategoryVisual]'s `categoryIconColors`,
/// saturated) already differ, but a CUSTOM category's pill and icon
/// currently resolve to the exact same 12-swatch color — rendering a
/// monochrome icon straight in that color would be invisible against its
/// own background. Uses [ThemeData.estimateBrightnessForColor] rather
/// than a hand-rolled luminance check — this codebase has no existing
/// contrast helper to reuse (confirmed by search) and this is the
/// standard Flutter primitive for exactly this question.
Color glyphColorOn(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black;

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
